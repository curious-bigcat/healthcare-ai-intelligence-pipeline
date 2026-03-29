/*=============================================================================
  10 - AWS SETUP GUIDE: S3 Bucket, IAM Role, S3 Event Notifications -> SQS
  Healthcare AI Intelligence Pipeline

  This file documents the AWS-side configuration required to complete
  the auto-ingest pipeline. Run these commands in AWS CLI or configure
  via the AWS Console.

  Architecture (using Snowflake-managed SQS):
    S3 (file upload) -> S3 Event Notification -> SQS (Snowflake-managed) -> Snowpipe

  NOTE: Snowpipe AUTO_INGEST on AWS uses SQS. When you create a pipe with
  AUTO_INGEST = TRUE, Snowflake provisions and manages an SQS queue for you.
  You simply configure S3 to send event notifications to that SQS queue.
  No SNS topic, EventBridge rule, or notification integration is needed.
=============================================================================*/

-----------------------------------------------------------------------
-- STEP 1: CREATE S3 BUCKET
-----------------------------------------------------------------------
/*
  Run in AWS CLI:

  aws s3 mb s3://healthcare-ai-demo-<YOUR_ACCOUNT_ID> --region us-east-1

  Create the folder structure:

  aws s3api put-object --bucket healthcare-ai-demo-<YOUR_ACCOUNT_ID> --key healthcare/pdfs/
  aws s3api put-object --bucket healthcare-ai-demo-<YOUR_ACCOUNT_ID> --key healthcare/txt/
  aws s3api put-object --bucket healthcare-ai-demo-<YOUR_ACCOUNT_ID> --key healthcare/audio/
*/

-----------------------------------------------------------------------
-- STEP 2: CREATE IAM POLICY FOR SNOWFLAKE S3 ACCESS
-----------------------------------------------------------------------
/*
  Create a policy file (snowflake-s3-policy.json):

  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource": [
          "arn:aws:s3:::healthcare-ai-demo-<YOUR_ACCOUNT_ID>",
          "arn:aws:s3:::healthcare-ai-demo-<YOUR_ACCOUNT_ID>/healthcare/*"
        ]
      }
    ]
  }

  aws iam create-policy \
    --policy-name SnowflakeHealthcareS3Access \
    --policy-document file://snowflake-s3-policy.json
*/

-----------------------------------------------------------------------
-- STEP 3: CREATE IAM ROLE FOR SNOWFLAKE
-----------------------------------------------------------------------
/*
  Create trust policy file (snowflake-trust-policy.json).
  Initially use a placeholder; you will update after DESCRIBE INTEGRATION.

  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "<STORAGE_AWS_IAM_USER_ARN from DESCRIBE INTEGRATION>"
        },
        "Action": "sts:AssumeRole",
        "Condition": {
          "StringEquals": {
            "sts:ExternalId": "<STORAGE_AWS_EXTERNAL_ID from DESCRIBE INTEGRATION>"
          }
        }
      }
    ]
  }

  aws iam create-role \
    --role-name SnowflakeHealthcareRole \
    --assume-role-policy-document file://snowflake-trust-policy.json

  aws iam attach-role-policy \
    --role-name SnowflakeHealthcareRole \
    --policy-arn arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:policy/SnowflakeHealthcareS3Access

  Note the Role ARN: arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/SnowflakeHealthcareRole
  Use this in 01_setup_database.sql for STORAGE_AWS_ROLE_ARN.
*/

-----------------------------------------------------------------------
-- STEP 4: GET SNOWFLAKE IAM USER ARN & EXTERNAL ID
-----------------------------------------------------------------------
-- After running 01_setup_database.sql, execute:
DESCRIBE INTEGRATION HEALTHCARE_S3_INTEGRATION;
-- Record: STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID
-- Update the trust policy in Step 3 with these values, then:
/*
  aws iam update-assume-role-policy \
    --role-name SnowflakeHealthcareRole \
    --policy-document file://snowflake-trust-policy.json
*/

