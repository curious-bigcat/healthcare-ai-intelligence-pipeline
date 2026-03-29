# Healthcare AI Intelligence Pipeline

An end-to-end demo that lands medical files (PDF, TXT, WAV, MP3) in S3, auto-ingests them into Snowflake via S3 Event Notifications -> SQS -> Snowpipe, processes them through **11 Cortex AI functions** using separate stored procedures per file type, and exposes the results via Cortex Search, Cortex Analyst, and a unified Cortex Agent with Snowflake Intelligence as the frontend.

## Architecture

```
S3 Bucket (pdfs/, txt/, audio/)
        |
  S3 Event Notification  -->  SQS (Snowflake-managed)
        |
  Snowpipe (x3: PDF, TXT, Audio)
        |
  FILES_LOG table  -->  Stream  -->  Task
        |
  PROCESS_NEW_FILES() Orchestrator
    |              |              |
  PROCESS_PDF    PROCESS_TXT    PROCESS_AUDIO
  (9 AI funcs)   (8 AI funcs)   (8 AI funcs)
    |              |              |
  PDF_INTEL      TXT_INTEL      AUDIO_INTEL
    |              |              |
  PDF_SEARCH     TXT_SEARCH     AUDIO_SEARCH
    |              |              |
    +--- Cortex Agent (4 tools) ---+
         |        |       |        |
    PDFSearch TXTSearch Audio  Analyst
                  Search   (Semantic View)
                   |
          Snowflake Intelligence UI
```

## Cortex AI Functions Used (11)

| # | Function | PDF | TXT | Audio | Purpose |
|---|----------|:---:|:---:|:-----:|---------|
| 1 | `AI_PARSE_DOCUMENT` | x | | | Extract text from PDF files (OCR + layout) |
| 2 | `AI_TRANSCRIBE` | | | x | Convert WAV/MP3 audio to text with speaker diarization |
| 3 | `AI_EXTRACT` | x | x | x | Pull structured entities (diagnoses, medications, vitals) |
| 4 | `AI_CLASSIFY` | x | x | x | Categorize documents/consultations |
| 5 | `AI_SENTIMENT` | x | x | x | Detect sentiment (overall + multi-dimensional) |
| 6 | `AI_SUMMARIZE` | x | x | x | Generate concise summaries |
| 7 | `AI_TRANSLATE` | x | x | x | Detect language, translate if non-English |
| 8 | `AI_REDACT` | x | x | | Remove PII (names, DOB, SSN, addresses) |
| 9 | `AI_COMPLETE` | x | x | x | Generate clinical insights / SOAP notes (claude-3.5-sonnet) |
| 10 | `AI_EMBED` | x | x | x | Create vector embeddings (snowflake-arctic-embed-m-v1.5) |
| 11 | `AI_SIMILARITY` | x | x | x | Compute similarity scores between documents |

## Files

### SQL Scripts (run in order)

| File | Description |
|------|-------------|
| `01_database_and_schemas.sql` | Database, schemas (RAW, PROCESSED, ANALYTICS), warehouse |
| `02_s3_integration_and_stages.sql` | S3 storage integration, 3 external stages, internal semantic stage |
| `03_file_ingestion.sql` | FILES_LOG table, file format, 3 Snowpipes (SQS auto-ingest), stream |
| `04_processing_tables.sql` | PDF_INTELLIGENCE, TXT_INTELLIGENCE, AUDIO_INTELLIGENCE tables |
| `05_proc_pdf.sql` | `PROCESS_PDF_FILES()` -- 9 AI functions for PDF processing |
| `06_proc_txt.sql` | `PROCESS_TXT_FILES()` -- 8 AI functions for TXT processing |
| `07_proc_audio.sql` | `PROCESS_AUDIO_FILES()` -- 8 AI functions for audio processing |
| `08_orchestrator_proc_and_task.sql` | `PROCESS_NEW_FILES()` orchestrator + stream-triggered task |
| `09_structured_data.sql` | Providers (12), Patients (15), Claims (30), Appointments (24) |
| `10_analytics_views.sql` | PDF_METRICS, TXT_METRICS, AUDIO_METRICS, COMBINED_INSIGHTS, CLAIMS_SUMMARY |
| `11_cortex_search.sql` | 3 Cortex Search services (PDF, TXT, Audio) |
| `12_semantic_view.sql` | HEALTHCARE_ANALYTICS semantic view with 11 verified queries |
| `13_cortex_agent.sql` | Cortex Agent with 4 tools (Analyst + 3 Search services) |
| `14_aws_setup_guide.sql` | Step-by-step AWS setup (S3, IAM, S3 Event Notifications -> SQS) |
| `15_validation_queries.sql` | End-to-end validation for every AI function output |
| `16_snowflake_intelligence.sql` | Snowflake Intelligence UI setup + agent test queries |

### Python Scripts

| File | Description |
|------|-------------|
| `generate_samples.py` | Generates 6 PDFs (fpdf2) and 4 TXT files with realistic medical content |
| `generate_audio_with_voice.py` | Generates 3 WAV + 2 MP3 files with real speech via Google TTS |

### Sample Files (`sample_files/`)

**PDFs** (6 files):
- `discharge_summary_whitfield.pdf` -- Hypertensive crisis discharge
- `prescription_garcia.pdf` -- Cardiac medications post-catheterization
- `clinical_notes_obrien.pdf` -- Mental health therapy session
- `lab_report_sullivan.pdf` -- Comprehensive metabolic panel
- `insurance_claim_brown.pdf` -- Orthopedic surgery claim
- `radiology_report_park.pdf` -- Chest CT with contrast

