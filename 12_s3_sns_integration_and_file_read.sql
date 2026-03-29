/*=============================================================================
  12 - S3 INTEGRATION, SNS NOTIFICATION INTEGRATION & FILE READ VERIFICATION
  Healthcare AI Intelligence Pipeline

  This file provides ALL the Snowflake-side SQL steps needed to:
    1. Create and verify the S3 storage integration
    2. Create and verify the SNS notification integration
    3. Read/list files from S3 stages to confirm connectivity
    4. Validate that files are accessible before AI processing

  Run AFTER 01_setup_database.sql (which creates the database, schemas,
  warehouse, and stages) and AFTER completing the AWS-side setup in
  10_aws_setup_guide.sql.

  IMPORTANT: Replace these placeholders before running:
    <YOUR_S3_BUCKET_NAME>     -> your actual S3 bucket name
    <YOUR_AWS_ACCOUNT_ID>     -> your 12-digit AWS account ID
    <YOUR_AWS_IAM_ROLE_ARN>   -> arn:aws:iam::<account_id>:role/SnowflakeHealthcareRole
    <YOUR_SNS_TOPIC_ARN>      -> arn:aws:sns:us-east-1:<account_id>:healthcare-ai-file-notifications
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTHCARE_AI_DEMO;
USE WAREHOUSE HEALTHCARE_AI_WH;

/*=========================================================================
  SECTION 1: S3 STORAGE INTEGRATION
  
  This creates the trust relationship between Snowflake and your AWS S3
  bucket. Snowflake assumes an IAM role in your account to read files.
=========================================================================*/

-----------------------------------------------------------------------
-- 1A. CREATE STORAGE INTEGRATION
-----------------------------------------------------------------------
CREATE OR REPLACE STORAGE INTEGRATION HEALTHCARE_S3_INTEGRATION
  TYPE                      = EXTERNAL_STAGE
  STORAGE_PROVIDER          = 'S3'
  ENABLED                   = TRUE
  STORAGE_AWS_ROLE_ARN      = '<YOUR_AWS_IAM_ROLE_ARN>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<YOUR_S3_BUCKET_NAME>/healthcare/')
  COMMENT = 'Storage integration for Healthcare AI demo S3 bucket';

-----------------------------------------------------------------------
-- 1B. DESCRIBE INTEGRATION — get Snowflake's IAM user ARN & external ID
--     You MUST update your AWS IAM role trust policy with these values.
-----------------------------------------------------------------------
DESCRIBE INTEGRATION HEALTHCARE_S3_INTEGRATION;

-- Record these two values from the output:
--   STORAGE_AWS_IAM_USER_ARN   -> e.g. arn:aws:iam::123456789012:user/abc1-b-self1234
--   STORAGE_AWS_EXTERNAL_ID    -> e.g. ABC12345_SFCRole=2_abcdefg123456

-- Then update your AWS IAM role trust policy (see 10_aws_setup_guide.sql Step 4):
--   aws iam update-assume-role-policy \
--     --role-name SnowflakeHealthcareRole \
--     --policy-document file://snowflake-trust-policy.json

-----------------------------------------------------------------------
-- 1C. VERIFY STORAGE INTEGRATION IS ACTIVE
-----------------------------------------------------------------------
SHOW INTEGRATIONS LIKE 'HEALTHCARE_S3%';

-- Confirm ENABLED = true and TYPE = EXTERNAL_STAGE
SELECT "name", "type", "category", "enabled", "created_on"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" = 'HEALTHCARE_S3_INTEGRATION';

-----------------------------------------------------------------------
-- 1D. GRANT USAGE ON INTEGRATION (if using roles other than ACCOUNTADMIN)
-----------------------------------------------------------------------
GRANT USAGE ON INTEGRATION HEALTHCARE_S3_INTEGRATION TO ROLE SYSADMIN;


/*=========================================================================
  SECTION 2: EXTERNAL STAGES (linked to the storage integration)
  
  Three stages, one per file type prefix in S3.
=========================================================================*/

-----------------------------------------------------------------------
-- 2A. CREATE STAGES
-----------------------------------------------------------------------
CREATE OR REPLACE STAGE RAW.S3_MEDICAL_DOCS
  URL                 = 's3://<YOUR_S3_BUCKET_NAME>/healthcare/pdfs/'
  STORAGE_INTEGRATION = HEALTHCARE_S3_INTEGRATION
  DIRECTORY           = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'S3 stage for incoming medical PDF documents';

