#!/usr/bin/env python3
"""
generate_samples.py -- Healthcare AI Intelligence Pipeline
Generates realistic sample medical files for testing the Cortex AI pipeline.

Output:
  sample_files/
    ├── pdfs/       (6 PDF medical documents)
    ├── txt/        (4 TXT medical text files)
    ├── audio/      (3 WAV + 2 MP3 synthesized audio files)

Usage:
  source .venv/bin/activate
  python generate_samples.py
"""

import os
import math
import wave
import struct
import random
from fpdf import FPDF
import lameenc

BASE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample_files")
PDF_DIR = os.path.join(BASE_DIR, "pdfs")
TXT_DIR = os.path.join(BASE_DIR, "txt")
AUDIO_DIR = os.path.join(BASE_DIR, "audio")


def ensure_dirs():
    for d in [PDF_DIR, TXT_DIR, AUDIO_DIR]:
        os.makedirs(d, exist_ok=True)


# =========================================================================
# PDF GENERATION
# =========================================================================

class MedicalPDF(FPDF):
    def header(self):
        self.set_font("Helvetica", "B", 10)
        self.cell(0, 8, self._header_text, align="C", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(0, 102, 153)
        self.set_line_width(0.5)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(4)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}} | CONFIDENTIAL -- Protected Health Information", align="C")

    def section(self, title, body):
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(0, 102, 153)
        self.cell(0, 8, title, new_x="LMARGIN", new_y="NEXT")
        self.set_font("Helvetica", "", 10)
        self.set_text_color(0, 0, 0)
        self.multi_cell(0, 5, body)
        self.ln(3)

    def field(self, label, value):
        self.set_font("Helvetica", "B", 10)
        self.cell(55, 6, f"{label}:")
        self.set_font("Helvetica", "", 10)
        self.cell(0, 6, value, new_x="LMARGIN", new_y="NEXT")


def gen_discharge_summary():
    pdf = MedicalPDF()
    pdf._header_text = "MERCY GENERAL HOSPITAL -- DISCHARGE SUMMARY"
    pdf.alias_nb_pages()
    pdf.add_page()

    pdf.field("Patient Name", "John Whitfield")
    pdf.field("Date of Birth", "03/15/1958")
    pdf.field("MRN", "MRN-20240610-JW")
    pdf.field("Admission Date", "06/08/2024")
    pdf.field("Discharge Date", "06/12/2024")
    pdf.field("Attending Physician", "Dr. Sarah Chen, MD -- Internal Medicine")
    pdf.field("Primary Diagnosis", "Hypertensive Crisis (ICD-10: I16.0)")
    pdf.ln(4)

    pdf.section("CHIEF COMPLAINT",
        "Patient presented to the emergency department with severe headache, "
        "blurred vision, and blood pressure reading of 210/130 mmHg. Patient "
        "reported non-compliance with prescribed antihypertensive medication "
        "for approximately 3 weeks due to cost concerns.")

    pdf.section("HISTORY OF PRESENT ILLNESS",
        "Mr. Whitfield is a 66-year-old male with a 15-year history of essential "
        "hypertension, type 2 diabetes mellitus, and hyperlipidemia. He was brought "
        "to the ED by his wife after experiencing a sudden onset severe occipital "
        "headache, visual disturbances, and mild chest discomfort. On arrival, "
        "his blood pressure was 210/130 mmHg, heart rate 102 bpm, and oxygen "
        "saturation 94% on room air. He denied any recent illness, trauma, or "
        "substance use. He admitted to stopping his lisinopril and amlodipine "
        "three weeks prior because he could not afford the copay.")

    pdf.section("HOSPITAL COURSE",
        "Patient was admitted to the ICU for IV nicardipine drip for controlled "
        "blood pressure reduction. Target MAP reduction of 25% achieved within "
        "first hour. CT head was negative for intracranial hemorrhage. "
        "Echocardiogram showed mild left ventricular hypertrophy with preserved "
        "ejection fraction of 55%. Renal function remained stable with creatinine "
        "1.2 mg/dL. Patient was transitioned to oral medications on day 2 with "
        "good blood pressure control. Social work consulted for medication "
        "assistance program enrollment. Patient educated on importance of "
        "medication compliance and signs of hypertensive emergency.")

    pdf.section("DISCHARGE MEDICATIONS",
        "1. Amlodipine 10 mg PO daily\n"
        "2. Lisinopril 40 mg PO daily\n"
        "3. Hydrochlorothiazide 25 mg PO daily\n"
        "4. Metformin 1000 mg PO twice daily\n"
        "5. Atorvastatin 40 mg PO at bedtime\n"
        "6. Aspirin 81 mg PO daily")

    pdf.section("FOLLOW-UP INSTRUCTIONS",
        "1. Follow up with Dr. Sarah Chen in 1 week for BP check\n"
        "2. Cardiology referral -- Dr. James Okafor for echocardiogram follow-up\n"
        "3. Home blood pressure monitoring twice daily, keep log\n"
        "4. Low sodium diet (<2g/day), DASH diet recommended\n"
        "5. Return to ED if BP >180/120, severe headache, chest pain, or vision changes\n"
        "6. Patient assistance program application submitted for medication coverage")

    pdf.section("DISCHARGE CONDITION", "Stable. Blood pressure at discharge: 142/88 mmHg.")

    pdf.output(os.path.join(PDF_DIR, "discharge_summary_whitfield.pdf"))


