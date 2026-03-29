/*=============================================================================
  11 - SAMPLE DATA & END-TO-END TEST QUERIES
  Healthcare AI Intelligence Pipeline

  This file provides:
    A. Manual file insert simulation (for testing without S3)
    B. Manual stored procedure invocation
    C. Validation queries for every AI function output
    D. Cortex Search test queries
    E. Cortex Analyst test queries
    F. Agent test queries
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTHCARE_AI_DEMO;
USE WAREHOUSE HEALTHCARE_AI_WH;

/*=========================================================================
  SECTION A: SIMULATE FILE ARRIVALS (without S3)

  If you don't have S3 configured yet, you can manually insert rows into
  FILES_LOG and place files on the internal stage to test AI processing.
=========================================================================*/

-----------------------------------------------------------------------
-- Option 1: Upload files to internal stages for testing
-----------------------------------------------------------------------
-- First, create temporary internal stages for testing
CREATE OR REPLACE STAGE RAW.TEST_DOCS
  COMMENT = 'Temporary internal stage for test PDF files';

CREATE OR REPLACE STAGE RAW.TEST_AUDIO
  COMMENT = 'Temporary internal stage for test WAV files';

-- Upload files from local machine (run in SnowSQL or Snowsight):
-- PUT file:///path/to/your/medical_report.pdf @RAW.TEST_DOCS;
-- PUT file:///path/to/your/consultation.wav @RAW.TEST_AUDIO;

-- Verify uploads:
-- LIST @RAW.TEST_DOCS;
-- LIST @RAW.TEST_AUDIO;

-----------------------------------------------------------------------
-- Option 2: Manually insert file log entries to simulate Snowpipe
-----------------------------------------------------------------------
-- These simulate what Snowpipe would insert when files land in S3.
-- Replace file names with actual files you uploaded to the stages above.

/*
INSERT INTO RAW.FILES_LOG (FILE_NAME, FILE_PATH, FILE_TYPE)
VALUES
  ('discharge_summary_whitfield.pdf',  'discharge_summary_whitfield.pdf',  'PDF'),
  ('lab_report_sullivan.pdf',          'lab_report_sullivan.pdf',          'PDF'),
  ('prescription_garcia.pdf',          'prescription_garcia.pdf',          'PDF'),
  ('consultation_whitfield_bp.wav',    'consultation_whitfield_bp.wav',    'WAV'),
  ('consultation_garcia_cardiac.wav',  'consultation_garcia_cardiac.wav',  'WAV'),
  ('consultation_obrien_therapy.wav',  'consultation_obrien_therapy.wav',  'WAV');
*/

/*=========================================================================
  SECTION B: MANUAL PROCESSING

  Call the stored procedure directly to process any unprocessed files.
=========================================================================*/

-- CALL PROCESSED.PROCESS_NEW_FILES();

/*=========================================================================
  SECTION C: VALIDATION QUERIES — verify every AI function output

  Run these AFTER files have been processed to confirm each AI function
  produced output.
=========================================================================*/

-----------------------------------------------------------------------
-- C1: Validate DOCUMENT_INTELLIGENCE table
-----------------------------------------------------------------------

-- Check all documents were processed
SELECT DOC_ID, FILE_NAME, DOC_CATEGORY, DETECTED_LANGUAGE, PROCESSED_AT
FROM PROCESSED.DOCUMENT_INTELLIGENCE
ORDER BY PROCESSED_AT DESC;

-- AI_PARSE_DOCUMENT — verify text was extracted
SELECT DOC_ID, FILE_NAME,
       LENGTH(PARSED_TEXT) AS TEXT_LENGTH,
       PARSED_LAYOUT IS NOT NULL AS HAS_LAYOUT
FROM PROCESSED.DOCUMENT_INTELLIGENCE;

-- AI_EXTRACT — verify structured fields were pulled
SELECT DOC_ID, FILE_NAME,
       EXTRACTED_FIELDS:patient_name::VARCHAR   AS PATIENT,
       EXTRACTED_FIELDS:provider_name::VARCHAR   AS PROVIDER,
       EXTRACTED_FIELDS:diagnosis::VARCHAR        AS DIAGNOSIS,
       EXTRACTED_FIELDS:medications              AS MEDICATIONS,
       EXTRACTED_FIELDS:total_amount::FLOAT      AS AMOUNT