CREATE OR REPLACE STAGE RAW.S3_MEDICAL_TXT
  URL                 = 's3://<YOUR_S3_BUCKET_NAME>/healthcare/txt/'
  STORAGE_INTEGRATION = HEALTHCARE_S3_INTEGRATION
  DIRECTORY           = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'S3 stage for incoming medical text documents';

CREATE OR REPLACE STAGE RAW.S3_MEDICAL_AUDIO
  URL                 = 's3://<YOUR_S3_BUCKET_NAME>/healthcare/audio/'
  STORAGE_INTEGRATION = HEALTHCARE_S3_INTEGRATION
  DIRECTORY           = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'S3 stage for incoming patient consultation audio files (WAV and MP3)';

-----------------------------------------------------------------------
-- 2B. VERIFY STAGES CREATED
-----------------------------------------------------------------------
SHOW STAGES IN SCHEMA RAW;


/*=========================================================================
  SECTION 3: SNS NOTIFICATION INTEGRATION
  
  This allows Snowpipe to subscribe to your SNS topic and receive
  notifications when new files land in S3 via EventBridge.
  
  Flow: S3 -> EventBridge -> SNS -> Snowpipe (auto_ingest)
=========================================================================*/

-----------------------------------------------------------------------
-- 3A. GET THE SNS IAM POLICY THAT SNOWFLAKE NEEDS
--     Run this to generate the policy JSON. You must apply this policy
--     to your SNS topic in AWS (see 10_aws_setup_guide.sql Step 7).
-----------------------------------------------------------------------
SELECT SYSTEM$GET_AWS_SNS_IAM_POLICY(
  'arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications'
) AS SNS_IAM_POLICY;

-- The output will look like:
-- {
--   "Version": "2012-10-17",
--   "Statement": [{
--     "Sid": "1",
--     "Effect": "Allow",
--     "Principal": {"AWS": "arn:aws:iam::123456789012:user/..."},
--     "Action": ["sns:subscribe"],
--     "Resource": ["arn:aws:sns:us-east-1:...:healthcare-ai-file-notifications"]
--   }]
-- }
--
-- IMPORTANT: Merge this with the EventBridge publish policy on your SNS topic.
-- See 10_aws_setup_guide.sql Step 7 for the full combined policy.

-----------------------------------------------------------------------
-- 3B. CREATE NOTIFICATION INTEGRATION
--     This is the Snowflake object that subscribes to SNS.
-----------------------------------------------------------------------
CREATE OR REPLACE NOTIFICATION INTEGRATION HEALTHCARE_SNS_NOTIFICATION
  ENABLED            = TRUE
  TYPE               = QUEUE
  NOTIFICATION_PROVIDER = AWS_SNS
  DIRECTION          = INBOUND
  AWS_SNS_TOPIC_ARN  = 'arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications'
  AWS_SNS_ROLE_ARN   = '<YOUR_AWS_IAM_ROLE_ARN>'
  COMMENT = 'SNS notification integration for S3 file arrival events via EventBridge';

-----------------------------------------------------------------------
-- 3C. DESCRIBE NOTIFICATION INTEGRATION
-----------------------------------------------------------------------
DESCRIBE NOTIFICATION INTEGRATION HEALTHCARE_SNS_NOTIFICATION;

-- Record the SF_AWS_IAM_USER_ARN and SF_AWS_EXTERNAL_ID if different
-- from the storage integration values.

-----------------------------------------------------------------------
-- 3D. VERIFY NOTIFICATION INTEGRATION
-----------------------------------------------------------------------
SHOW NOTIFICATION INTEGRATIONS;

SELECT "name", "type", "enabled", "created_on"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" = 'HEALTHCARE_SNS_NOTIFICATION';

-----------------------------------------------------------------------
-- 3E. GRANT USAGE ON NOTIFICATION INTEGRATION
-----------------------------------------------------------------------
GRANT USAGE ON INTEGRATION HEALTHCARE_SNS_NOTIFICATION TO ROLE SYSADMIN;


/*=========================================================================
  SECTION 4: SNOWPIPES WITH SNS AUTO-INGEST
  
  These pipes use AWS_SNS_TOPIC to automatically trigger when new files
  land in S3. Each pipe handles one file type prefix.
=========================================================================*/

