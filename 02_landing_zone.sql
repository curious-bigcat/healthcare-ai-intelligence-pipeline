/*=============================================================================
  02 - LANDING ZONE: File Log Table, Snowpipe, Stream & Task Trigger
  Healthcare AI Intelligence Pipeline

  Flow:
    S3 file upload → EventBridge → SNS → Snowpipe (auto_ingest)
    → RAW.FILES_LOG → Stream → Task → calls PROCESS_NEW_FILES() proc

  IMPORTANT: Replace <YOUR_SNS_TOPIC_ARN> with your actual SNS topic ARN
             e.g. arn:aws:sns:us-east-1:123456789012:healthcare-ai-file-notifications
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTHCARE_AI_DEMO;
USE SCHEMA RAW;
USE WAREHOUSE HEALTHCARE_AI_WH;

-----------------------------------------------------------------------
-- 1. FILE LOG TABLE — every file that lands in S3 gets a row here
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
-- 2. FILE FORMAT — to parse S3 event notification JSON
-----------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT RAW.S3_EVENT_JSON
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE;

-----------------------------------------------------------------------
-- 3. SNOWPIPE FOR PDFs
--    Auto-ingests file metadata when PDFs land in S3
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_DOCS
  AUTO_INGEST = TRUE
  AWS_SNS_TOPIC = '<YOUR_SNS_TOPIC_ARN>'
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
-- 4. SNOWPIPE FOR TXT
--    Auto-ingests file metadata when TXT files land in S3
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_TXT
  AUTO_INGEST = TRUE
  AWS_SNS_TOPIC = '<YOUR_SNS_TOPIC_ARN>'
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
-- 5. SNOWPIPE FOR AUDIO (WAV and MP3)
--    Auto-ingests file metadata when audio files land in S3
--    FILE_TYPE is determined by extension in the processing proc
-----------------------------------------------------------------------
CREATE OR REPLACE PIPE RAW.PIPE_MEDICAL_AUDIO
  AUTO_INGEST = TRUE
  AWS_SNS_TOPIC = '<YOUR_SNS_TOPIC_ARN>'
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
-- 5. STREAM on FILES_LOG — captures new inserts
-----------------------------------------------------------------------
CREATE OR REPLACE STREAM RAW.FILES_LOG_STREAM
  ON TABLE RAW.FILES_LOG
  APPEND_ONLY = TRUE
  COMMENT = 'Captures new file arrivals for AI processing';

-----------------------------------------------------------------------
-- 6. TASK — triggered by stream, calls the AI processing stored proc
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
-- 7. VERIFY & GET SNS POLICY
-----------------------------------------------------------------------
SHOW PIPES IN SCHEMA RAW;

-- Run this to get the IAM policy needed for your SNS topic:
-- SELECT SYSTEM$GET_AWS_SNS_IAM_POLICY('<YOUR_SNS_TOPIC_ARN>');