def gen_lab_report():
    pdf = MedicalPDF()
    pdf._header_text = "MERCY GENERAL HOSPITAL -- LABORATORY REPORT"
    pdf.alias_nb_pages()
    pdf.add_page()

    pdf.field("Patient Name", "Margaret Sullivan")
    pdf.field("Date of Birth", "11/22/1965")
    pdf.field("MRN", "MRN-20240701-MS")
    pdf.field("Collection Date", "07/01/2024")
    pdf.field("Report Date", "07/02/2024")
    pdf.field("Ordering Physician", "Dr. James Okafor, MD -- Cardiology")
    pdf.field("Specimen Type", "Venous Blood")
    pdf.ln(4)

    pdf.section("COMPLETE BLOOD COUNT (CBC)",
        "WBC:          7.2 x10^3/uL    (Ref: 4.5-11.0)     NORMAL\n"
        "RBC:          4.1 x10^6/uL    (Ref: 3.8-5.1)      NORMAL\n"
        "Hemoglobin:   12.8 g/dL       (Ref: 12.0-16.0)     NORMAL\n"
        "Hematocrit:   38.2%           (Ref: 36.0-46.0)     NORMAL\n"
        "Platelets:    245 x10^3/uL    (Ref: 150-400)       NORMAL\n"
        "MCV:          93.2 fL         (Ref: 80.0-100.0)    NORMAL\n"
        "MCH:          31.2 pg         (Ref: 27.0-33.0)     NORMAL")

    pdf.section("COMPREHENSIVE METABOLIC PANEL",
        "Glucose:      142 mg/dL       (Ref: 70-100)        HIGH *\n"
        "BUN:          22 mg/dL        (Ref: 7-20)          HIGH *\n"
        "Creatinine:   1.4 mg/dL       (Ref: 0.6-1.2)      HIGH *\n"
        "eGFR:         52 mL/min       (Ref: >60)           LOW *\n"
        "Sodium:       139 mEq/L       (Ref: 136-145)       NORMAL\n"
        "Potassium:    4.8 mEq/L       (Ref: 3.5-5.0)      NORMAL\n"
        "Chloride:     102 mEq/L       (Ref: 98-106)        NORMAL\n"
        "CO2:          24 mEq/L        (Ref: 23-29)         NORMAL\n"
        "Calcium:      9.2 mg/dL       (Ref: 8.5-10.5)      NORMAL\n"
        "Total Protein: 7.1 g/dL       (Ref: 6.0-8.3)      NORMAL\n"
        "Albumin:      3.8 g/dL        (Ref: 3.5-5.0)      NORMAL\n"
        "AST (SGOT):   28 U/L          (Ref: 10-40)         NORMAL\n"
        "ALT (SGPT):   34 U/L          (Ref: 7-56)          NORMAL")

    pdf.section("LIPID PANEL",
        "Total Cholesterol:  248 mg/dL  (Ref: <200)         HIGH *\n"
        "LDL Cholesterol:    168 mg/dL  (Ref: <100)         HIGH *\n"
        "HDL Cholesterol:    38 mg/dL   (Ref: >40)          LOW *\n"
        "Triglycerides:      210 mg/dL  (Ref: <150)         HIGH *\n"
        "VLDL:               42 mg/dL   (Ref: 5-40)         HIGH *")

    pdf.section("CARDIAC BIOMARKERS",
        "Troponin I:    0.02 ng/mL     (Ref: <0.04)        NORMAL\n"
        "BNP:           320 pg/mL      (Ref: <100)          HIGH *\n"
        "CRP (hs):      3.8 mg/L       (Ref: <1.0)         HIGH *")

    pdf.section("HEMOGLOBIN A1C",
        "HbA1c:         7.2%           (Ref: <5.7)          HIGH *\n"
        "Estimated Avg Glucose: 160 mg/dL")

    pdf.section("INTERPRETATION",
        "Abnormal findings indicate elevated cardiovascular risk. Elevated BNP "
        "suggests cardiac strain consistent with known atherosclerotic heart disease. "
        "Elevated creatinine and reduced eGFR suggest Stage 3a chronic kidney disease. "
        "Lipid panel significantly elevated -- current statin therapy may need adjustment. "
        "HbA1c of 7.2% indicates suboptimal glycemic control. Recommend cardiology "
        "and nephrology follow-up.")

    pdf.output(os.path.join(PDF_DIR, "lab_report_sullivan.pdf"))


