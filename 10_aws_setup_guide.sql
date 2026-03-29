/*=============================================================================
  10 - AWS SETUP GUIDE: S3 Bucket, IAM Role, SNS, EventBridge
  Healthcare AI Intelligence Pipeline

  This file documents the AWS-side configuration required to complete
  the auto-ingest pipeline. Run these commands in AWS CLI or configure
  via the AWS Console.

  Architecture:
    S3 (file upload) → EventBridge (Object Created) → SNS Topic → Snowpipe
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
-- STEP 5: ENABLE EVENTBRIDGE ON THE S3 BUCKET
-----------------------------------------------------------------------
/*
  aws s3api put-bucket-notification-configuration \
    --bucket healthcare-ai-demo-<YOUR_ACCOUNT_ID> \
    --notification-configuration '{
      "EventBridgeConfiguration": {}
    }'
*/

-----------------------------------------------------------------------
-- STEP 6: CREATE SNS TOPIC
-----------------------------------------------------------------------
/*
  aws sns create-topic \
    --name healthcare-ai-file-notifications \
    --region us-east-1

  Note the Topic ARN: arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications
  Use this in 02_landing_zone.sql for AWS_SNS_TOPIC.
*/

-----------------------------------------------------------------------
-- STEP 7: ADD SNOWFLAKE IAM POLICY TO SNS TOPIC
-----------------------------------------------------------------------
-- Run this in Snowflake to get the policy:
-- SELECT SYSTEM$GET_AWS_SNS_IAM_POLICY('arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications');

/*
  The output will be a JSON policy. Add it to your SNS topic access policy:

  aws sns set-topic-attributes \
    --topic-arn arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications \
    --attribute-name Policy \
    --attribute-value '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "AllowSnowflakeSubscribe",
          "Effect": "Allow",
          "Principal": {
            "AWS": "<STORAGE_AWS_IAM_USER_ARN from DESCRIBE INTEGRATION>"
          },
          "Action": ["sns:Subscribe"],
          "Resource": ["arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications"]
        },
        {
          "Sid": "AllowEventBridgePublish",
          "Effect": "Allow",
          "Principal": {
            "Service": "events.amazonaws.com"
          },
          "Action": "sns:Publish",
          "Resource": "arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications"
        }
      ]
    }'
*/

-----------------------------------------------------------------------
-- STEP 8: CREATE EVENTBRIDGE RULE
-----------------------------------------------------------------------
/*
  aws events put-rule \
    --name healthcare-ai-s3-file-created \
    --event-pattern '{
      "source": ["aws.s3"],
      "detail-type": ["Object Created"],
      "detail": {
        "bucket": {
          "name": ["healthcare-ai-demo-<YOUR_ACCOUNT_ID>"]
        },
        "object": {
          "key": [
            {"prefix": "healthcare/pdfs/"},
            {"prefix": "healthcare/txt/"},
            {"prefix": "healthcare/audio/"}
          ]
        }
      }
    }' \
    --state ENABLED \
    --description "Route S3 file creation events to SNS for Snowpipe"

  aws events put-targets \
    --rule healthcare-ai-s3-file-created \
    --targets "Id"="1","Arn"="arn:aws:sns:us-east-1:<YOUR_AWS_ACCOUNT_ID>:healthcare-ai-file-notifications"
*/

-----------------------------------------------------------------------
-- STEP 9: VERIFY THE PIPELINE
-----------------------------------------------------------------------
/*
  Upload test files:

  aws s3 cp test_report.pdf s3://healthcare-ai-demo-<YOUR_ACCOUNT_ID>/healthcare/pdfs/
  aws s3 cp test_notes.txt s3://healthcare-ai-demo-<YOUR_ACCOUNT_ID>/healthcare/txt/
  aws s3 cp test_consultation.wav s3://healthcare-ai-demo-<YOUR_ACCOUNT_ID>/healthcare/audio/
  aws s3 cp test_consultation.mp3 s3://healthcare-ai-demo-<YOUR_ACCOUNT_ID>/healthcare/audio/

  Then check in Snowflake:

  -- Check pipe status
  SELECT SYSTEM$PIPE_STATUS('HEALTHCARE_AI_DEMO.RAW.PIPE_MEDICAL_DOCS');
  SELECT SYSTEM$PIPE_STATUS('HEALTHCARE_AI_DEMO.RAW.PIPE_MEDICAL_AUDIO');

  -- Check files landed
  SELECT * FROM HEALTHCARE_AI_DEMO.RAW.FILES_LOG ORDER BY LANDED_AT DESC;

  -- Check stream has data
  SELECT SYSTEM$STREAM_HAS_DATA('HEALTHCARE_AI_DEMO.RAW.FILES_LOG_STREAM');
*/

-----------------------------------------------------------------------
-- STEP 10: RESUME THE PROCESSING TASK
-----------------------------------------------------------------------
-- Once the full pipeline is verified:
ALTER TASK HEALTHCARE_AI_DEMO.RAW.PROCESS_NEW_FILES_TASK RESUME;

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
