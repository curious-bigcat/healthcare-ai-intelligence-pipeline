/*=============================================================================
  01 - DATABASE, SCHEMAS, WAREHOUSE, STORAGE INTEGRATION & STAGES
  Healthcare AI Intelligence Pipeline — FRESH SETUP (no reuse of existing objects)

  Prerequisites:
    - ACCOUNTADMIN role
    - An S3 bucket created in AWS (us-east-1) with folders:
        healthcare/pdfs/
        healthcare/txt/
        healthcare/audio/
    - An IAM role with S3 read access, trust policy configured for Snowflake
      (see 10_aws_setup_guide.sql for IAM role creation steps)

  IMPORTANT: Replace the placeholders below:
    <YOUR_S3_BUCKET_NAME>   → your actual S3 bucket name
    <YOUR_AWS_IAM_ROLE_ARN> → arn:aws:iam::<account_id>:role/<role_name>
=============================================================================*/

USE ROLE ACCOUNTADMIN;

-----------------------------------------------------------------------
-- 1. DATABASE
-----------------------------------------------------------------------
CREATE OR REPLACE DATABASE HEALTHCARE_AI_DEMO
  COMMENT = 'Healthcare AI Intelligence Pipeline: PDF medical reports + audio consultations processed with 11 Cortex AI functions';

-----------------------------------------------------------------------
-- 2. SCHEMAS
-----------------------------------------------------------------------
CREATE SCHEMA HEALTHCARE_AI_DEMO.RAW
  COMMENT = 'Landing zone for raw file metadata from S3 via Snowpipe';

CREATE SCHEMA HEALTHCARE_AI_DEMO.PROCESSED
  COMMENT = 'AI-enriched document and audio intelligence tables';

CREATE SCHEMA HEALTHCARE_AI_DEMO.ANALYTICS
  COMMENT = 'Structured analytics, semantic views, Cortex Search, and Agent';

-----------------------------------------------------------------------
-- 3. WAREHOUSE
-----------------------------------------------------------------------
CREATE OR REPLACE WAREHOUSE HEALTHCARE_AI_WH
  WAREHOUSE_SIZE      = 'XSMALL'
  AUTO_SUSPEND        = 60
  AUTO_RESUME         = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse for Healthcare AI demo processing';

USE WAREHOUSE HEALTHCARE_AI_WH;

-----------------------------------------------------------------------
-- 4. STORAGE INTEGRATION (new — connects Snowflake to your S3 bucket)
-----------------------------------------------------------------------
CREATE OR REPLACE STORAGE INTEGRATION HEALTHCARE_S3_INTEGRATION
  TYPE                      = EXTERNAL_STAGE
  STORAGE_PROVIDER          = 'S3'
  ENABLED                   = TRUE
  STORAGE_AWS_ROLE_ARN      = '<YOUR_AWS_IAM_ROLE_ARN>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<YOUR_S3_BUCKET_NAME>/healthcare/')
  COMMENT = 'Storage integration for Healthcare AI demo S3 bucket';

-- After creating, run this to get the Snowflake IAM user ARN and external ID
-- needed for the AWS trust policy on your IAM role:
DESCRIBE INTEGRATION HEALTHCARE_S3_INTEGRATION;
-- Note STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID values
-- and update your AWS IAM role trust policy (see 10_aws_setup_guide.sql)

-----------------------------------------------------------------------
-- 5. EXTERNAL STAGES
-----------------------------------------------------------------------
CREATE OR REPLACE STAGE HEALTHCARE_AI_DEMO.RAW.S3_MEDICAL_DOCS
  URL                 = 's3://<YOUR_S3_BUCKET_NAME>/healthcare/pdfs/'
  STORAGE_INTEGRATION = HEALTHCARE_S3_INTEGRATION
  DIRECTORY           = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'S3 stage for incoming medical PDF documents';

CREATE OR REPLACE STAGE HEALTHCARE_AI_DEMO.RAW.S3_MEDICAL_TXT
  URL                 = 's3://<YOUR_S3_BUCKET_NAME>/healthcare/txt/'
  STORAGE_INTEGRATION = HEALTHCARE_S3_INTEGRATION
  DIRECTORY           = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'S3 stage for incoming medical text documents';

CREATE OR REPLACE STAGE HEALTHCARE_AI_DEMO.RAW.S3_MEDICAL_AUDIO
  URL                 = 's3://<YOUR_S3_BUCKET_NAME>/healthcare/audio/'
  STORAGE_INTEGRATION = HEALTHCARE_S3_INTEGRATION
  DIRECTORY           = (ENABLE = TRUE AUTO_REFRESH = TRUE)
  COMMENT = 'S3 stage for incoming patient consultation audio files (WAV and MP3)';

-----------------------------------------------------------------------
-- 6. INTERNAL STAGE (for semantic model YAML)
-----------------------------------------------------------------------
CREATE OR REPLACE STAGE HEALTHCARE_AI_DEMO.ANALYTICS.SEMANTIC_MODELS
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Internal stage for semantic model YAML files';

-----------------------------------------------------------------------
-- 7. VERIFY
-----------------------------------------------------------------------
SHOW INTEGRATIONS LIKE 'HEALTHCARE%';
SHOW STAGES IN DATABASE HEALTHCARE_AI_DEMO;