def gen_prescription():
    pdf = MedicalPDF()
    pdf._header_text = "MERCY GENERAL HOSPITAL -- PRESCRIPTION"
    pdf.alias_nb_pages()
    pdf.add_page()

    pdf.field("Patient Name", "Roberto Garcia")
    pdf.field("Date of Birth", "09/12/1955")
    pdf.field("MRN", "MRN-20240805-RG")
    pdf.field("Date", "08/05/2024")
    pdf.field("Prescribing Physician", "Dr. James Okafor, MD -- Cardiology")
    pdf.field("DEA Number", "BO1234567")
    pdf.field("Insurance", "Medicare Advantage -- Plan ID: MA-2024-RG")
    pdf.ln(4)

    pdf.section("DIAGNOSIS",
        "Atherosclerotic heart disease (I25.10)\n"
        "Post left heart catheterization\n"
        "Essential hypertension (I10)")

    pdf.section("PRESCRIPTIONS",
        "Rx 1: Clopidogrel (Plavix) 75 mg tablets\n"
        "   Sig: Take one tablet by mouth once daily\n"
        "   Dispense: #90 (ninety)\n"
        "   Refills: 3\n"
        "   Purpose: Antiplatelet therapy post-catheterization\n\n"
        "Rx 2: Metoprolol Succinate ER 50 mg tablets\n"
        "   Sig: Take one tablet by mouth once daily in the morning\n"
        "   Dispense: #90 (ninety)\n"
        "   Refills: 3\n"
        "   Purpose: Heart rate and blood pressure control\n\n"
        "Rx 3: Atorvastatin 80 mg tablets\n"
        "   Sig: Take one tablet by mouth at bedtime\n"
        "   Dispense: #90 (ninety)\n"
        "   Refills: 3\n"
        "   Purpose: High-intensity statin therapy for atherosclerosis\n\n"
        "Rx 4: Nitroglycerin 0.4 mg sublingual tablets\n"
        "   Sig: Place one tablet under tongue as needed for chest pain.\n"
        "        May repeat every 5 minutes x 3 doses. Call 911 if no relief.\n"
        "   Dispense: #25 (twenty-five)\n"
        "   Refills: 5\n"
        "   Purpose: Acute angina relief\n\n"
        "Rx 5: Lisinopril 20 mg tablets\n"
        "   Sig: Take one tablet by mouth once daily\n"
        "   Dispense: #90 (ninety)\n"
        "   Refills: 3\n"
        "   Purpose: ACE inhibitor for cardioprotection and blood pressure")

    pdf.section("PATIENT INSTRUCTIONS",
        "1. Do not stop clopidogrel without consulting your cardiologist\n"
        "2. Take metoprolol at the same time each morning\n"
        "3. Report any unusual bleeding, bruising, or muscle pain\n"
        "4. Follow up in 4 weeks for medication review\n"
        "5. Cardiac rehabilitation program enrollment recommended\n"
        "6. Low sodium, heart-healthy diet. No grapefruit with atorvastatin.")

    pdf.output(os.path.join(PDF_DIR, "prescription_garcia.pdf"))


def gen_radiology_report():
    pdf = MedicalPDF()
    pdf._header_text = "ST. LUKE'S MEDICAL CENTER -- RADIOLOGY REPORT"
    pdf.alias_nb_pages()
    pdf.add_page()

    pdf.field("Patient Name", "David Park")
    pdf.field("Date of Birth", "07/08/1972")
    pdf.field("MRN", "MRN-20240710-DP")
    pdf.field("Exam Date", "06/28/2024")
    pdf.field("Report Date", "06/29/2024")
    pdf.field("Referring Physician", "Dr. Maria Rodriguez, MD -- Orthopedics")
    pdf.field("Radiologist", "Dr. Emily Foster, MD -- Radiology")
    pdf.field("Exam Type", "MRI Right Knee without and with contrast")
    pdf.ln(4)

    pdf.section("CLINICAL INDICATION",
        "52-year-old male with chronic right knee pain, mechanical locking, and "
        "instability. Rule out meniscal tear, evaluate for degenerative changes. "
        "Patient is being evaluated for potential total knee replacement.")

    pdf.section("TECHNIQUE",
        "MRI of the right knee was performed on a 3T scanner using standard knee "
        "coil. Sequences obtained: sagittal PD fat-sat, coronal PD fat-sat, "
        "axial PD fat-sat, sagittal T1, and post-gadolinium sagittal and coronal "
        "T1 fat-sat sequences. IV gadolinium contrast (15 mL Gadavist) was "
        "administered without adverse reaction.")

    pdf.section("FINDINGS",
        "MENISCI:\n"
        "- Medial meniscus: Complex tear involving the posterior horn and body with "
        "a displaced fragment measuring approximately 8mm extending into the "
        "intercondylar notch. Grade III signal abnormality.\n"
        "- Lateral meniscus: Mild degenerative signal changes (Grade II) in the "
        "posterior horn without discrete tear.\n\n"
        "LIGAMENTS:\n"
        "- ACL: Intact with normal signal and tension.\n"
        "- PCL: Intact.\n"
        "- MCL: Mild thickening suggesting chronic low-grade sprain. No acute tear.\n"
        "- LCL: Intact.\n\n"
        "ARTICULAR CARTILAGE:\n"
        "- Diffuse Grade III-IV chondral loss along the medial femoral condyle and "
        "medial tibial plateau with areas of full-thickness cartilage loss and "
        "subchondral bone edema.\n"
        "- Moderate Grade II-III chondral thinning of the patellofemoral compartment.\n"
        "- Lateral compartment shows mild Grade II changes.\n\n"
        "BONE:\n"
        "- Subchondral bone marrow edema in the medial femoral condyle and medial "
        "tibial plateau.\n"
        "- Small subchondral cyst (6mm) in the medial tibial plateau.\n"
        "- No acute fracture.\n\n"
        "OTHER:\n"
        "- Moderate joint effusion.\n"
        "- Baker's cyst measuring 2.8 x 1.5 cm in the popliteal fossa.\n"
        "- Mild synovitis with post-contrast enhancement.")

    pdf.section("IMPRESSION",
        "1. Complex medial meniscus tear with displaced fragment -- surgical consultation "
        "recommended\n"
        "2. Advanced tricompartmental osteoarthritis, most severe in the medial "
        "compartment with Grade III-IV chondral loss\n"
        "3. Moderate joint effusion and Baker's cyst\n"
        "4. Chronic MCL sprain\n\n"
        "Given the severity of degenerative changes and complex meniscal pathology, "
        "findings support consideration for total knee arthroplasty as discussed "
        "with the referring surgeon.")

    pdf.output(os.path.join(PDF_DIR, "radiology_report_park.pdf"))


