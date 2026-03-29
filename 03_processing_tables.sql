/*=============================================================================
  03 - AI PROCESSING OUTPUT TABLES
  Healthcare AI Intelligence Pipeline

  These tables store the enriched output from 11 Cortex AI functions
  applied to PDFs (medical reports) and WAV files (patient consultations).
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTHCARE_AI_DEMO;
USE SCHEMA PROCESSED;
USE WAREHOUSE HEALTHCARE_AI_WH;

-----------------------------------------------------------------------
-- 1. DOCUMENT_INTELLIGENCE — one row per processed PDF
-----------------------------------------------------------------------
CREATE OR REPLACE TABLE PROCESSED.DOCUMENT_INTELLIGENCE (
    DOC_ID              NUMBER AUTOINCREMENT PRIMARY KEY,
    FILE_ID             NUMBER         NOT NULL COMMENT 'FK to RAW.FILES_LOG',
    FILE_NAME           VARCHAR        NOT NULL,
    PROCESSED_AT        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),

    -- AI_PARSE_DOCUMENT output
    PARSED_TEXT          VARCHAR(16777216) COMMENT 'Raw OCR text from AI_PARSE_DOCUMENT',
    PARSED_LAYOUT        VARIANT           COMMENT 'Layout-mode structured output (tables, paragraphs)',

    -- AI_EXTRACT output
    EXTRACTED_FIELDS     VARIANT           COMMENT 'Structured extraction: patient_name, dob, diagnosis, provider, dates, medications, amounts',

    -- AI_CLASSIFY output
    DOC_CATEGORY         VARCHAR(100)      COMMENT 'Classification: Lab Report, Discharge Summary, Prescription, Radiology Report, Insurance Claim, Referral Letter, Clinical Notes, Other',
    DOC_CATEGORY_CONFIDENCE FLOAT          COMMENT 'Classification confidence score',

    -- AI_SENTIMENT output
    SENTIMENT_SCORE      FLOAT             COMMENT 'Overall sentiment (-1 to 1)',
    SENTIMENT_DIMENSIONS VARIANT           COMMENT 'Multi-dimensional: urgency, clinical_concern, patient_satisfaction',

    -- AI_SUMMARIZE output
    SUMMARY              VARCHAR(10000)    COMMENT '3-sentence summary of the document',

    -- AI_TRANSLATE output
    DETECTED_LANGUAGE    VARCHAR(50)       COMMENT 'Detected source language',
    TRANSLATED_TEXT      VARCHAR(16777216) COMMENT 'English translation (NULL if already English)',

    -- AI_REDACT output
    REDACTED_TEXT        VARCHAR(16777216) COMMENT 'PII-redacted version of parsed text',

    -- AI_COMPLETE output
    KEY_INSIGHTS         VARCHAR(10000)    COMMENT 'LLM-generated key insights and action items',

    -- AI_EMBED output
    EMBEDDING            VECTOR(FLOAT, 768) COMMENT 'Text embedding for similarity search'
);

-----------------------------------------------------------------------
-- 2. AUDIO_INTELLIGENCE — one row per processed WAV
-----------------------------------------------------------------------
CREATE OR REPLACE TABLE PROCESSED.AUDIO_INTELLIGENCE (
    AUDIO_ID            NUMBER AUTOINCREMENT PRIMARY KEY,
    FILE_ID             NUMBER         NOT NULL COMMENT 'FK to RAW.FILES_LOG',
    FILE_NAME           VARCHAR        NOT NULL,
    PROCESSED_AT        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),

    -- AI_TRANSCRIBE output
    TRANSCRIPT_TEXT      VARCHAR(16777216) COMMENT 'Full transcription text',
    TRANSCRIPT_SEGMENTS  VARIANT           COMMENT 'Word-level timestamps and speaker diarization',
    AUDIO_DURATION_SECS  FLOAT             COMMENT 'Duration of audio in seconds',
    SPEAKER_COUNT        NUMBER            COMMENT 'Number of distinct speakers detected',

    -- AI_EXTRACT output
    EXTRACTED_FIELDS     VARIANT           COMMENT 'Structured extraction: patient_name, provider_name, chief_complaint, medications_discussed, follow_up_actions',

    -- AI_CLASSIFY output
    CALL_CATEGORY        VARCHAR(100)      COMMENT 'Classification: Initial Consultation, Follow-Up Visit, Specialist Referral, Prescription Review, Lab Results Discussion, Mental Health Session, Insurance Discussion, Other',
    CALL_CATEGORY_CONFIDENCE FLOAT         COMMENT 'Classification confidence score',

    -- AI_SENTIMENT output
    SENTIMENT_SCORE      FLOAT             COMMENT 'Overall sentiment (-1 to 1)',
    SENTIMENT_DIMENSIONS VARIANT           COMMENT 'Multi-dimensional: empathy, clinical_clarity, patient_anxiety, resolution',

    -- AI_SUMMARIZE output
    SUMMARY              VARCHAR(10000)    COMMENT 'Executive summary of the consultation',

    -- AI_TRANSLATE output
    DETECTED_LANGUAGE    VARCHAR(50)       COMMENT 'Detected language of the audio',
    TRANSLATED_TRANSCRIPT VARCHAR(16777216) COMMENT 'English translation of transcript (NULL if already English)',

    -- AI_COMPLETE output
    CONSULTATION_NOTES   VARCHAR(10000)    COMMENT 'LLM-generated structured consultation notes (SOAP format)',

    -- AI_EMBED output
    EMBEDDING            VECTOR(FLOAT, 768) COMMENT 'Transcript embedding for similarity search'
);

-----------------------------------------------------------------------
-- 3. INDEXES for common lookups
-----------------------------------------------------------------------
-- (Snowflake auto-clusters; these comments document expected query patterns)
-- Common filters: FILE_ID, DOC_CATEGORY, CALL_CATEGORY, DETECTED_LANGUAGE, PROCESSED_AT