**Text files** (4 files):
- `nurse_notes_anderson.txt` -- Post-operative nursing observations
- `referral_letter_zhang.txt` -- Neurology referral for migraines
- `patient_intake_torres.txt` -- New patient intake form
- `pathology_report_lee.txt` -- Tissue biopsy pathology findings

**Audio files** (5 files, real voice via Google TTS):
- `consultation_whitfield_bp.wav` -- BP follow-up with Dr. Chen (2:36)
- `consultation_garcia_cardiac.wav` -- Cardiac follow-up with Dr. Okafor (2:48)
- `consultation_obrien_therapy.wav` -- Therapy session with Dr. Thompson (3:08)
- `consultation_johnson_pediatric.mp3` -- Pediatric well-child with Dr. Wang (2:36)
- `consultation_tanaka_dermatology.mp3` -- Dermatology biopsy with Dr. Johnson (2:57)

## Prerequisites

- Snowflake account with Cortex AI functions enabled
- AWS account with S3 access
- Python 3.10+ with a virtual environment

## Setup

### 1. Generate sample files

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install fpdf2 lameenc gTTS
python generate_samples.py
python generate_audio_with_voice.py
```

### 2. Run SQL scripts in Snowflake

Execute scripts `01` through `13` in order. Each uses the `HEALTHCARE_AI_DEMO` database.

### 3. Configure AWS

Follow the guide in `14_aws_setup_guide.sql`:

1. Create S3 bucket with `healthcare/pdfs/`, `healthcare/txt/`, `healthcare/audio/` prefixes
2. Create IAM policy for Snowflake S3 access
3. Create IAM role with trust policy for Snowflake's external ID
4. Run `DESC INTEGRATION` in Snowflake to get IAM user ARN and external ID
5. Update the IAM role trust policy with those values
6. Create Snowpipes (AUTO_INGEST = TRUE) and get the SQS queue ARN from `SHOW PIPES`
7. Configure S3 event notifications to send ObjectCreated events to the Snowflake-managed SQS queue
8. Resume the Snowpipes and processing task

### 4. Upload sample files to S3

```bash
aws s3 cp sample_files/pdfs/ s3://YOUR-BUCKET/healthcare/pdfs/ --recursive
aws s3 cp sample_files/txt/ s3://YOUR-BUCKET/healthcare/txt/ --recursive
aws s3 cp sample_files/audio/ s3://YOUR-BUCKET/healthcare/audio/ --recursive
```

### 5. Set up Snowflake Intelligence

Create a new app in Snowflake Intelligence pointing to the `HEALTHCARE_INTELLIGENCE_AGENT` Cortex Agent (see `16_snowflake_intelligence.sql`).

### 6. Validate

Run the queries in `15_validation_queries.sql` to verify the full pipeline end to end.

## Snowflake Objects Created

| Object | Schema | Type |
|--------|--------|------|
| `HEALTHCARE_AI_DEMO` | -- | Database |
| `HEALTHCARE_AI_WH` | -- | Warehouse (X-Small) |
| `HEALTHCARE_S3_INTEGRATION` | -- | Storage Integration |
| `FILES_LOG` | RAW | Table |
| `METADATA_ONLY_FORMAT` | RAW | File Format |
| `PIPE_MEDICAL_DOCS` | RAW | Snowpipe |
| `PIPE_MEDICAL_TXT` | RAW | Snowpipe |
| `PIPE_MEDICAL_AUDIO` | RAW | Snowpipe |
| `FILES_LOG_STREAM` | RAW | Stream |
| `PROCESS_NEW_FILES_TASK` | RAW | Task |
| `PDF_INTELLIGENCE` | PROCESSED | Table |
| `TXT_INTELLIGENCE` | PROCESSED | Table |
| `AUDIO_INTELLIGENCE` | PROCESSED | Table |
| `PROCESS_PDF_FILES()` | PROCESSED | Stored Procedure |
| `PROCESS_TXT_FILES()` | PROCESSED | Stored Procedure |
| `PROCESS_AUDIO_FILES()` | PROCESSED | Stored Procedure |
| `PROCESS_NEW_FILES()` | PROCESSED | Stored Procedure (orchestrator) |
| `PDF_SEARCH` | PROCESSED | Cortex Search Service |
| `TXT_SEARCH` | PROCESSED | Cortex Search Service |
| `AUDIO_SEARCH` | PROCESSED | Cortex Search Service |
| `PROVIDERS` | ANALYTICS | Table |
| `PATIENTS` | ANALYTICS | Table |
| `CLAIMS` | ANALYTICS | Table |
| `APPOINTMENTS` | ANALYTICS | Table |
| `PDF_METRICS` | ANALYTICS | View |
| `TXT_METRICS` | ANALYTICS | View |
| `AUDIO_METRICS` | ANALYTICS | View |
| `COMBINED_INSIGHTS` | ANALYTICS | View |
| `CLAIMS_SUMMARY` | ANALYTICS | View |
| `HEALTHCARE_ANALYTICS` | ANALYTICS | Semantic View |
| `HEALTHCARE_INTELLIGENCE_AGENT` | ANALYTICS | Cortex Agent |

## Sample Agent Questions

Once everything is running, try these in Snowflake Intelligence:

- "What are the most common diagnoses across all medical documents?"
- "Find any consultations related to cardiac conditions"
- "How many claims are pending vs approved, and what's the total amount?"
- "Search for any mentions of medication side effects in audio recordings"
- "Which providers have the highest claim approval rates?"
- "Summarize Patricia O'Brien's therapy session"
- "What is the average claim amount by insurance provider?"
- "Find all PDF documents related to hypertension treatment"
- "Search text documents for clinical notes about diabetes"
- "What clinical insights were generated from the radiology reports?"
- "Compare findings across PDF and TXT documents for the same patient"