def gen_insurance_claim():
    pdf = MedicalPDF()
    pdf._header_text = "HARTFORD HEALTHCARE CANCER CENTER -- INSURANCE CLAIM FORM"
    pdf.alias_nb_pages()
    pdf.add_page()

    pdf.field("Claim Number", "CLM-2024-08-1007")
    pdf.field("Patient Name", "Linda Brown")
    pdf.field("Date of Birth", "12/05/1948")
    pdf.field("Insurance Plan", "Medicare Advantage")
    pdf.field("Member ID", "MA-2024-LB-8842")
    pdf.field("Group Number", "GRP-MEDICARE-CT")
    pdf.field("Provider", "Dr. Aisha Patel, MD -- Oncology")
    pdf.field("Facility", "Hartford Healthcare Cancer Center")
    pdf.field("Service Date", "08/12/2024")
    pdf.ln(4)

    pdf.section("SERVICES RENDERED",
        "CPT Code: 88305 -- Surgical Pathology, tissue examination\n"
        "ICD-10: C50.911 -- Malignant neoplasm of unspecified site of right breast\n\n"
        "Description: Pathological examination of breast tissue specimen obtained "
        "via image-guided core needle biopsy performed on 08/10/2024. Specimen "
        "submitted for histological analysis including H&E staining, "
        "immunohistochemistry panel (ER, PR, HER2, Ki-67).\n\n"
        "Units: 1\n"
        "Billed Amount: $425.00\n"
        "Allowed Amount: $340.00\n"
        "Insurance Payment: $272.00 (80%)\n"
        "Patient Responsibility: $68.00 (20% coinsurance)")

    pdf.section("PATHOLOGY RESULTS SUMMARY",
        "Invasive ductal carcinoma, Grade 2 (moderately differentiated)\n"
        "Tumor size: 1.4 cm\n"
        "ER: Positive (95%)\n"
        "PR: Positive (80%)\n"
        "HER2: Negative (Score 1+)\n"
        "Ki-67: 18%\n"
        "Margins: Cannot be assessed on core biopsy specimen\n"
        "Lymphovascular invasion: Not identified on this specimen")

    pdf.section("PRIOR AUTHORIZATION",
        "Prior Authorization Number: PA-2024-LB-5521\n"
        "Authorized Date: 08/08/2024\n"
        "Authorization Status: APPROVED\n"
        "Authorized Services: Diagnostic pathology and immunohistochemistry panel")

    pdf.section("ADDITIONAL PLANNED SERVICES (pending authorization)",
        "1. Breast MRI for staging -- CPT 77049\n"
        "2. Sentinel lymph node biopsy -- CPT 38525\n"
        "3. Oncotype DX genomic testing -- CPT 81519\n"
        "4. Surgical consultation for lumpectomy vs mastectomy\n"
        "5. Radiation oncology consultation")

    pdf.output(os.path.join(PDF_DIR, "insurance_claim_brown.pdf"))


