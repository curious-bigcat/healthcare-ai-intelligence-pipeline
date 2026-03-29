/*=============================================================================
  06 - ANALYTICS VIEWS OVER AI OUTPUTS
  Healthcare AI Intelligence Pipeline

  Flattened, query-friendly views that expose the AI-enriched data from
  PROCESSED tables. These are what the Semantic View will reference.
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTHCARE_AI_DEMO;
USE SCHEMA ANALYTICS;
USE WAREHOUSE HEALTHCARE_AI_WH;

-----------------------------------------------------------------------
-- 1. DOCUMENT_METRICS — flattened document intelligence
-----------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALYTICS.DOCUMENT_METRICS AS
SELECT
    d.DOC_ID,
    d.FILE_ID,
    d.FILE_NAME,
    d.PROCESSED_AT,

    -- Classification
    d.DOC_CATEGORY,
    d.DOC_CATEGORY_CONFIDENCE,

    -- Sentiment
    d.SENTIMENT_SCORE,
    d.SENTIMENT_DIMENSIONS:urgency::FLOAT              AS URGENCY_SCORE,
    d.SENTIMENT_DIMENSIONS:clinical_concern::FLOAT     AS CLINICAL_CONCERN_SCORE,
    d.SENTIMENT_DIMENSIONS:patient_satisfaction::FLOAT  AS PATIENT_SATISFACTION_SCORE,

    -- Extracted fields
    d.EXTRACTED_FIELDS:patient_name::VARCHAR            AS PATIENT_NAME,
    d.EXTRACTED_FIELDS:provider_name::VARCHAR           AS PROVIDER_NAME,
    d.EXTRACTED_FIELDS:facility_name::VARCHAR           AS FACILITY_NAME,
    d.EXTRACTED_FIELDS:document_date::VARCHAR           AS DOCUMENT_DATE,
    d.EXTRACTED_FIELDS:diagnosis::VARCHAR               AS DIAGNOSIS,
    d.EXTRACTED_FIELDS:insurance_id::VARCHAR            AS INSURANCE_ID,
    d.EXTRACTED_FIELDS:total_amount::FLOAT              AS BILLED_AMOUNT,
    ARRAY_SIZE(d.EXTRACTED_FIELDS:medications)          AS MEDICATION_COUNT,
    ARRAY_SIZE(d.EXTRACTED_FIELDS:procedures)           AS PROCEDURE_COUNT,
    ARRAY_SIZE(d.EXTRACTED_FIELDS:follow_up_actions)    AS FOLLOW_UP_COUNT,

    -- Language
    d.DETECTED_LANGUAGE,
    CASE WHEN d.TRANSLATED_TEXT IS NOT NULL THEN TRUE ELSE FALSE END AS WAS_TRANSLATED,

    -- Summary & insights
    d.SUMMARY,
    d.KEY_INSIGHTS

FROM PROCESSED.DOCUMENT_INTELLIGENCE d;

-----------------------------------------------------------------------
-- 2. AUDIO_METRICS — flattened audio intelligence
-----------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALYTICS.AUDIO_METRICS AS
SELECT
    a.AUDIO_ID,
    a.FILE_ID,
    a.FILE_NAME,
    a.PROCESSED_AT,

    -- Transcription stats
    a.AUDIO_DURATION_SECS,
    ROUND(a.AUDIO_DURATION_SECS / 60.0, 1)            AS DURATION_MINUTES,
    a.SPEAKER_COUNT,

    -- Classification
    a.CALL_CATEGORY,
    a.CALL_CATEGORY_CONFIDENCE,

    -- Sentiment
    a.SENTIMENT_SCORE,
    a.SENTIMENT_DIMENSIONS:empathy::FLOAT              AS EMPATHY_SCORE,
    a.SENTIMENT_DIMENSIONS:clinical_clarity::FLOAT     AS CLINICAL_CLARITY_SCORE,
    a.SENTIMENT_DIMENSIONS:patient_anxiety::FLOAT      AS PATIENT_ANXIETY_SCORE,
    a.SENTIMENT_DIMENSIONS:resolution::FLOAT           AS RESOLUTION_SCORE,

    -- Extracted fields
    a.EXTRACTED_FIELDS:patient_name::VARCHAR            AS PATIENT_NAME,
    a.EXTRACTED_FIELDS:provider_name::VARCHAR           AS PROVIDER_NAME,
    a.EXTRACTED_FIELDS:chief_complaint::VARCHAR         AS CHIEF_COMPLAINT,
    a.EXTRACTED_FIELDS:diagnosis_discussed::VARCHAR     AS DIAGNOSIS_DISCUSSED,
    ARRAY_SIZE(a.EXTRACTED_FIELDS:medications_discussed) AS MEDICATIONS_MENTIONED,
    ARRAY_SIZE(a.EXTRACTED_FIELDS:follow_up_actions)   AS ACTION_ITEM_COUNT,
    a.EXTRACTED_FIELDS:next_appointment::VARCHAR        AS NEXT_APPOINTMENT,

    -- Language
    a.DETECTED_LANGUAGE,
    CASE WHEN a.TRANSLATED_TRANSCRIPT IS NOT NULL THEN TRUE ELSE FALSE END AS WAS_TRANSLATED,

    -- Summary & notes
    a.SUMMARY,
    a.CONSULTATION_NOTES

FROM PROCESSED.AUDIO_INTELLIGENCE a;

-----------------------------------------------------------------------
-- 3. COMBINED_INSIGHTS — unified view across both modalities
-----------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALYTICS.COMBINED_INSIGHTS AS
SELECT
    'DOCUMENT'                AS SOURCE_TYPE,
    DOC_ID                    AS RECORD_ID,
    FILE_NAME,
    PROCESSED_AT,
    DOC_CATEGORY              AS CATEGORY,
    SENTIMENT_SCORE,
    PATIENT_NAME,
    PROVIDER_NAME,
    DIAGNOSIS                 AS PRIMARY_FINDING,
    DETECTED_LANGUAGE,
    WAS_TRANSLATED,
    SUMMARY,
    MEDICATION_COUNT,
    FOLLOW_UP_COUNT           AS ACTION_ITEM_COUNT,
    NULL::FLOAT               AS DURATION_MINUTES,
    NULL::NUMBER              AS SPEAKER_COUNT
FROM ANALYTICS.DOCUMENT_METRICS

UNION ALL

SELECT
    'AUDIO'                   AS SOURCE_TYPE,
    AUDIO_ID                  AS RECORD_ID,
    FILE_NAME,
    PROCESSED_AT,
    CALL_CATEGORY             AS CATEGORY,
    SENTIMENT_SCORE,
    PATIENT_NAME,
    PROVIDER_NAME,
    CHIEF_COMPLAINT           AS PRIMARY_FINDING,
    DETECTED_LANGUAGE,
    WAS_TRANSLATED,
    SUMMARY,
    MEDICATIONS_MENTIONED     AS MEDICATION_COUNT,
    ACTION_ITEM_COUNT,
    DURATION_MINUTES,
    SPEAKER_COUNT
FROM ANALYTICS.AUDIO_METRICS;

-----------------------------------------------------------------------
-- 4. CLAIMS_SUMMARY — aggregated claims for Analyst queries
-----------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALYTICS.CLAIMS_SUMMARY AS
SELECT
    c.CLAIM_ID,
    c.SERVICE_DATE,
    c.CLAIM_DATE,
    c.PROCEDURE_CODE,
    c.PROCEDURE_DESC,
    c.DIAGNOSIS_CODE,
    c.DIAGNOSIS_DESC,
    c.BILLED_AMOUNT,
    c.ALLOWED_AMOUNT,
    c.PAID_AMOUNT,
    c.PATIENT_RESPONSIBILITY,
    c.CLAIM_STATUS,
    c.DENIAL_REASON,
    p.FIRST_NAME || ' ' || p.LAST_NAME   AS PATIENT_NAME,
    p.DATE_OF_BIRTH                       AS PATIENT_DOB,
    p.GENDER                              AS PATIENT_GENDER,
    p.CITY                                AS PATIENT_CITY,
    p.INSURANCE_PLAN,
    pr.PROVIDER_NAME,
    pr.SPECIALTY                          AS PROVIDER_SPECIALTY,
    pr.FACILITY_NAME
FROM ANALYTICS.CLAIMS c
JOIN ANALYTICS.PATIENTS p  ON c.PATIENT_ID  = p.PATIENT_ID
JOIN ANALYTICS.PROVIDERS pr ON c.PROVIDER_ID = pr.PROVIDER_ID;