-----------------------------------------------------------------------
-- 4A. SNOWPIPE FOR PDFs
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_DOCS
  AUTO_INGEST = TRUE
  AWS_SNS_TOPIC = 'arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications'
  COMMENT = 'Auto-ingest pipe for PDF medical documents from S3'
AS
  COPY INTO RAW.FILES_LOG (FILE_NAME, FILE_PATH, FILE_TYPE, FILE_SIZE_BYTES, S3_EVENT_TIME)
  FROM (
    SELECT
      METADATA$FILENAME                               AS FILE_NAME,
      METADATA$FILENAME                               AS FILE_PATH,
      'PDF'                                           AS FILE_TYPE,
      METADATA$FILE_CONTENT_KEY                       AS FILE_SIZE_BYTES,
      METADATA$START_SCAN_TIME                        AS S3_EVENT_TIME
    FROM @RAW.S3_MEDICAL_DOCS
  )
  FILE_FORMAT = (TYPE = 'JSON');

-----------------------------------------------------------------------
-- 4B. SNOWPIPE FOR TXT FILES
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_TXT
  AUTO_INGEST = TRUE
  AWS_SNS_TOPIC = 'arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications'
  COMMENT = 'Auto-ingest pipe for TXT medical documents from S3'
AS
  COPY INTO RAW.FILES_LOG (FILE_NAME, FILE_PATH, FILE_TYPE, FILE_SIZE_BYTES, S3_EVENT_TIME)
  FROM (
    SELECT
      METADATA$FILENAME                               AS FILE_NAME,
      METADATA$FILENAME                               AS FILE_PATH,
      'TXT'                                           AS FILE_TYPE,
      METADATA$FILE_CONTENT_KEY                       AS FILE_SIZE_BYTES,
      METADATA$START_SCAN_TIME                        AS S3_EVENT_TIME
    FROM @RAW.S3_MEDICAL_TXT
  )
  FILE_FORMAT = (TYPE = 'JSON');

-----------------------------------------------------------------------
-- 4C. SNOWPIPE FOR AUDIO (WAV and MP3)
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_AUDIO
  AUTO_INGEST = TRUE
  AWS_SNS_TOPIC = 'arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications'
  COMMENT = 'Auto-ingest pipe for WAV/MP3 audio consultations from S3'
AS
  COPY INTO RAW.FILES_LOG (FILE_NAME, FILE_PATH, FILE_TYPE, FILE_SIZE_BYTES, S3_EVENT_TIME)
  FROM (
    SELECT
      METADATA$FILENAME                               AS FILE_NAME,
      METADATA$FILENAME                               AS FILE_PATH,
      CASE
        WHEN UPPER(METADATA$FILENAME) LIKE '%.MP3' THEN 'MP3'
        ELSE 'WAV'
      END                                             AS FILE_TYPE,
      METADATA$FILE_CONTENT_KEY                       AS FILE_SIZE_BYTES,
      METADATA$START_SCAN_TIME                        AS S3_EVENT_TIME
    FROM @RAW.S3_MEDICAL_AUDIO
  )
  FILE_FORMAT = (TYPE = 'JSON');

-----------------------------------------------------------------------
-- 4D. VERIFY PIPES & GET SNS SUBSCRIPTION STATUS
-----------------------------------------------------------------------
SHOW PIPES IN SCHEMA RAW;

SELECT SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_DOCS')  AS DOCS_PIPE_STATUS;
SELECT SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_TXT')   AS TXT_PIPE_STATUS;
SELECT SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_AUDIO') AS AUDIO_PIPE_STATUS;


/*=========================================================================
  SECTION 5: READ & LIST FILES FROM S3 STAGES
  
  These queries verify that Snowflake can successfully access your S3
  bucket through the storage integration. Run these AFTER uploading
  sample files to S3.
=========================================================================*/

-----------------------------------------------------------------------
-- 5A. LIST FILES ON EACH STAGE
--     Confirms S3 connectivity and IAM permissions are working.
-----------------------------------------------------------------------
LIST @RAW.S3_MEDICAL_DOCS;
LIST @RAW.S3_MEDICAL_TXT;
LIST @RAW.S3_MEDICAL_AUDIO;