def gen_clinical_notes():
    pdf = MedicalPDF()
    pdf._header_text = "SILVER HILL HOSPITAL -- CLINICAL NOTES"
    pdf.alias_nb_pages()
    pdf.add_page()

    pdf.field("Patient Name", "Patricia O'Brien")
    pdf.field("Date of Birth", "08/25/1975")
    pdf.field("MRN", "MRN-20240901-PO")
    pdf.field("Session Date", "09/01/2024")
    pdf.field("Session Type", "Individual Psychotherapy -- 45 minutes (Telehealth)")
    pdf.field("Provider", "Dr. David Thompson, MD -- Psychiatry")
    pdf.field("Diagnosis", "Major Depressive Disorder, Recurrent, Mild (F33.0)")
    pdf.ln(4)

    pdf.section("SUBJECTIVE",
        "Patient reports mild improvement in mood since last session two weeks ago. "
        "She states she has been taking sertraline 100mg daily as prescribed without "
        "missed doses. Sleep has improved from 4-5 hours to approximately 6 hours per "
        "night, though she still reports early morning awakening around 4:30 AM. "
        "Appetite remains decreased but she is eating regular meals. She reports "
        "returning to her daily walking routine (30 minutes, 4 days per week). "
        "She describes ongoing difficulty concentrating at work and feelings of "
        "guilt related to her divorce proceedings. Denies suicidal ideation, "
        "self-harm urges, or homicidal ideation. Denies substance use. Reports "
        "moderate stress related to custody arrangement negotiations.")

    pdf.section("OBJECTIVE",
        "PHQ-9 Score: 11 (moderate depression) -- improved from 15 at last visit\n"
        "GAD-7 Score: 8 (mild anxiety) -- stable from last visit\n"
        "Appearance: Well-groomed, appropriate attire for telehealth session\n"
        "Behavior: Cooperative, engaged, maintained eye contact via camera\n"
        "Speech: Normal rate, rhythm, and volume\n"
        "Mood: 'A little better, but still struggling'\n"
        "Affect: Congruent, mildly restricted range, tearful when discussing custody\n"
        "Thought Process: Linear, goal-directed\n"
        "Thought Content: No SI/HI, no delusions, no obsessions\n"
        "Cognition: Alert, oriented x4\n"
        "Insight: Good\n"
        "Judgment: Good")

    pdf.section("ASSESSMENT",
        "49-year-old female with MDD, recurrent, showing gradual improvement with "
        "current treatment regimen. PHQ-9 decreased from 15 to 11 indicating "
        "positive treatment response. Sleep and activity level improving. Ongoing "
        "psychosocial stressors (divorce, custody) contributing to persistent "
        "symptoms. No safety concerns at this time.")

    pdf.section("PLAN",
        "1. Continue sertraline 100 mg daily -- no dose change at this time\n"
        "2. Continue cognitive behavioral therapy (CBT), focus on:\n"
        "   - Cognitive restructuring around guilt and self-blame\n"
        "   - Behavioral activation -- maintain exercise routine\n"
        "   - Sleep hygiene techniques for early morning awakening\n"
        "3. Discussed adding melatonin 3mg at bedtime for sleep onset\n"
        "4. Referral to family therapist for co-parenting support\n"
        "5. Next session in 2 weeks (09/15/2024) via telehealth\n"
        "6. Patient to call crisis line (988) if safety concerns arise\n"
        "7. Re-assess PHQ-9 and GAD-7 at next session")

    pdf.output(os.path.join(PDF_DIR, "clinical_notes_obrien.pdf"))


# =========================================================================
# TXT GENERATION
# =========================================================================

def gen_referral_letter():
    text = """YALE NEW HAVEN HOSPITAL -- NEUROLOGY DEPARTMENT
REFERRAL LETTER

Date: August 15, 2024
From: Dr. Sarah Chen, MD -- Internal Medicine, Mercy General Hospital
To: Dr. Robert Kim, MD -- Neurology, Yale New Haven Hospital

RE: Patient Wei Zhang, DOB: 04/17/1990, MRN: MRN-20240820-WZ

Dear Dr. Kim,

I am writing to refer Mr. Wei Zhang, a 34-year-old male, for neurological evaluation of suspected seizure disorder.

CLINICAL HISTORY:
Mr. Zhang presented to my office on August 10, 2024 reporting two episodes of loss of consciousness over the past three months. The first episode occurred at his workplace on May 22, 2024, witnessed by coworkers who described generalized tonic-clonic movements lasting approximately 2-3 minutes with post-ictal confusion lasting 30 minutes. The second episode occurred at home on August 3, 2024, witnessed by his wife, with similar presentation.

Between episodes, the patient reports occasional "spacing out" spells lasting 10-15 seconds, during which he is unresponsive, approximately 2-3 times per week. He also reports intermittent bilateral temporal headaches and fatigue.

RELEVANT HISTORY:
- No prior history of seizures or neurological conditions
- No history of head trauma, meningitis, or encephalitis
- Family history: maternal uncle with epilepsy (diagnosed age 28)
- No substance use, no alcohol abuse
- Current medications: None
- Allergies: NKDA

WORKUP TO DATE:
- Basic metabolic panel: Normal
- CBC: Normal
- TSH: 2.1 mIU/L (normal)
- Blood glucose: 92 mg/dL (normal)
- Standard 12-lead ECG: Normal sinus rhythm, no arrhythmia

REQUESTED EVALUATION:
1. EEG with sleep deprivation
2. MRI brain with and without contrast
3. Neurological examination and seizure classification
4. Treatment recommendations if epilepsy is confirmed

The patient understands the referral and is eager to pursue evaluation. He is concerned about driving restrictions and occupational safety given his work as a software engineer.

Please do not hesitate to contact my office if you need additional information.

Sincerely,
Dr. Sarah Chen, MD
Internal Medicine
Mercy General Hospital, Hartford, CT
Phone: (860) 555-0142
Fax: (860) 555-0143
"""
    with open(os.path.join(TXT_DIR, "referral_letter_zhang.txt"), "w") as f:
        f.write(text)