FROM PROCESSED.DOCUMENT_INTELLIGENCE;

-- AI_CLASSIFY — verify document categorization
SELECT DOC_ID, FILE_NAME, DOC_CATEGORY, DOC_CATEGORY_CONFIDENCE
FROM PROCESSED.DOCUMENT_INTELLIGENCE
ORDER BY DOC_CATEGORY_CONFIDENCE DESC;

-- AI_SENTIMENT — verify sentiment analysis
SELECT DOC_ID, FILE_NAME,
       SENTIMENT_SCORE,
       SENTIMENT_DIMENSIONS:urgency::FLOAT              AS URGENCY,
       SENTIMENT_DIMENSIONS:clinical_concern::FLOAT     AS CONCERN,
       SENTIMENT_DIMENSIONS:patient_satisfaction::FLOAT  AS SATISFACTION
FROM PROCESSED.DOCUMENT_INTELLIGENCE;

-- AI_SUMMARIZE — verify summaries
SELECT DOC_ID, FILE_NAME, SUMMARY
FROM PROCESSED.DOCUMENT_INTELLIGENCE;

-- AI_TRANSLATE — verify language detection
SELECT DOC_ID, FILE_NAME, DETECTED_LANGUAGE,
       CASE WHEN TRANSLATED_TEXT IS NOT NULL THEN 'Yes' ELSE 'No' END AS WAS_TRANSLATED
FROM PROCESSED.DOCUMENT_INTELLIGENCE;

-- AI_REDACT — verify PII removal
SELECT DOC_ID, FILE_NAME,
       LEFT(PARSED_TEXT, 200)   AS ORIGINAL_SNIPPET,
       LEFT(REDACTED_TEXT, 200) AS REDACTED_SNIPPET
FROM PROCESSED.DOCUMENT_INTELLIGENCE;

-- AI_COMPLETE — verify insights generation
SELECT DOC_ID, FILE_NAME, KEY_INSIGHTS
FROM PROCESSED.DOCUMENT_INTELLIGENCE;

-- AI_EMBED — verify embeddings were generated
SELECT DOC_ID, FILE_NAME,
       EMBEDDING IS NOT NULL AS HAS_EMBEDDING
FROM PROCESSED.DOCUMENT_INTELLIGENCE;

-----------------------------------------------------------------------
-- C2: Validate AUDIO_INTELLIGENCE table
-----------------------------------------------------------------------

-- Check all audio files were processed
SELECT AUDIO_ID, FILE_NAME, CALL_CATEGORY, AUDIO_DURATION_SECS,
       SPEAKER_COUNT, DETECTED_LANGUAGE, PROCESSED_AT
FROM PROCESSED.AUDIO_INTELLIGENCE
ORDER BY PROCESSED_AT DESC;

-- AI_TRANSCRIBE — verify transcription
SELECT AUDIO_ID, FILE_NAME,
       LENGTH(TRANSCRIPT_TEXT) AS TRANSCRIPT_LENGTH,
       AUDIO_DURATION_SECS,
       SPEAKER_COUNT
FROM PROCESSED.AUDIO_INTELLIGENCE;

-- AI_EXTRACT — verify structured extraction from transcript
SELECT AUDIO_ID, FILE_NAME,
       EXTRACTED_FIELDS:patient_name::VARCHAR         AS PATIENT,
       EXTRACTED_FIELDS:provider_name::VARCHAR         AS PROVIDER,
       EXTRACTED_FIELDS:chief_complaint::VARCHAR       AS CHIEF_COMPLAINT,
       EXTRACTED_FIELDS:medications_discussed          AS MEDICATIONS,
       EXTRACTED_FIELDS:follow_up_actions              AS FOLLOW_UPS
FROM PROCESSED.AUDIO_INTELLIGENCE;

-- AI_CLASSIFY — verify call categorization
SELECT AUDIO_ID, FILE_NAME, CALL_CATEGORY, CALL_CATEGORY_CONFIDENCE
FROM PROCESSED.AUDIO_INTELLIGENCE;

