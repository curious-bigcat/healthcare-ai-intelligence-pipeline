/*=============================================================================
  08 - SEMANTIC VIEW FOR CORTEX ANALYST
  Healthcare AI Intelligence Pipeline

  This semantic view enables natural-language queries over:
    - Patient demographics and registration
    - Provider directory and specialties
    - Claims data (billing, diagnosis, procedures, status)
    - Appointments (scheduling, visit types, recording status)
    - AI-processed document metrics (PDF intelligence)
    - AI-processed audio metrics (consultation intelligence)
=============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTHCARE_AI_DEMO;
USE SCHEMA ANALYTICS;
USE WAREHOUSE HEALTHCARE_AI_WH;

-----------------------------------------------------------------------
-- SEMANTIC VIEW
-----------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW ANALYTICS.HEALTHCARE_ANALYTICS
  COMMENT = 'Healthcare analytics semantic view for Cortex Analyst. Covers patients, providers, claims, appointments, and AI-processed document/audio intelligence.'
AS
  -- PATIENTS table
  TABLES (
    ANALYTICS.PATIENTS
      WITH SEMANTICS (
        PATIENT_ID IDENTIFIER 'Unique patient identifier',
        FIRST_NAME DIMENSION 'Patient first name',
        LAST_NAME DIMENSION 'Patient last name',
        DATE_OF_BIRTH DIMENSION 'Patient date of birth',
        GENDER DIMENSION 'Patient gender (Male, Female)',
        CITY DIMENSION 'Patient city of residence',
        STATE DIMENSION 'Patient state of residence',
        ZIP_CODE DIMENSION 'Patient zip code',
        INSURANCE_PLAN DIMENSION 'Insurance plan name (Aetna PPO, UnitedHealth Choice Plus, Cigna Open Access, Anthem Blue Cross, Medicare Advantage)',
        PRIMARY_PROVIDER_ID DIMENSION 'FK to PROVIDERS table — the patient primary care provider',
        REGISTERED_DATE DIMENSION 'Date patient was registered in the system'
      ),

    -- PROVIDERS table
    ANALYTICS.PROVIDERS
      WITH SEMANTICS (
        PROVIDER_ID IDENTIFIER 'Unique provider identifier',
        PROVIDER_NAME DIMENSION 'Full name of the doctor or provider',
        SPECIALTY DIMENSION 'Medical specialty (Internal Medicine, Cardiology, Orthopedics, Neurology, Oncology, Psychiatry, Pediatrics, Dermatology, Radiology, Pulmonology, Endocrinology, Gastroenterology)',
        FACILITY_NAME DIMENSION 'Hospital or clinic name where provider practices',
        CITY DIMENSION 'City where the facility is located',
        STATE DIMENSION 'State where the facility is located',
        NPI_NUMBER DIMENSION 'National Provider Identifier number',
        IS_ACTIVE DIMENSION 'Whether the provider is currently active'
      ),

    -- CLAIMS table
    ANALYTICS.CLAIMS
      WITH SEMANTICS (
        CLAIM_ID IDENTIFIER 'Unique claim identifier',
        PATIENT_ID DIMENSION 'FK to PATIENTS table',
        PROVIDER_ID DIMENSION 'FK to PROVIDERS table',
        SERVICE_DATE DIMENSION 'Date the medical service was performed',
        CLAIM_DATE DIMENSION 'Date the claim was submitted',
        PROCEDURE_CODE DIMENSION 'CPT procedure code',
        PROCEDURE_DESC DIMENSION 'Description of the medical procedure',
        DIAGNOSIS_CODE DIMENSION 'ICD-10 diagnosis code',
        DIAGNOSIS_DESC DIMENSION 'Description of the diagnosis',
        BILLED_AMOUNT MEASURE 'Total amount billed by the provider in dollars' WITH AGGREGATIONS (SUM, AVG, MIN, MAX),
        ALLOWED_AMOUNT MEASURE 'Amount allowed by the insurance plan in dollars' WITH AGGREGATIONS (SUM, AVG, MIN, MAX),
        PAID_AMOUNT MEASURE 'Amount paid by insurance in dollars' WITH AGGREGATIONS (SUM, AVG, MIN, MAX),
        PATIENT_RESPONSIBILITY MEASURE 'Amount the patient owes (copay, coinsurance, deductible) in dollars' WITH AGGREGATIONS (SUM, AVG, MIN, MAX),
        CLAIM_STATUS DIMENSION 'Status of the claim: Approved, Denied, Pending, Under Review',
        DENIAL_REASON DIMENSION 'Reason for claim denial if applicable'
      ),

    -- APPOINTMENTS table
    ANALYTICS.APPOINTMENTS
      WITH SEMANTICS (
        APPOINTMENT_ID IDENTIFIER 'Unique appointment identifier',
        PATIENT_ID DIMENSION 'FK to PATIENTS table',
        PROVIDER_ID DIMENSION 'FK to PROVIDERS table',
        APPOINTMENT_DATE DIMENSION 'Date and time of the appointment',
        APPOINTMENT_TYPE DIMENSION 'Type of visit: In-Person, Telehealth, Phone',
        VISIT_REASON DIMENSION 'Reason for the visit or chief complaint',
        DURATION_MINUTES MEASURE 'Duration of the appointment in minutes' WITH AGGREGATIONS (SUM, AVG, MIN, MAX),
        STATUS DIMENSION 'Appointment status: Completed, Cancelled, No-Show, Scheduled',
        HAS_AUDIO_RECORDING DIMENSION 'Whether the consultation was recorded as audio (TRUE/FALSE)',
        HAS_DOCUMENT DIMENSION 'Whether a medical document was generated (TRUE/FALSE)'
      )
  )

  RELATIONSHIPS (
    ANALYTICS.PATIENTS (PRIMARY_PROVIDER_ID) REFERENCES ANALYTICS.PROVIDERS (PROVIDER_ID),
    ANALYTICS.CLAIMS (PATIENT_ID) REFERENCES ANALYTICS.PATIENTS (PATIENT_ID),
    ANALYTICS.CLAIMS (PROVIDER_ID) REFERENCES ANALYTICS.PROVIDERS (PROVIDER_ID),
    ANALYTICS.APPOINTMENTS (PATIENT_ID) REFERENCES ANALYTICS.PATIENTS (PATIENT_ID),
    ANALYTICS.APPOINTMENTS (PROVIDER_ID) REFERENCES ANALYTICS.PROVIDERS (PROVIDER_ID)
  )

  VERIFIED QUERIES (
    -- Claims queries
    'Total billed amount by provider specialty' AS
      SELECT pr.SPECIALTY, SUM(c.BILLED_AMOUNT) AS TOTAL_BILLED
      FROM ANALYTICS.CLAIMS c
      JOIN ANALYTICS.PROVIDERS pr ON c.PROVIDER_ID = pr.PROVIDER_ID
      GROUP BY pr.SPECIALTY
      ORDER BY TOTAL_BILLED DESC,

    'Claims by status' AS
      SELECT CLAIM_STATUS, COUNT(*) AS CLAIM_COUNT, SUM(BILLED_AMOUNT) AS TOTAL_BILLED
      FROM ANALYTICS.CLAIMS
      GROUP BY CLAIM_STATUS,

    'Average paid amount per diagnosis' AS
      SELECT DIAGNOSIS_DESC, COUNT(*) AS CLAIM_COUNT, AVG(PAID_AMOUNT) AS AVG_PAID
      FROM ANALYTICS.CLAIMS
      GROUP BY DIAGNOSIS_DESC
      ORDER BY AVG_PAID DESC,

    'Patients with the highest total billed amount' AS
      SELECT p.FIRST_NAME || '' '' || p.LAST_NAME AS PATIENT_NAME, p.INSURANCE_PLAN,
             SUM(c.BILLED_AMOUNT) AS TOTAL_BILLED, COUNT(*) AS CLAIM_COUNT
      FROM ANALYTICS.CLAIMS c
      JOIN ANALYTICS.PATIENTS p ON c.PATIENT_ID = p.PATIENT_ID
      GROUP BY p.FIRST_NAME, p.LAST_NAME, p.INSURANCE_PLAN
      ORDER BY TOTAL_BILLED DESC,

    'Denied claims with reasons' AS
      SELECT c.CLAIM_ID, p.FIRST_NAME || '' '' || p.LAST_NAME AS PATIENT_NAME,
             c.PROCEDURE_DESC, c.BILLED_AMOUNT, c.DENIAL_REASON
      FROM ANALYTICS.CLAIMS c
      JOIN ANALYTICS.PATIENTS p ON c.PATIENT_ID = p.PATIENT_ID
      WHERE c.CLAIM_STATUS = ''Denied'',

    -- Appointment queries
    'Appointment count by type' AS
      SELECT APPOINTMENT_TYPE, STATUS, COUNT(*) AS APPT_COUNT
      FROM ANALYTICS.APPOINTMENTS
      GROUP BY APPOINTMENT_TYPE, STATUS,

    'Average appointment duration by specialty' AS
      SELECT pr.SPECIALTY, AVG(a.DURATION_MINUTES) AS AVG_DURATION_MIN
      FROM ANALYTICS.APPOINTMENTS a
      JOIN ANALYTICS.PROVIDERS pr ON a.PROVIDER_ID = pr.PROVIDER_ID
      WHERE a.STATUS = ''Completed''
      GROUP BY pr.SPECIALTY
      ORDER BY AVG_DURATION_MIN DESC,

    'Appointments with audio recordings' AS
      SELECT a.APPOINTMENT_ID, p.FIRST_NAME || '' '' || p.LAST_NAME AS PATIENT_NAME,
             pr.PROVIDER_NAME, a.APPOINTMENT_DATE, a.VISIT_REASON
      FROM ANALYTICS.APPOINTMENTS a
      JOIN ANALYTICS.PATIENTS p ON a.PATIENT_ID = p.PATIENT_ID
      JOIN ANALYTICS.PROVIDERS pr ON a.PROVIDER_ID = pr.PROVIDER_ID
      WHERE a.HAS_AUDIO_RECORDING = TRUE,

    -- Patient queries
    'Patients by insurance plan' AS
      SELECT INSURANCE_PLAN, COUNT(*) AS PATIENT_COUNT
      FROM ANALYTICS.PATIENTS
      GROUP BY INSURANCE_PLAN
      ORDER BY PATIENT_COUNT DESC,

    'Providers by specialty and facility' AS
      SELECT SPECIALTY, FACILITY_NAME, PROVIDER_NAME, CITY
      FROM ANALYTICS.PROVIDERS
      WHERE IS_ACTIVE = TRUE
      ORDER BY SPECIALTY, FACILITY_NAME
  );

-----------------------------------------------------------------------
-- VERIFY
-----------------------------------------------------------------------
SHOW SEMANTIC VIEWS IN SCHEMA ANALYTICS;
DESCRIBE SEMANTIC VIEW ANALYTICS.HEALTHCARE_ANALYTICS;