def gen_pathology_report():
    text = """YALE NEW HAVEN HOSPITAL -- PATHOLOGY DEPARTMENT
PATHOLOGY REPORT

Patient: Catherine Lee
DOB: 10/03/1960
MRN: MRN-20241001-CL
Specimen Collection Date: 09/28/2024
Report Date: 10/01/2024
Referring Physician: Dr. Priya Sharma, MD -- Endocrinology
Pathologist: Dr. Amanda Rivers, MD -- Pathology

SPECIMEN:
A. Thyroid, right lobe -- fine needle aspiration
B. Thyroid, left lobe -- fine needle aspiration

CLINICAL HISTORY:
64-year-old female with type 2 diabetes mellitus and newly discovered thyroid nodules on routine ultrasound. Right lobe nodule measures 2.3 cm, left lobe nodule measures 1.1 cm. TI-RADS 4 (right), TI-RADS 3 (left). TSH: 3.8 mIU/L (normal). Patient has no history of neck radiation, no family history of thyroid cancer.

GROSS DESCRIPTION:
Specimen A: Two air-dried smears and two alcohol-fixed smears from ultrasound-guided FNA of right thyroid nodule. Two passes performed.
Specimen B: Two air-dried smears and two alcohol-fixed smears from ultrasound-guided FNA of left thyroid nodule. Two passes performed.

MICROSCOPIC FINDINGS:
Specimen A (Right lobe, 2.3 cm nodule):
- Moderately cellular specimen
- Follicular cells arranged in microfollicular and trabecular patterns
- Nuclear enlargement with irregular nuclear contours
- Occasional nuclear grooves identified
- No definitive papillary nuclear features (no intranuclear pseudoinclusions)
- Scant colloid
- No necrosis or mitotic figures

Specimen B (Left lobe, 1.1 cm nodule):
- Adequately cellular specimen
- Follicular cells in macrofollicular arrangements
- Uniform nuclei without atypia
- Abundant colloid
- Background consistent with benign thyroid tissue

DIAGNOSIS:
Specimen A: BETHESDA CATEGORY IV -- Follicular neoplasm / suspicious for follicular neoplasm
- Recommendation: Diagnostic lobectomy (right) with intraoperative frozen section
- Molecular testing (Afirma/ThyroSeq) may be considered prior to surgery

Specimen B: BETHESDA CATEGORY II -- Benign
- Consistent with benign colloid nodule
- Recommendation: Follow-up ultrasound in 12-18 months

COMMENT:
The right thyroid nodule demonstrates features concerning for follicular neoplasm. Distinction between follicular adenoma and follicular carcinoma requires histological evaluation of the capsule and vascular invasion, which cannot be assessed on cytology. Surgical consultation is recommended. Molecular testing may help risk-stratify if the patient prefers to avoid surgery initially.

Electronically signed by:
Dr. Amanda Rivers, MD
Department of Pathology
Yale New Haven Hospital
"""
    with open(os.path.join(TXT_DIR, "pathology_report_lee.txt"), "w") as f:
        f.write(text)


def gen_patient_intake():
    text = """BRIDGEPORT HOSPITAL -- PULMONOLOGY DEPARTMENT
PATIENT INTAKE QUESTIONNAIRE

Date: September 10, 2024
Patient Name: Michael Torres
Date of Birth: 02/14/1988
Age: 36
Gender: Male
Provider: Dr. Ahmed Hassan, MD -- Pulmonology

REASON FOR VISIT:
Evaluation of persistent asthma with recent worsening of symptoms

CURRENT SYMPTOMS:
- Wheezing: Yes, 3-4 times per week, worse at night and early morning
- Shortness of breath: Yes, with moderate exertion (climbing stairs, brisk walking)
- Chest tightness: Occasional, mainly in cold weather
- Cough: Chronic, dry, worse at night, 5-6 episodes per week
- Sputum production: Minimal, clear
- Nocturnal symptoms: Awakens 2-3 times per week due to coughing or wheezing
- Exercise limitation: Cannot jog more than 10 minutes without significant dyspnea
- Rescue inhaler use: 4-5 times per week (albuterol)

SYMPTOM TRIGGERS:
[X] Cold air
[X] Exercise
[X] Dust / allergens
[X] Strong odors / perfumes
[ ] Tobacco smoke (not exposed)
[X] Stress
[ ] Medications (aspirin/NSAIDs)
[X] Seasonal changes (worse in fall/spring)

MEDICAL HISTORY:
- Asthma diagnosed age 12, previously well-controlled
- Allergic rhinitis
- No hospitalizations for asthma
- One ER visit in 2022 for acute exacerbation (treated with nebulizer, steroids)
- No intubation history
- No prior lung function testing in past 3 years

CURRENT MEDICATIONS:
1. Albuterol (ProAir HFA) 90 mcg -- 2 puffs as needed (using 4-5x/week)
2. Fluticasone propionate (Flovent HFA) 110 mcg -- 2 puffs twice daily
3. Cetirizine 10 mg daily
4. Montelukast 10 mg at bedtime

ALLERGIES:
- Penicillin (rash)
- Environmental: dust mites, cat dander, ragweed, mold

FAMILY HISTORY:
- Mother: Asthma, allergic rhinitis
- Father: Hypertension
- Sister: Eczema

SOCIAL HISTORY:
- Occupation: Construction site supervisor (outdoor exposure)
- Tobacco: Never smoker
- Alcohol: Social, 2-3 drinks per week
- Recreational drugs: None
- Exercise: Tries to exercise but limited by symptoms
- Pets: One dog (no symptoms with dog)
- Home: Apartment, carpet in bedroom, no visible mold

PATIENT CONCERNS:
"My asthma has been getting worse over the past 6 months despite taking my inhalers. I'm worried because I can't keep up with my job which requires physical activity. I want to know if there are better treatment options."

SPIROMETRY RESULTS (performed today):
- FEV1: 72% predicted (pre-bronchodilator)
- FEV1: 84% predicted (post-bronchodilator) -- 16% improvement
- FVC: 88% predicted
- FEV1/FVC ratio: 0.72

ASSESSMENT: Mild persistent asthma with suboptimal control on current Step 3 therapy.
Recommend step-up to Step 4: Consider adding LABA (formoterol or salmeterol) to current ICS, or switch to combination ICS/LABA inhaler. Allergy evaluation and possible immunotherapy referral.
"""
    with open(os.path.join(TXT_DIR, "patient_intake_torres.txt"), "w") as f:
        f.write(text)


