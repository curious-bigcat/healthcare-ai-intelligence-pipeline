/*=============================================================================
  04 - AI PROCESSING STORED PROCEDURE
  Healthcare AI Intelligence Pipeline

  This stored procedure is called by the task whenever new files arrive.
  It reads unprocessed rows from RAW.FILES_LOG, then for each file:

  PDFs  → AI_PARSE_DOCUMENT, AI_EXTRACT, AI_CLASSIFY, AI_SENTIMENT,
          AI_SUMMARIZE, AI_TRANSLATE, AI_REDACT, AI_COMPLETE, AI_EMBED

  TXTs  → AI_EXTRACT, AI_CLASSIFY, AI_SENTIMENT, AI_SUMMARIZE,
          AI_TRANSLATE, AI_REDACT, AI_COMPLETE, AI_EMBED
          (text is read directly — no AI_PARSE_DOCUMENT needed)

  WAVs/MP3s → AI_TRANSCRIBE, AI_EXTRACT, AI_CLASSIFY, AI_SENTIMENT,
              AI_SUMMARIZE, AI_TRANSLATE, AI_COMPLETE, AI_EMBED

  Total: 11 distinct Cortex AI functions used across all paths.
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTHCARE_AI_DEMO;
USE SCHEMA PROCESSED;
USE WAREHOUSE HEALTHCARE_AI_WH;

CREATE OR REPLACE PROCEDURE PROCESSED.PROCESS_NEW_FILES()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
  COMMENT = 'Processes new PDF, TXT, WAV, and MP3 files through 11 Cortex AI functions'
AS
BEGIN

  -----------------------------------------------------------------------
  -- PART A: PROCESS NEW PDFs
  -----------------------------------------------------------------------
  INSERT INTO PROCESSED.DOCUMENT_INTELLIGENCE (
      FILE_ID, FILE_NAME, PARSED_TEXT, PARSED_LAYOUT,
      EXTRACTED_FIELDS, DOC_CATEGORY, DOC_CATEGORY_CONFIDENCE,
      SENTIMENT_SCORE, SENTIMENT_DIMENSIONS, SUMMARY,
      DETECTED_LANGUAGE, TRANSLATED_TEXT, REDACTED_TEXT,
      KEY_INSIGHTS, EMBEDDING
  )
  SELECT
      f.FILE_ID,
      f.FILE_NAME,

      ---------------------------------------------------------------
      -- 1. AI_PARSE_DOCUMENT (OCR mode) — extract raw text from PDF
      ---------------------------------------------------------------
      AI_PARSE_DOCUMENT(
        TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME),
        'OCR'
      ):content::VARCHAR                                    AS PARSED_TEXT,

      ---------------------------------------------------------------
      -- 2. AI_PARSE_DOCUMENT (LAYOUT mode) — structured layout
      ---------------------------------------------------------------
      AI_PARSE_DOCUMENT(
        TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME),
        'LAYOUT'
      )                                                     AS PARSED_LAYOUT,

      ---------------------------------------------------------------
      -- 3. AI_EXTRACT — pull structured healthcare fields
      ---------------------------------------------------------------
      AI_EXTRACT(
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR,
        OBJECT_CONSTRUCT(
          'patient_name',       'string: full name of the patient',
          'date_of_birth',      'string: patient date of birth',
          'provider_name',      'string: name of the doctor or provider',
          'facility_name',      'string: hospital or clinic name',
          'document_date',      'string: date of the document',
          'diagnosis',          'string: primary diagnosis or findings',
          'medications',        'array: list of medications mentioned',
          'procedures',         'array: list of procedures or tests',
          'follow_up_actions',  'array: recommended follow-up actions',
          'insurance_id',       'string: insurance or policy number if present',
          'total_amount',       'number: total billed amount if present'
        )
      )                                                     AS EXTRACTED_FIELDS,

      ---------------------------------------------------------------
      -- 4. AI_CLASSIFY — categorize document type
      ---------------------------------------------------------------
      AI_CLASSIFY(
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR,
        ARRAY_CONSTRUCT(
          'Lab Report',
          'Discharge Summary',
          'Prescription',
          'Radiology Report',
          'Insurance Claim',
          'Referral Letter',
          'Clinical Notes',
          'Pathology Report'
        )
      ):label::VARCHAR                                      AS DOC_CATEGORY,

      AI_CLASSIFY(
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR,
        ARRAY_CONSTRUCT(
          'Lab Report', 'Discharge Summary', 'Prescription',
          'Radiology Report', 'Insurance Claim', 'Referral Letter',
          'Clinical Notes', 'Pathology Report'
        )
      ):score::FLOAT                                        AS DOC_CATEGORY_CONFIDENCE,

      ---------------------------------------------------------------
      -- 5. AI_SENTIMENT — overall + multi-dimensional
      ---------------------------------------------------------------
      AI_SENTIMENT(
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR
      )                                                     AS SENTIMENT_SCORE,

      AI_SENTIMENT(
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR,
        ARRAY_CONSTRUCT('urgency', 'clinical_concern', 'patient_satisfaction')
      )                                                     AS SENTIMENT_DIMENSIONS,

      ---------------------------------------------------------------
      -- 6. AI_SUMMARIZE — concise summary
      ---------------------------------------------------------------
      AI_SUMMARIZE(
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR
      )                                                     AS SUMMARY,

      ---------------------------------------------------------------
      -- 7. AI_TRANSLATE — detect language, translate if non-English
      ---------------------------------------------------------------
      AI_CLASSIFY(
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR,
        ARRAY_CONSTRUCT('English', 'Spanish', 'French', 'German',
                        'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic')
      ):label::VARCHAR                                      AS DETECTED_LANGUAGE,

      CASE
        WHEN AI_CLASSIFY(
          AI_PARSE_DOCUMENT(
            TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
          ):content::VARCHAR,
          ARRAY_CONSTRUCT('English', 'Spanish', 'French', 'German',
                          'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic')
        ):label::VARCHAR != 'English'
        THEN AI_TRANSLATE(
          AI_PARSE_DOCUMENT(
            TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
          ):content::VARCHAR,
          '',   -- auto-detect source
          'en'  -- translate to English
        )
        ELSE NULL
      END                                                   AS TRANSLATED_TEXT,

      ---------------------------------------------------------------
      -- 8. AI_REDACT — remove PII (patient names, DOB, SSN, etc.)
      ---------------------------------------------------------------
      AI_REDACT(
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR
      )                                                     AS REDACTED_TEXT,

      ---------------------------------------------------------------
      -- 9. AI_COMPLETE — generate key insights and action items
      ---------------------------------------------------------------
      AI_COMPLETE(
        'claude-3.5-sonnet',
        CONCAT(
          'You are a medical document analyst. Given the following medical document, '
          , 'provide: 1) Three key clinical insights, 2) Any urgent action items, '
          , '3) Recommended follow-ups. Be concise.\n\nDocument:\n',
          AI_PARSE_DOCUMENT(
            TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
          ):content::VARCHAR
        )
      )                                                     AS KEY_INSIGHTS,

      ---------------------------------------------------------------
      -- 10. AI_EMBED — vector embedding for Cortex Search
      ---------------------------------------------------------------
      AI_EMBED(
        'snowflake-arctic-embed-m-v1.5',
        AI_PARSE_DOCUMENT(
          TO_FILE('@RAW.S3_MEDICAL_DOCS', f.FILE_NAME), 'OCR'
        ):content::VARCHAR
      )                                                     AS EMBEDDING

  FROM RAW.FILES_LOG f
  WHERE f.FILE_TYPE = 'PDF'
    AND f.IS_PROCESSED = FALSE;


  -----------------------------------------------------------------------
  -- PART B: PROCESS NEW TXT FILES
  -- TXT files are already text, so we skip AI_PARSE_DOCUMENT.
  -- We read the file content directly from the stage using
  -- AI_EXTRACT on the file reference instead.
  -----------------------------------------------------------------------
  INSERT INTO PROCESSED.DOCUMENT_INTELLIGENCE (
      FILE_ID, FILE_NAME, PARSED_TEXT, PARSED_LAYOUT,
      EXTRACTED_FIELDS, DOC_CATEGORY, DOC_CATEGORY_CONFIDENCE,
      SENTIMENT_SCORE, SENTIMENT_DIMENSIONS, SUMMARY,
      DETECTED_LANGUAGE, TRANSLATED_TEXT, REDACTED_TEXT,
      KEY_INSIGHTS, EMBEDDING
  )
  WITH txt_content AS (
    SELECT
      f.FILE_ID,
      f.FILE_NAME,
      -- Read TXT file content via AI_EXTRACT with a simple prompt
      AI_COMPLETE(
        'claude-3.5-sonnet',
        CONCAT('Return the following medical document text exactly as-is, with no modifications:\n\n',
          TO_VARCHAR(TO_FILE('@RAW.S3_MEDICAL_TXT', f.FILE_NAME)))
      )                                                     AS FILE_TEXT
    FROM RAW.FILES_LOG f
    WHERE f.FILE_TYPE = 'TXT'
      AND f.IS_PROCESSED = FALSE
  )
  SELECT
      t.FILE_ID,
      t.FILE_NAME,

      -- Raw text (from the file)
      t.FILE_TEXT                                            AS PARSED_TEXT,
      NULL                                                  AS PARSED_LAYOUT,

      -- AI_EXTRACT
      AI_EXTRACT(
        t.FILE_TEXT,
        OBJECT_CONSTRUCT(
          'patient_name',       'string: full name of the patient',
          'date_of_birth',      'string: patient date of birth',
          'provider_name',      'string: name of the doctor or provider',
          'facility_name',      'string: hospital or clinic name',
          'document_date',      'string: date of the document',
          'diagnosis',          'string: primary diagnosis or findings',
          'medications',        'array: list of medications mentioned',
          'procedures',         'array: list of procedures or tests',
          'follow_up_actions',  'array: recommended follow-up actions',
          'insurance_id',       'string: insurance or policy number if present',
          'total_amount',       'number: total billed amount if present'
        )
      )                                                     AS EXTRACTED_FIELDS,

      -- AI_CLASSIFY
      AI_CLASSIFY(
        t.FILE_TEXT,
        ARRAY_CONSTRUCT(
          'Lab Report', 'Discharge Summary', 'Prescription', 'Radiology Report',
          'Insurance Claim', 'Referral Letter', 'Clinical Notes', 'Pathology Report',
          'Patient Intake Form', 'Nursing Notes'
        )
      ):label::VARCHAR                                      AS DOC_CATEGORY,

      AI_CLASSIFY(
        t.FILE_TEXT,
        ARRAY_CONSTRUCT(
          'Lab Report', 'Discharge Summary', 'Prescription', 'Radiology Report',
          'Insurance Claim', 'Referral Letter', 'Clinical Notes', 'Pathology Report',
          'Patient Intake Form', 'Nursing Notes'
        )
      ):score::FLOAT                                        AS DOC_CATEGORY_CONFIDENCE,

      -- AI_SENTIMENT
      AI_SENTIMENT(t.FILE_TEXT)                              AS SENTIMENT_SCORE,
      AI_SENTIMENT(
        t.FILE_TEXT,
        ARRAY_CONSTRUCT('urgency', 'clinical_concern', 'patient_satisfaction')
      )                                                     AS SENTIMENT_DIMENSIONS,

      -- AI_SUMMARIZE
      AI_SUMMARIZE(t.FILE_TEXT)                              AS SUMMARY,

      -- AI_TRANSLATE (detect + translate)
      AI_CLASSIFY(
        t.FILE_TEXT,
        ARRAY_CONSTRUCT('English', 'Spanish', 'French', 'German',
                        'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic')
      ):label::VARCHAR                                      AS DETECTED_LANGUAGE,

      CASE
        WHEN AI_CLASSIFY(
          t.FILE_TEXT,
          ARRAY_CONSTRUCT('English', 'Spanish', 'French', 'German',
                          'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic')
        ):label::VARCHAR != 'English'
        THEN AI_TRANSLATE(t.FILE_TEXT, '', 'en')
        ELSE NULL
      END                                                   AS TRANSLATED_TEXT,

      -- AI_REDACT
      AI_REDACT(t.FILE_TEXT)                                AS REDACTED_TEXT,

      -- AI_COMPLETE
      AI_COMPLETE(
        'claude-3.5-sonnet',
        CONCAT(
          'You are a medical document analyst. Given the following medical document, '
          , 'provide: 1) Three key clinical insights, 2) Any urgent action items, '
          , '3) Recommended follow-ups. Be concise.\n\nDocument:\n',
          t.FILE_TEXT
        )
      )                                                     AS KEY_INSIGHTS,

      -- AI_EMBED
      AI_EMBED('snowflake-arctic-embed-m-v1.5', t.FILE_TEXT) AS EMBEDDING

  FROM txt_content t;


  -----------------------------------------------------------------------
  -- PART C: PROCESS NEW WAV AND MP3 AUDIO FILES
  -----------------------------------------------------------------------
  INSERT INTO PROCESSED.AUDIO_INTELLIGENCE (
      FILE_ID, FILE_NAME, TRANSCRIPT_TEXT, TRANSCRIPT_SEGMENTS,
      AUDIO_DURATION_SECS, SPEAKER_COUNT,
      EXTRACTED_FIELDS, CALL_CATEGORY, CALL_CATEGORY_CONFIDENCE,
      SENTIMENT_SCORE, SENTIMENT_DIMENSIONS, SUMMARY,
      DETECTED_LANGUAGE, TRANSLATED_TRANSCRIPT,
      CONSULTATION_NOTES, EMBEDDING
  )
  WITH transcribed AS (
    SELECT
      f.FILE_ID,
      f.FILE_NAME,
      AI_TRANSCRIBE(
        TO_FILE('@RAW.S3_MEDICAL_AUDIO', f.FILE_NAME),
        OBJECT_CONSTRUCT('mode', 'segments', 'timestamp_granularity', 'word')
      )                                                     AS RAW_TRANSCRIPT
    FROM RAW.FILES_LOG f
    WHERE f.FILE_TYPE IN ('WAV', 'MP3')
      AND f.IS_PROCESSED = FALSE
  )
  SELECT
      t.FILE_ID,
      t.FILE_NAME,

      ---------------------------------------------------------------
      -- 1. AI_TRANSCRIBE — full text
      ---------------------------------------------------------------
      t.RAW_TRANSCRIPT:text::VARCHAR                        AS TRANSCRIPT_TEXT,

      ---------------------------------------------------------------
      -- 2. AI_TRANSCRIBE — segments with timestamps & speakers
      ---------------------------------------------------------------
      t.RAW_TRANSCRIPT:segments                             AS TRANSCRIPT_SEGMENTS,

      t.RAW_TRANSCRIPT:audio_duration::FLOAT                AS AUDIO_DURATION_SECS,

      -- Count distinct speakers from segments
      (SELECT COUNT(DISTINCT seg.value:speaker)
       FROM TABLE(FLATTEN(t.RAW_TRANSCRIPT:segments)) seg
       WHERE seg.value:speaker IS NOT NULL)                 AS SPEAKER_COUNT,

      ---------------------------------------------------------------
      -- 3. AI_EXTRACT — structured fields from transcript
      ---------------------------------------------------------------
      AI_EXTRACT(
        t.RAW_TRANSCRIPT:text::VARCHAR,
        OBJECT_CONSTRUCT(
          'patient_name',        'string: full name of the patient',
          'provider_name',       'string: name of the doctor or provider',
          'chief_complaint',     'string: main reason for the consultation',
          'diagnosis_discussed', 'string: any diagnosis or condition discussed',
          'medications_discussed', 'array: medications mentioned',
          'follow_up_actions',   'array: action items or follow-ups agreed upon',
          'next_appointment',    'string: date or timeframe of next visit if mentioned'
        )
      )                                                     AS EXTRACTED_FIELDS,

      ---------------------------------------------------------------
      -- 4. AI_CLASSIFY — categorize consultation type
      ---------------------------------------------------------------
      AI_CLASSIFY(
        t.RAW_TRANSCRIPT:text::VARCHAR,
        ARRAY_CONSTRUCT(
          'Initial Consultation',
          'Follow-Up Visit',
          'Specialist Referral',
          'Prescription Review',
          'Lab Results Discussion',
          'Mental Health Session',
          'Insurance Discussion',
          'Emergency Consultation'
        )
      ):label::VARCHAR                                      AS CALL_CATEGORY,

      AI_CLASSIFY(
        t.RAW_TRANSCRIPT:text::VARCHAR,
        ARRAY_CONSTRUCT(
          'Initial Consultation', 'Follow-Up Visit', 'Specialist Referral',
          'Prescription Review', 'Lab Results Discussion', 'Mental Health Session',
          'Insurance Discussion', 'Emergency Consultation'
        )
      ):score::FLOAT                                        AS CALL_CATEGORY_CONFIDENCE,

      ---------------------------------------------------------------
      -- 5. AI_SENTIMENT — overall + multi-dimensional
      ---------------------------------------------------------------
      AI_SENTIMENT(t.RAW_TRANSCRIPT:text::VARCHAR)          AS SENTIMENT_SCORE,

      AI_SENTIMENT(
        t.RAW_TRANSCRIPT:text::VARCHAR,
        ARRAY_CONSTRUCT('empathy', 'clinical_clarity', 'patient_anxiety', 'resolution')
      )                                                     AS SENTIMENT_DIMENSIONS,

      ---------------------------------------------------------------
      -- 6. AI_SUMMARIZE — executive summary
      ---------------------------------------------------------------
      AI_SUMMARIZE(t.RAW_TRANSCRIPT:text::VARCHAR)          AS SUMMARY,

      ---------------------------------------------------------------
      -- 7. AI_TRANSLATE — detect language, translate if non-English
      ---------------------------------------------------------------
      AI_CLASSIFY(
        t.RAW_TRANSCRIPT:text::VARCHAR,
        ARRAY_CONSTRUCT('English', 'Spanish', 'French', 'German',
                        'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic')
      ):label::VARCHAR                                      AS DETECTED_LANGUAGE,

      CASE
        WHEN AI_CLASSIFY(
          t.RAW_TRANSCRIPT:text::VARCHAR,
          ARRAY_CONSTRUCT('English', 'Spanish', 'French', 'German',
                          'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic')
        ):label::VARCHAR != 'English'
        THEN AI_TRANSLATE(t.RAW_TRANSCRIPT:text::VARCHAR, '', 'en')
        ELSE NULL
      END                                                   AS TRANSLATED_TRANSCRIPT,

      ---------------------------------------------------------------
      -- 8. AI_COMPLETE — structured SOAP consultation notes
      ---------------------------------------------------------------
      AI_COMPLETE(
        'claude-3.5-sonnet',
        CONCAT(
          'You are a medical scribe. Given the following patient consultation transcript, '
          , 'generate structured SOAP notes (Subjective, Objective, Assessment, Plan). '
          , 'Be concise and clinically accurate.\n\nTranscript:\n',
          t.RAW_TRANSCRIPT:text::VARCHAR
        )
      )                                                     AS CONSULTATION_NOTES,

      ---------------------------------------------------------------
      -- 9. AI_EMBED — vector embedding for Cortex Search
      ---------------------------------------------------------------
      AI_EMBED(
        'snowflake-arctic-embed-m-v1.5',
        t.RAW_TRANSCRIPT:text::VARCHAR
      )                                                     AS EMBEDDING

  FROM transcribed t;


  -----------------------------------------------------------------------
  -- PART C: MARK FILES AS PROCESSED
  -----------------------------------------------------------------------
  UPDATE RAW.FILES_LOG
  SET IS_PROCESSED = TRUE,
      PROCESSED_AT = CURRENT_TIMESTAMP()
  WHERE IS_PROCESSED = FALSE;

  RETURN 'Processing complete: ' || CURRENT_TIMESTAMP()::VARCHAR;

END;