-- AI_SENTIMENT — verify multi-dimensional sentiment
SELECT AUDIO_ID, FILE_NAME,
       SENTIMENT_SCORE,
       SENTIMENT_DIMENSIONS:empathy::FLOAT           AS EMPATHY,
       SENTIMENT_DIMENSIONS:clinical_clarity::FLOAT  AS CLARITY,
       SENTIMENT_DIMENSIONS:patient_anxiety::FLOAT   AS ANXIETY,
       SENTIMENT_DIMENSIONS:resolution::FLOAT        AS RESOLUTION
FROM PROCESSED.AUDIO_INTELLIGENCE;

-- AI_SUMMARIZE — verify summaries
SELECT AUDIO_ID, FILE_NAME, SUMMARY
FROM PROCESSED.AUDIO_INTELLIGENCE;

-- AI_COMPLETE — verify SOAP notes generation
SELECT AUDIO_ID, FILE_NAME, CONSULTATION_NOTES
FROM PROCESSED.AUDIO_INTELLIGENCE;

-- AI_EMBED — verify embeddings
SELECT AUDIO_ID, FILE_NAME,
       EMBEDDING IS NOT NULL AS HAS_EMBEDDING
FROM PROCESSED.AUDIO_INTELLIGENCE;

/*=========================================================================
  SECTION D: CORTEX SEARCH TESTS
=========================================================================*/

-- Search medical documents for diabetes-related content
-- SELECT *
-- FROM TABLE(
--   HEALTHCARE_AI_DEMO.PROCESSED.DOCUMENT_SEARCH.SEARCH(
--     QUERY => 'diabetes diagnosis and treatment plan',
--     COLUMNS => ARRAY_CONSTRUCT('FILE_NAME', 'DOC_CATEGORY', 'PATIENT_NAME', 'DIAGNOSIS', 'SENTIMENT_SCORE'),
--     LIMIT => 5
--   )
-- );

-- Search audio transcripts for medication discussions
-- SELECT *
-- FROM TABLE(
--   HEALTHCARE_AI_DEMO.PROCESSED.AUDIO_SEARCH.SEARCH(
--     QUERY => 'medication changes and side effects discussed',
--     COLUMNS => ARRAY_CONSTRUCT('FILE_NAME', 'CALL_CATEGORY', 'PATIENT_NAME', 'CHIEF_COMPLAINT', 'DURATION_SECS'),
--     LIMIT => 5
--   )
-- );

-- Search with filter — only lab reports
-- SELECT *
-- FROM TABLE(
--   HEALTHCARE_AI_DEMO.PROCESSED.DOCUMENT_SEARCH.SEARCH(
--     QUERY => 'abnormal blood work results',
--     COLUMNS => ARRAY_CONSTRUCT('FILE_NAME', 'DOC_CATEGORY', 'PATIENT_NAME', 'DIAGNOSIS'),
--     FILTER => OBJECT_CONSTRUCT('DOC_CATEGORY', 'Lab Report'),
--     LIMIT => 5
--   )
-- );

/*=========================================================================
  SECTION E: CORTEX ANALYST TESTS (via semantic view)
=========================================================================*/

-- These queries test the structured data through the semantic view.
-- They can be run directly or asked via natural language through the agent.

-- Total billed by specialty
SELECT pr.SPECIALTY,
       COUNT(*) AS CLAIM_COUNT,
       SUM(c.BILLED_AMOUNT) AS TOTAL_BILLED,
       AVG(c.PAID_AMOUNT) AS AVG_PAID
FROM ANALYTICS.CLAIMS c
JOIN ANALYTICS.PROVIDERS pr ON c.PROVIDER_ID = pr.PROVIDER_ID
GROUP BY pr.SPECIALTY
ORDER BY TOTAL_BILLED DESC;

-- Claims by status
SELECT CLAIM_STATUS, COUNT(*) AS CNT, SUM(BILLED_AMOUNT) AS TOTAL
FROM ANALYTICS.CLAIMS
GROUP BY CLAIM_STATUS;

-- Patients with most appointments
SELECT p.FIRST_NAME || ' ' || p.LAST_NAME AS PATIENT,
       COUNT(*) AS APPOINTMENTS,
       SUM(a.DURATION_MINUTES) AS TOTAL_MINUTES