def gen_nurse_notes():
    text = """YALE NEW HAVEN HOSPITAL -- NURSING ASSESSMENT
POST-OPERATIVE PROGRESS NOTES

Patient: Thomas Anderson
DOB: 07/11/1952
MRN: MRN-20241101-TA
Room: CVICU Bed 4
Date: November 2, 2024 (POD #1)
Surgery: Coronary Artery Bypass Graft (CABG) x3 -- November 1, 2024
Surgeon: Dr. James Okafor, MD -- Cardiology / Cardiac Surgery

VITAL SIGNS (0600):
- Temperature: 37.2°C (99.0°F)
- Heart Rate: 88 bpm, sinus rhythm
- Blood Pressure: 128/76 mmHg (arterial line)
- Respiratory Rate: 16 breaths/min
- SpO2: 96% on 2L nasal cannula
- CVP: 8 mmHg
- Urine output: 45 mL/hr (adequate)
- Pain: 6/10 at sternal incision site

NEUROLOGICAL:
- Alert and oriented x4 (person, place, time, situation)
- Pupils equal, round, reactive to light
- Moving all extremities equally
- No focal deficits
- Mild drowsiness attributed to opioid analgesics

CARDIOVASCULAR:
- Heart sounds: S1, S2 regular, no murmur appreciated
- Sternal incision: Clean, dry, intact, no erythema or drainage
- Chest tubes (2): Left pleural -- draining 30 mL/hr serosanguineous
  Mediastinal -- draining 15 mL/hr serosanguineous
- Left saphenous vein harvest site: ACE wrap intact, mild edema, no hematoma
- Peripheral pulses: 2+ bilateral dorsalis pedis and posterior tibial
- No signs of DVT
- Telemetry: Normal sinus rhythm, occasional PVCs (2-3 per minute)

RESPIRATORY:
- Extubated at 2200 on 11/01, tolerating nasal cannula well
- Lung sounds: Diminished bilateral bases, clear upper lobes
- Incentive spirometry: Achieving 1000 mL (target 1500 mL)
- Coughing with splinting -- productive of small amount clear sputum
- Chest X-ray ordered for 0800

GASTROINTESTINAL:
- Abdomen soft, non-distended, bowel sounds present in all quadrants
- NPO overnight, clear liquid diet started at 0600
- Tolerating sips of water and apple juice
- No nausea or vomiting

RENAL / FLUIDS:
- Foley catheter in place, urine clear yellow
- I&O (past 12 hours): Intake 1200 mL, Output 980 mL (positive balance 220 mL)
- Creatinine: 1.3 mg/dL (baseline 1.1)
- Electrolytes: K+ 4.2, Mg 2.0 -- within normal limits

PAIN MANAGEMENT:
- Morphine PCA: 1 mg demand dose, 8 min lockout, 30 mg 4-hr limit
- PCA usage overnight: 12 demands, 8 delivered
- Alternating with acetaminophen 1000 mg IV q6h
- Current pain: 6/10 sternal, 3/10 left leg harvest site
- Plan to transition to oral oxycodone when tolerating diet

MEDICATIONS ADMINISTERED (past 12 hours):
- Aspirin 325 mg PO (given at 0600 with sips)
- Metoprolol 12.5 mg PO BID (given at 0600)
- Atorvastatin 80 mg PO (given at 0600)
- Heparin 5000 units SubQ q8h (DVT prophylaxis)
- Pantoprazole 40 mg IV daily
- Cefazolin 1g IV q8h (surgical prophylaxis -- last dose #6 of 6)
- Insulin sliding scale (blood glucose 0600: 168 mg/dL -- 4 units regular insulin given)

PLAN / GOALS FOR TODAY:
1. Ambulate to chair x2 today with cardiac rehab team
2. Advance diet to regular cardiac diet if tolerating clears
3. Incentive spirometry q1h while awake -- target 1500 mL
4. Remove arterial line if hemodynamically stable by 1200
5. Wean supplemental O2 -- target SpO2 >94% on room air
6. Continue chest tube monitoring -- consider removal if output <100 mL/8hr
7. Physical therapy evaluation for ambulation progression
8. Pain management reassessment -- transition to oral analgesics
9. Social work consult for discharge planning (anticipated discharge POD #4-5)
10. Family meeting at 1400 with Dr. Okafor for surgical update

Documented by: Sarah Mitchell, RN, BSN, CCRN
Time: 0630
Cosigned by: Dr. James Okafor, MD
"""
    with open(os.path.join(TXT_DIR, "nurse_notes_anderson.txt"), "w") as f:
        f.write(text)


# =========================================================================
# AUDIO GENERATION (synthesized tones -- valid WAV/MP3 files)
# =========================================================================