-----------------------------------------------------------------------
-- STEP 5: CONFIGURE S3 EVENT NOTIFICATIONS -> SNOWFLAKE SQS QUEUE
--
--   Snowpipe AUTO_INGEST provisions an SQS queue managed by Snowflake.
--   After creating the pipes in 02_landing_zone.sql, get the SQS ARN:
-----------------------------------------------------------------------
SHOW PIPES IN DATABASE HEALTHCARE_AI_DEMO;
-- Look at the notification_channel column. It will look like:
-- arn:aws:sqs:us-east-1:123456789012:sf-snowpipe-AIDXYZ-HASH
--
-- All pipes in the same account share the same SQS queue ARN.
-- Copy this ARN for the S3 event notification configuration below.

/*
  OPTION A: AWS CLI — Configure S3 event notifications to Snowflake's SQS queue

  Create a notification config file (s3-event-notification.json):

  {
    "QueueConfigurations": [
      {
        "Id": "SnowpipePDFs",
        "QueueArn": "<SQS_QUEUE_ARN_FROM_SHOW_PIPES>",
        "Events": ["s3:ObjectCreated:*"],
        "Filter": {
          "Key": {
            "FilterRules": [
              {"Name": "prefix", "Value": "healthcare/pdfs/"}
            ]
          }
        }
      },
      {
        "Id": "SnowpipeTXT",
        "QueueArn": "<SQS_QUEUE_ARN_FROM_SHOW_PIPES>",
        "Events": ["s3:ObjectCreated:*"],
        "Filter": {
          "Key": {
            "FilterRules": [
              {"Name": "prefix", "Value": "healthcare/txt/"}
            ]
          }
        }
      },
      {
        "Id": "SnowpipeAudio",
        "QueueArn": "<SQS_QUEUE_ARN_FROM_SHOW_PIPES>",
        "Events": ["s3:ObjectCreated:*"],
        "Filter": {
          "Key": {
            "FilterRules": [
              {"Name": "prefix", "Value": "healthcare/audio/"}
            ]
          }
        }
      }
    ]
  }

  aws s3api put-bucket-notification-configuration \
    --bucket healthcare-ai-demo-<YOUR_ACCOUNT_ID> \
    --notification-configuration file://s3-event-notification.json


  OPTION B: AWS Console

  1. Go to S3 -> your bucket -> Properties -> Event notifications
  2. Create 3 event notifications:

     Notification 1 (PDFs):
       Name:   snowpipe-pdfs
       Prefix: healthcare/pdfs/
       Events: All object create events (s3:ObjectCreated:*)
       Dest:   SQS queue -> Enter SQS queue ARN from SHOW PIPES

     Notification 2 (TXT):
       Name:   snowpipe-txt
       Prefix: healthcare/txt/
       Events: All object create events (s3:ObjectCreated:*)
       Dest:   SQS queue -> Enter SQS queue ARN from SHOW PIPES

     Notification 3 (Audio):
       Name:   snowpipe-audio
       Prefix: healthcare/audio/
       Events: All object create events (s3:ObjectCreated:*)
       Dest:   SQS queue -> Enter SQS queue ARN from SHOW PIPES
*/

-----------------------------------------------------------------------
-- STEP 6: VERIFY S3 EVENT NOTIFICATIONS ARE CONFIGURED
-----------------------------------------------------------------------
/*
  aws s3api get-bucket-notification-configuration \
    --bucket healthcare-ai-demo-<YOUR_ACCOUNT_ID>

  Expected output should show 3 QueueConfigurations pointing to
  the Snowflake SQS queue ARN.
*/

-----------------------------------------------------------------------
-- STEP 7: TEST THE PIPELINE
-----------------------------------------------------------------------
/*
  Upload sample files to trigger auto-ingest:

  aws s3 cp sample_files/pdfs/ s3://healthcare-ai-demo-<YOUR_ACCOUNT_ID>/healthcare/pdfs/ --recursive
  aws s3 cp sample_files/txt/ s3://healthcare-ai-demo-<YOUR_ACCOUNT_ID>/healthcare/txt/ --recursive
  aws s3 cp sample_files/audio/ s3://healthcare-ai-demo-<YOUR_ACCOUNT_ID>/healthcare/audio/ --recursive

  Then verify in Snowflake:
*/

-- Check pipe status (should show pendingFileCount > 0 shortly after upload)
SELECT SYSTEM$PIPE_STATUS('HEALTHCARE_AI_DEMO.RAW.PIPE_MEDICAL_DOCS')  AS DOCS_STATUS;
SELECT SYSTEM$PIPE_STATUS('HEALTHCARE_AI_DEMO.RAW.PIPE_MEDICAL_TXT')   AS TXT_STATUS;
SELECT SYSTEM$PIPE_STATUS('HEALTHCARE_AI_DEMO.RAW.PIPE_MEDICAL_AUDIO') AS AUDIO_STATUS;