-----------------------------------------------------------------------
-- 5B. COUNT FILES PER STAGE
-----------------------------------------------------------------------
SELECT 'PDFs'  AS FILE_TYPE, COUNT(*) AS FILE_COUNT FROM DIRECTORY(@RAW.S3_MEDICAL_DOCS)
UNION ALL
SELECT 'TXT'   AS FILE_TYPE, COUNT(*) AS FILE_COUNT FROM DIRECTORY(@RAW.S3_MEDICAL_TXT)
UNION ALL
SELECT 'Audio' AS FILE_TYPE, COUNT(*) AS FILE_COUNT FROM DIRECTORY(@RAW.S3_MEDICAL_AUDIO);

-----------------------------------------------------------------------
-- 5C. LIST FILES WITH DETAILS (name, size, last modified)
-----------------------------------------------------------------------

-- PDF files
SELECT
  RELATIVE_PATH                           AS FILE_NAME,
  SIZE                                    AS FILE_SIZE_BYTES,
  ROUND(SIZE / 1024.0, 1)                AS FILE_SIZE_KB,
  LAST_MODIFIED                           AS LAST_MODIFIED
FROM DIRECTORY(@RAW.S3_MEDICAL_DOCS)
ORDER BY LAST_MODIFIED DESC;

-- TXT files
SELECT
  RELATIVE_PATH                           AS FILE_NAME,
  SIZE                                    AS FILE_SIZE_BYTES,
  ROUND(SIZE / 1024.0, 1)                AS FILE_SIZE_KB,
  LAST_MODIFIED                           AS LAST_MODIFIED
FROM DIRECTORY(@RAW.S3_MEDICAL_TXT)
ORDER BY LAST_MODIFIED DESC;

-- Audio files (WAV + MP3)
SELECT
  RELATIVE_PATH                           AS FILE_NAME,
  SIZE                                    AS FILE_SIZE_BYTES,
  ROUND(SIZE / 1024.0 / 1024.0, 2)       AS FILE_SIZE_MB,
  LAST_MODIFIED                           AS LAST_MODIFIED,
  CASE
    WHEN UPPER(RELATIVE_PATH) LIKE '%.MP3' THEN 'MP3'
    WHEN UPPER(RELATIVE_PATH) LIKE '%.WAV' THEN 'WAV'
    ELSE 'UNKNOWN'
  END                                     AS AUDIO_FORMAT
FROM DIRECTORY(@RAW.S3_MEDICAL_AUDIO)
ORDER BY LAST_MODIFIED DESC;

-----------------------------------------------------------------------
-- 5D. READ FILE CONTENT PREVIEW
--     Verify Snowflake can actually read the file contents (not just list).
-----------------------------------------------------------------------

-- Preview a PDF file (read raw bytes reference)
SELECT
  RELATIVE_PATH                           AS FILE_NAME,
  TO_FILE('@RAW.S3_MEDICAL_DOCS', RELATIVE_PATH) AS FILE_REFERENCE,
  SIZE                                    AS FILE_SIZE_BYTES
FROM DIRECTORY(@RAW.S3_MEDICAL_DOCS)
LIMIT 1;

-- Preview a TXT file (read actual text content via AI_COMPLETE)
SELECT
  RELATIVE_PATH                           AS FILE_NAME,
  LEFT(
    AI_COMPLETE(
      'claude-3.5-sonnet',
      CONCAT('Return the first 500 characters of this document exactly as-is:\n\n',
        TO_VARCHAR(TO_FILE('@RAW.S3_MEDICAL_TXT', RELATIVE_PATH)))
    ), 500
  )                                       AS CONTENT_PREVIEW
FROM DIRECTORY(@RAW.S3_MEDICAL_TXT)
LIMIT 1;

-- Preview an audio file reference (verify stage access for AI_TRANSCRIBE)
SELECT
  RELATIVE_PATH                           AS FILE_NAME,
  TO_FILE('@RAW.S3_MEDICAL_AUDIO', RELATIVE_PATH) AS FILE_REFERENCE,
  SIZE                                    AS FILE_SIZE_BYTES,
  ROUND(SIZE / 1024.0 / 1024.0, 2)       AS FILE_SIZE_MB
FROM DIRECTORY(@RAW.S3_MEDICAL_AUDIO)
LIMIT 1;

-----------------------------------------------------------------------
-- 5E. QUICK AI FUNCTION TEST ON STAGED FILES
--     Run a single AI function on one file from each stage to confirm
--     the full pipeline (S3 -> Stage -> AI Function) works end to end.
-----------------------------------------------------------------------

