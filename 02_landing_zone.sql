/*=============================================================================
  02 - LANDING ZONE: File Log Table, Snowpipe (SQS), Stream & Task Trigger
  Healthcare AI Intelligence Pipeline

  Flow:
    S3 file upload -> S3 Event Notification -> SQS Queue -> Snowpipe (auto_ingest)
    -> RAW.FILES_LOG -> Stream -> Task -> calls PROCESS_NEW_FILES() proc

  Snowpipe auto-ingest on AWS uses SQS (not SNS). When you create a pipe
  with AUTO_INGEST = TRUE, Snowflake provisions an SQS queue. You configure
  S3 event notifications to send to that SQS queue.

  Steps:
    1. Create the pipes (AUTO_INGEST = TRUE)
    2. Run SHOW PIPES to get the notification_channel (SQS queue ARN)
    3. Configure S3 bucket event notifications to send to that SQS queue
       (see 10_aws_setup_guide.sql and 12_s3_sqs_integration_and_file_read.sql)
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTHCARE_AI_DEMO;
USE SCHEMA RAW;
USE WAREHOUSE HEALTHCARE_AI_WH;

-----------------------------------------------------------------------
-- 1. FILE LOG TABLE -- every file that lands in S3 gets a row here
-----------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.FILES_LOG (
    FILE_ID         NUMBER AUTOINCREMENT PRIMARY KEY,
    FILE_NAME       VARCHAR        NOT NULL,
    FILE_PATH       VARCHAR        NOT NULL,
    FILE_TYPE       VARCHAR(10)    NOT NULL COMMENT 'PDF, TXT, WAV, or MP3',
    FILE_SIZE_BYTES NUMBER,
    S3_EVENT_TIME   TIMESTAMP_NTZ,
    LANDED_AT       TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    IS_PROCESSED    BOOLEAN        DEFAULT FALSE,
    PROCESSED_AT    TIMESTAMP_NTZ
);

-----------------------------------------------------------------------
-- 2. FILE FORMAT -- to parse S3 event notification JSON
-----------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT RAW.S3_EVENT_JSON
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE;

-----------------------------------------------------------------------
-- 3. SNOWPIPE FOR PDFs
--    AUTO_INGEST = TRUE tells Snowflake to provision an SQS queue.
--    After creation, run: SHOW PIPES to get the notification_channel
--    (the SQS queue ARN) and configure S3 event notifications.
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_DOCS
  AUTO_INGEST = TRUE
  COMMENT = 'Auto-ingest pipe for PDF medical documents from S3 via SQS'
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

-- Get SQS queue ARN for this pipe
DESC PIPE RAW.PIPE_MEDICAL_DOCS;

-----------------------------------------------------------------------
-- 4. SNOWPIPE FOR TXT
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_TXT
  AUTO_INGEST = TRUE
  COMMENT = 'Auto-ingest pipe for TXT medical documents from S3 via SQS'
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

-- Get SQS queue ARN for this pipe
DESC PIPE RAW.PIPE_MEDICAL_TXT;

-----------------------------------------------------------------------
-- 5. SNOWPIPE FOR AUDIO (WAV and MP3)
--    FILE_TYPE is determined by file extension
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_AUDIO
  AUTO_INGEST = TRUE
  COMMENT = 'Auto-ingest pipe for WAV/MP3 audio consultations from S3 via SQS'
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

-- Get SQS queue ARN for this pipe
DESC PIPE RAW.PIPE_MEDICAL_AUDIO;

-----------------------------------------------------------------------
-- 6. GET SQS QUEUE ARNs FROM ALL PIPES
--    The notification_channel column contains the Snowflake-managed
--    SQS queue ARN. You need this for configuring S3 event notifications.
--
--    All 3 pipes share the SAME SQS queue ARN (Snowflake manages one
--    SQS queue per account). Copy this ARN for the S3 setup step.
-----------------------------------------------------------------------
SHOW PIPES IN SCHEMA RAW;

-- Look at the notification_channel column in the output.
-- It will look like: arn:aws:sqs:us-east-1:123456789012:sf-snowpipe-AIDXYZ-HASH
-- Save this value -- you need it in Step 5 of 10_aws_setup_guide.sql.

-----------------------------------------------------------------------
-- 7. STREAM on FILES_LOG -- captures new inserts
-----------------------------------------------------------------------
CREATE OR REPLACE STREAM RAW.FILES_LOG_STREAM
  ON TABLE RAW.FILES_LOG
  APPEND_ONLY = TRUE
  COMMENT = 'Captures new file arrivals for AI processing';

-----------------------------------------------------------------------
-- 8. TASK -- triggered by stream, calls the AI processing stored proc
--    (The stored procedure is defined in 04_stored_procedure.sql)
-----------------------------------------------------------------------
CREATE OR REPLACE TASK RAW.PROCESS_NEW_FILES_TASK
  WAREHOUSE = HEALTHCARE_AI_WH
  SCHEDULE  = '1 MINUTE'
  COMMENT   = 'Polls stream for new files and triggers AI processing'
  WHEN SYSTEM$STREAM_HAS_DATA('RAW.FILES_LOG_STREAM')
AS
  CALL PROCESSED.PROCESS_NEW_FILES();

-- Task is created in suspended state; resume after proc is created:
-- ALTER TASK RAW.PROCESS_NEW_FILES_TASK RESUME;

-----------------------------------------------------------------------
-- 9. VERIFY
-----------------------------------------------------------------------
SHOW PIPES IN SCHEMA RAW;
SHOW STREAMS IN SCHEMA RAW;
SHOW TASKS IN SCHEMA RAW;

-- Check pipe status
SELECT SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_DOCS')  AS DOCS_PIPE_STATUS;
SELECT SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_TXT')   AS TXT_PIPE_STATUS;
SELECT SYSTEM$PIPE_STATUS('RAW.PIPE_MEDICAL_AUDIO') AS AUDIO_PIPE_STATUS;