FROM ANALYTICS.APPOINTMENTS a
JOIN ANALYTICS.PATIENTS p ON a.PATIENT_ID = p.PATIENT_ID
WHERE a.STATUS = 'Completed'
GROUP BY p.FIRST_NAME, p.LAST_NAME
ORDER BY APPOINTMENTS DESC;

-- Insurance plan distribution
SELECT INSURANCE_PLAN, COUNT(*) AS PATIENT_COUNT
FROM ANALYTICS.PATIENTS
GROUP BY INSURANCE_PLAN
ORDER BY PATIENT_COUNT DESC;

-- Telehealth vs In-Person
SELECT APPOINTMENT_TYPE, COUNT(*) AS CNT,
       AVG(DURATION_MINUTES) AS AVG_DURATION
FROM ANALYTICS.APPOINTMENTS
WHERE STATUS = 'Completed'
GROUP BY APPOINTMENT_TYPE;

/*=========================================================================
  SECTION F: AGENT TEST (run via Snowflake Intelligence or SQL)
=========================================================================*/

-- Test the agent directly via SQL:
-- SELECT SNOWFLAKE.CORTEX.INVOKE_AGENT(
--   'HEALTHCARE_AI_DEMO.ANALYTICS.HEALTHCARE_INTELLIGENCE_AGENT',
--   'Which providers have the highest total billed amounts?'
-- );

-- SELECT SNOWFLAKE.CORTEX.INVOKE_AGENT(
--   'HEALTHCARE_AI_DEMO.ANALYTICS.HEALTHCARE_INTELLIGENCE_AGENT',
--   'Find any documents mentioning hypertension or high blood pressure'
-- );

-- SELECT SNOWFLAKE.CORTEX.INVOKE_AGENT(
--   'HEALTHCARE_AI_DEMO.ANALYTICS.HEALTHCARE_INTELLIGENCE_AGENT',
--   'Summarize the most recent patient consultations'
-- );

/*=========================================================================
  SECTION G: AI FUNCTION SHOWCASE — standalone examples
  (Run these independently to demonstrate each function)
=========================================================================*/

-- AI_SIMILARITY — compare two document embeddings
/*
SELECT
  a.FILE_NAME AS DOC_A,
  b.FILE_NAME AS DOC_B,
  AI_SIMILARITY(a.EMBEDDING, b.EMBEDDING) AS SIMILARITY_SCORE
FROM PROCESSED.DOCUMENT_INTELLIGENCE a
CROSS JOIN PROCESSED.DOCUMENT_INTELLIGENCE b
WHERE a.DOC_ID < b.DOC_ID
ORDER BY SIMILARITY_SCORE DESC;
*/

-- AI_AGG — aggregate summaries across all documents
/*
SELECT AI_SUMMARIZE_AGG(SUMMARY)
FROM PROCESSED.DOCUMENT_INTELLIGENCE;
*/

-- Count of AI functions used in this pipeline:
SELECT 'AI Functions Used' AS METRIC, 11 AS COUNT
UNION ALL SELECT 'PDF Functions', 9
UNION ALL SELECT 'Audio Functions', 8
UNION ALL SELECT 'Shared Functions', 6;

/*
  COMPLETE LIST OF 11 CORTEX AI FUNCTIONS USED:
  =============================================
  1.  AI_PARSE_DOCUMENT  — OCR + layout extraction from PDFs
  2.  AI_TRANSCRIBE      — speech-to-text from WAV audio
  3.  AI_EXTRACT         — structured field extraction from text
  4.  AI_CLASSIFY        — document/call type categorization
  5.  AI_SENTIMENT       — sentiment analysis (overall + multi-dimensional)
  6.  AI_SUMMARIZE       — text summarization
  7.  AI_TRANSLATE       — language detection + translation
  8.  AI_REDACT          — PII removal from medical documents
  9.  AI_COMPLETE        — LLM-powered insights / SOAP notes generation
  10. AI_EMBED           — vector embeddings for search
  11. AI_SIMILARITY      — embedding similarity comparison (via Cortex Search)

  ADDITIONAL FUNCTIONS DEMONSTRATED:
  - AI_SUMMARIZE_AGG    — aggregate summarization across rows
*/
