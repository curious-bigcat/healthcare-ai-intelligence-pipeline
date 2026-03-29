# Healthcare AI Intelligence Pipeline

An end-to-end demo that lands medical files (PDF, TXT, WAV, MP3) in S3, auto-ingests them into Snowflake via S3 Event Notifications -> SQS -> Snowpipe, processes them through **11 Cortex AI functions**, and exposes the results via Cortex Search, Cortex Analyst, and a unified Cortex Agent with Snowflake Intelligence as the frontend.

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
  PROCESS_NEW_FILES() Stored Procedure
    |           |             |
  PDF/TXT     Audio       All file types
  AI_PARSE    AI_TRANSCRIBE   AI_EXTRACT
  AI_COMPLETE                 AI_CLASSIFY
                              AI_SENTIMENT
                              AI_SUMMARIZE
                              AI_TRANSLATE
                              AI_REDACT
                              AI_COMPLETE
                              AI_EMBED
                              AI_SIMILARITY
        |                         |
  DOCUMENT_INTELLIGENCE    AUDIO_INTELLIGENCE
        |                         |
  Cortex Search (x2)     Analytics Views
        |                         |
        +--- Cortex Agent (3 tools) ---+
             |          |              |
       AudioSearch  DocSearch  HealthcareAnalyst
                                  (Semantic View)
                       |
              Snowflake Intelligence UI
```

## Cortex AI Functions Used (11)

| # | Function | Purpose |
|---|----------|---------|
| 1 | `AI_PARSE_DOCUMENT` | Extract text from PDF files |
| 2 | `AI_TRANSCRIBE` | Convert WAV/MP3 audio to text |
| 3 | `AI_EXTRACT` | Pull structured entities (diagnoses, medications, vitals) |
| 4 | `AI_CLASSIFY` | Categorize documents (clinical, administrative, etc.) |
| 5 | `AI_SENTIMENT` | Detect patient/provider sentiment |
| 6 | `AI_SUMMARIZE` | Generate concise document/transcript summaries |
| 7 | `AI_TRANSLATE` | Translate content to Spanish |
| 8 | `AI_REDACT` | Remove PII (names, DOB, SSN, addresses) |
| 9 | `AI_COMPLETE` | Generate clinical insights via LLM (claude-3.5-sonnet) |
| 10 | `AI_EMBED` | Create vector embeddings (snowflake-arctic-embed-m-v1.5) |
| 11 | `AI_SIMILARITY` | Compute similarity scores between documents |

## Files

### SQL Scripts (run in order)

| File | Description |
|------|-------------|
| `01_setup_database.sql` | Database, schemas, warehouse, S3 storage integration, external stages |
| `02_landing_zone.sql` | FILES_LOG table, 3 Snowpipes (PDF/TXT/Audio), stream, processing task |
| `03_processing_tables.sql` | DOCUMENT_INTELLIGENCE and AUDIO_INTELLIGENCE tables |
| `04_stored_procedure.sql` | `PROCESS_NEW_FILES()` -- core AI processing engine using all 11 functions |
| `05_structured_data.sql` | Providers (12), Patients (15), Claims (30), Appointments (24) |
| `06_analytics_views.sql` | DOCUMENT_METRICS, AUDIO_METRICS, COMBINED_INSIGHTS, CLAIMS_SUMMARY views |
| `07_cortex_search.sql` | Cortex Search services over documents and audio transcripts |
| `08_semantic_view.sql` | HEALTHCARE_ANALYTICS semantic view with 11 verified queries |
| `09_cortex_agent.sql` | Cortex Agent with 3 tools (Analyst + 2 Search services) |
| `10_aws_setup_guide.sql` | Step-by-step AWS setup (S3, IAM, S3 Event Notifications -> SQS) + Snowflake Intelligence UI |
| `11_sample_data_test.sql` | Validation queries, manual testing, and AI function showcase |
| `12_s3_sqs_integration_and_file_read.sql` | S3 storage integration, SQS auto-ingest setup, stage file listing and read verification |

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

Execute scripts `01` through `09` in order, then run `12_s3_sqs_integration_and_file_read.sql` for integration setup and file read verification. Each script uses the `HEALTHCARE_AI_DEMO` database.

### 3. Configure AWS

Follow the guide in `10_aws_setup_guide.sql`:

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

Create a new app in Snowflake Intelligence pointing to the `HEALTHCARE_INTELLIGENCE_AGENT` Cortex Agent.

### 6. Validate

Run the queries in `11_sample_data_test.sql` to verify the full pipeline end to end.

## Snowflake Objects Created

| Object | Schema | Type |
|--------|--------|------|
| `HEALTHCARE_AI_DEMO` | -- | Database |
| `HEALTHCARE_AI_WH` | -- | Warehouse (X-Small) |
| `HEALTHCARE_S3_INTEGRATION` | -- | Storage Integration |
| `FILES_LOG` | RAW | Table |
| `PIPE_MEDICAL_DOCS` | RAW | Snowpipe |
| `PIPE_MEDICAL_TXT` | RAW | Snowpipe |
| `PIPE_MEDICAL_AUDIO` | RAW | Snowpipe |
| `FILES_LOG_STREAM` | RAW | Stream |
| `PROCESS_NEW_FILES_TASK` | RAW | Task |
| `PROCESS_NEW_FILES()` | RAW | Stored Procedure |
| `DOCUMENT_INTELLIGENCE` | PROCESSED | Table |
| `AUDIO_INTELLIGENCE` | PROCESSED | Table |
| `PROVIDERS` | ANALYTICS | Table |
| `PATIENTS` | ANALYTICS | Table |
| `CLAIMS` | ANALYTICS | Table |
| `APPOINTMENTS` | ANALYTICS | Table |
| `DOCUMENT_METRICS` | ANALYTICS | View |
| `AUDIO_METRICS` | ANALYTICS | View |
| `COMBINED_INSIGHTS` | ANALYTICS | View |
| `CLAIMS_SUMMARY` | ANALYTICS | View |
| `DOCUMENT_SEARCH` | PROCESSED | Cortex Search Service |
| `AUDIO_SEARCH` | PROCESSED | Cortex Search Service |
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
- "Find all documents related to hypertension treatment"
- "List upcoming appointments that have audio recordings"
- "What clinical insights were generated from the radiology reports?"