-- Check files landed in FILES_LOG
SELECT * FROM HEALTHCARE_AI_DEMO.RAW.FILES_LOG ORDER BY LANDED_AT DESC;

-- Check stream has data for processing
SELECT SYSTEM$STREAM_HAS_DATA('HEALTHCARE_AI_DEMO.RAW.FILES_LOG_STREAM') AS READY;

-- If auto-ingest hasn't triggered, manually refresh pipes:
-- ALTER PIPE HEALTHCARE_AI_DEMO.RAW.PIPE_MEDICAL_DOCS  REFRESH;
-- ALTER PIPE HEALTHCARE_AI_DEMO.RAW.PIPE_MEDICAL_TXT   REFRESH;
-- ALTER PIPE HEALTHCARE_AI_DEMO.RAW.PIPE_MEDICAL_AUDIO REFRESH;

-- Check copy history for errors
SELECT PIPE_NAME, FILE_NAME, STATUS, ROW_COUNT, ERROR_MESSAGE, LAST_LOAD_TIME
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME   => 'HEALTHCARE_AI_DEMO.RAW.FILES_LOG',
  START_TIME   => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 20;

-----------------------------------------------------------------------
-- STEP 8: RESUME THE PROCESSING TASK
-----------------------------------------------------------------------
-- Once files are landing successfully in FILES_LOG:
ALTER TASK HEALTHCARE_AI_DEMO.RAW.PROCESS_NEW_FILES_TASK RESUME;

-- Verify task is running
SHOW TASKS LIKE 'PROCESS_NEW_FILES_TASK' IN SCHEMA HEALTHCARE_AI_DEMO.RAW;

-----------------------------------------------------------------------
-- SNOWFLAKE INTELLIGENCE SETUP (UI Steps)
-----------------------------------------------------------------------
/*
  1. Navigate to Snowflake Intelligence in the Snowsight UI
  2. Click "New Agent" or go to the existing SNOWFLAKE_INTELLIGENCE database
  3. Configure a new agent:
     - Name: Healthcare Intelligence
     - Agent: HEALTHCARE_AI_DEMO.ANALYTICS.HEALTHCARE_INTELLIGENCE_AGENT
  4. The agent automatically inherits the 3 tools:
     - HealthcareAnalyst (structured queries via semantic view)
     - DocumentSearch (search parsed medical documents)
     - AudioSearch (search transcribed consultations)
  5. Test with sample questions from the agent definition
  6. Share with your team as needed
*/

-----------------------------------------------------------------------
-- TROUBLESHOOTING
-----------------------------------------------------------------------
/*
  Q: Pipes are created but files don't appear in FILES_LOG?
  A: Check these in order:
     1. Verify S3 event notifications: aws s3api get-bucket-notification-configuration --bucket <bucket>
     2. Verify the SQS ARN matches: SHOW PIPES; (check notification_channel column)
     3. Check IAM role trust policy has correct Snowflake user ARN and external ID
     4. Try manual refresh: ALTER PIPE RAW.PIPE_MEDICAL_DOCS REFRESH;
     5. Check COPY_HISTORY for error messages (query above)

  Q: Getting "Access Denied" errors?
  A: Run DESCRIBE INTEGRATION HEALTHCARE_S3_INTEGRATION; and verify:
     - STORAGE_AWS_IAM_USER_ARN matches the Principal in your IAM trust policy
     - STORAGE_AWS_EXTERNAL_ID matches the sts:ExternalId condition
     - The IAM role has the S3 access policy attached

  Q: Pipe shows executionState = "PAUSED"?
  A: Pipes are created paused. Resume them:
     ALTER PIPE RAW.PIPE_MEDICAL_DOCS  SET PIPE_EXECUTION_PAUSED = FALSE;
     ALTER PIPE RAW.PIPE_MEDICAL_TXT   SET PIPE_EXECUTION_PAUSED = FALSE;
     ALTER PIPE RAW.PIPE_MEDICAL_AUDIO SET PIPE_EXECUTION_PAUSED = FALSE;
*/