def generate_tone_wav(filepath, duration_sec=10, sample_rate=16000, frequencies=None):
    """Generate a WAV file with layered sine wave tones (simulates audio content)."""
    if frequencies is None:
        frequencies = [440]

    n_samples = int(duration_sec * sample_rate)
    samples = []

    for i in range(n_samples):
        t = i / sample_rate
        value = 0
        for freq in frequencies:
            # Add slight frequency variation to make it more interesting
            mod_freq = freq * (1 + 0.02 * math.sin(2 * math.pi * 0.5 * t))
            value += math.sin(2 * math.pi * mod_freq * t)

        # Add some amplitude modulation (simulates speech-like envelope)
        envelope = 0.5 + 0.5 * math.sin(2 * math.pi * 2.5 * t)
        value = value / len(frequencies) * envelope

        # Add subtle noise
        value += random.uniform(-0.02, 0.02)

        # Clamp and convert to 16-bit
        value = max(-1.0, min(1.0, value * 0.7))
        samples.append(int(value * 32767))

    with wave.open(filepath, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def wav_to_mp3(wav_path, mp3_path, bitrate=128):
    """Convert WAV to MP3 using lameenc."""
    with wave.open(wav_path, "r") as wf:
        pcm_data = wf.readframes(wf.getnframes())
        sample_rate = wf.getframerate()
        channels = wf.getnchannels()

    encoder = lameenc.Encoder()
    encoder.set_bit_rate(bitrate)
    encoder.set_in_sample_rate(sample_rate)
    encoder.set_channels(channels)
    encoder.set_quality(2)

    mp3_data = encoder.encode(pcm_data)
    mp3_data += encoder.flush()

    with open(mp3_path, "wb") as f:
        f.write(mp3_data)


def gen_audio_files():
    """Generate WAV and MP3 sample files with distinct tone patterns."""

    # WAV 1: BP consultation -- calm, steady tones
    generate_tone_wav(
        os.path.join(AUDIO_DIR, "consultation_whitfield_bp.wav"),
        duration_sec=12, sample_rate=16000,
        frequencies=[220, 330, 440]
    )

    # WAV 2: Cardiac follow-up -- slightly more complex
    generate_tone_wav(
        os.path.join(AUDIO_DIR, "consultation_garcia_cardiac.wav"),
        duration_sec=15, sample_rate=16000,
        frequencies=[261, 329, 392, 523]
    )

    # WAV 3: Therapy session -- longer, softer
    generate_tone_wav(
        os.path.join(AUDIO_DIR, "consultation_obrien_therapy.wav"),
        duration_sec=18, sample_rate=16000,
        frequencies=[196, 247, 294]
    )

    # MP3 1: Pediatric visit -- higher pitched
    wav_tmp = os.path.join(AUDIO_DIR, "_tmp_pediatric.wav")
    generate_tone_wav(
        wav_tmp, duration_sec=10, sample_rate=16000,
        frequencies=[523, 659, 784]
    )
    wav_to_mp3(wav_tmp, os.path.join(AUDIO_DIR, "consultation_johnson_pediatric.mp3"))
    os.remove(wav_tmp)

    # MP3 2: Dermatology visit -- mid-range
    wav_tmp = os.path.join(AUDIO_DIR, "_tmp_dermatology.wav")
    generate_tone_wav(
        wav_tmp, duration_sec=8, sample_rate=16000,
        frequencies=[349, 440, 523]
    )
    wav_to_mp3(wav_tmp, os.path.join(AUDIO_DIR, "consultation_tanaka_dermatology.mp3"))
    os.remove(wav_tmp)


# =========================================================================
# MAIN
# =========================================================================

def main():
    print("Generating sample healthcare files...")
    ensure_dirs()

    # PDFs
    print("  [1/6] Discharge summary (Whitfield)...")
    gen_discharge_summary()
    print("  [2/6] Lab report (Sullivan)...")
    gen_lab_report()
    print("  [3/6] Prescription (Garcia)...")
    gen_prescription()
    print("  [4/6] Radiology report (Park)...")
    gen_radiology_report()
    print("  [5/6] Insurance claim (Brown)...")
    gen_insurance_claim()
    print("  [6/6] Clinical notes (O'Brien)...")
    gen_clinical_notes()

    # TXT
    print("  [1/4] Referral letter (Zhang)...")
    gen_referral_letter()
    print("  [2/4] Pathology report (Lee)...")
    gen_pathology_report()
    print("  [3/4] Patient intake (Torres)...")
    gen_patient_intake()
    print("  [4/4] Nurse notes (Anderson)...")
    gen_nurse_notes()

    # Audio
    print("  [1/5] WAV: BP consultation (Whitfield)...")
    print("  [2/5] WAV: Cardiac consultation (Garcia)...")
    print("  [3/5] WAV: Therapy session (O'Brien)...")
    print("  [4/5] MP3: Pediatric visit (Johnson)...")
    print("  [5/5] MP3: Dermatology visit (Tanaka)...")
    gen_audio_files()

    # Summary
    print("\n✓ All files generated in sample_files/")
    for subdir in ["pdfs", "txt", "audio"]:
        path = os.path.join(BASE_DIR, subdir)
        files = os.listdir(path)
        print(f"  {subdir}/: {len(files)} files")
        for f in sorted(files):
            size = os.path.getsize(os.path.join(path, f))
            print(f"    {f} ({size:,} bytes)")


if __name__ == "__main__":
    main()