-- Test AI_PARSE_DOCUMENT on first PDF
SELECT
  d.RELATIVE_PATH                         AS FILE_NAME,
  LEFT(
    AI_PARSE_DOCUMENT(
      TO_FILE('@RAW.S3_MEDICAL_DOCS', d.RELATIVE_PATH), 'OCR'
    ):content::VARCHAR,
    300
  )                                       AS PARSED_TEXT_PREVIEW
FROM DIRECTORY(@RAW.S3_MEDICAL_DOCS) d
LIMIT 1;

-- Test AI_TRANSCRIBE on first audio file
SELECT
  d.RELATIVE_PATH                         AS FILE_NAME,
  LEFT(
    AI_TRANSCRIBE(
      TO_FILE('@RAW.S3_MEDICAL_AUDIO', d.RELATIVE_PATH),
      OBJECT_CONSTRUCT('mode', 'transcript')
    ):text::VARCHAR,
    300
  )                                       AS TRANSCRIPT_PREVIEW
FROM DIRECTORY(@RAW.S3_MEDICAL_AUDIO) d
LIMIT 1;


/*=========================================================================
  SECTION 6: FILES_LOG VERIFICATION
  
  After Snowpipe ingests file metadata, verify the landing zone.
=========================================================================*/

-----------------------------------------------------------------------
-- 6A. CHECK FILES_LOG TABLE
-----------------------------------------------------------------------
SELECT FILE_ID, FILE_NAME, FILE_TYPE, FILE_SIZE_BYTES,
       LANDED_AT, IS_PROCESSED, PROCESSED_AT
FROM RAW.FILES_LOG
ORDER BY LANDED_AT DESC;

-----------------------------------------------------------------------
-- 6B. FILE COUNT BY TYPE AND STATUS
-----------------------------------------------------------------------
SELECT
  FILE_TYPE,
  COUNT(*)                                            AS TOTAL_FILES,
  SUM(CASE WHEN IS_PROCESSED THEN 1 ELSE 0 END)      AS PROCESSED,
  SUM(CASE WHEN NOT IS_PROCESSED THEN 1 ELSE 0 END)   AS PENDING
FROM RAW.FILES_LOG
GROUP BY FILE_TYPE
ORDER BY FILE_TYPE;

-----------------------------------------------------------------------
-- 6C. CHECK STREAM HAS DATA (unprocessed files waiting)
-----------------------------------------------------------------------
SELECT SYSTEM$STREAM_HAS_DATA('RAW.FILES_LOG_STREAM') AS HAS_UNPROCESSED_FILES;

-----------------------------------------------------------------------
-- 6D. MANUALLY REFRESH PIPES (if auto-ingest hasn't triggered yet)
-----------------------------------------------------------------------
-- ALTER PIPE RAW.PIPE_MEDICAL_DOCS  REFRESH;
-- ALTER PIPE RAW.PIPE_MEDICAL_TXT   REFRESH;
-- ALTER PIPE RAW.PIPE_MEDICAL_AUDIO REFRESH;

-----------------------------------------------------------------------
-- 6E. CHECK PIPE COPY HISTORY (troubleshoot ingest issues)
-----------------------------------------------------------------------
SELECT PIPE_NAME, FILE_NAME, STATUS, ROW_COUNT, ERROR_MESSAGE, LAST_LOAD_TIME
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME   => 'RAW.FILES_LOG',
  START_TIME   => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 20;


/*=========================================================================
  SECTION 7: RESUME PIPES AND TASK (final step)
  
  Run this once everything above is verified.
=========================================================================*/

-- Resume all Snowpipes
ALTER PIPE RAW.PIPE_MEDICAL_DOCS  SET PIPE_EXECUTION_PAUSED = FALSE;
ALTER PIPE RAW.PIPE_MEDICAL_TXT   SET PIPE_EXECUTION_PAUSED = FALSE;
ALTER PIPE RAW.PIPE_MEDICAL_AUDIO SET PIPE_EXECUTION_PAUSED = FALSE;

-- Resume the processing task
ALTER TASK RAW.PROCESS_NEW_FILES_TASK RESUME;

-- Final status check
SELECT 'PIPE_MEDICAL_DOCS'  AS OBJECT, SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_DOCS')  AS STATUS
UNION ALL
SELECT 'PIPE_MEDICAL_TXT',           SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_TXT')
UNION ALL
SELECT 'PIPE_MEDICAL_AUDIO',         SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_AUDIO');

SHOW TASKS LIKE 'PROCESS_NEW_FILES_TASK' IN SCHEMA RAW;
