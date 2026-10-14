# Hospital Data Analysis Project

A SQL-based analysis of a synthetic hospital database made up of 12 linked tables. The project answers 35 business questions about patients, appointments, admissions, clinical activity, staffing, billing, insurance and data quality.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Dataset Overview](#dataset-overview)
3. [Table Relationships](#table-relationships)
4. [Business Questions](#business-questions)
5. [SQL Coverage](#sql-coverage)
6. [Getting Started](#getting-started)
7. [Data Quality Notes](#data-quality-notes)
8. [Known Issues and Next Steps](#known-issues-and-next-steps)
9. [Tech Stack](#tech-stack)

---

## Project Structure

```
Hospital Data Analysis Project/
├── Hospital Data Analysis/              # Source data (12 CSV files)
│   ├── patients.csv
│   ├── doctors.csv
│   ├── departments.csv
│   ├── staff.csv
│   ├── appointments.csv
│   ├── admissions.csv
│   ├── diagnoses.csv
│   ├── lab_tests.csv
│   ├── medications.csv
│   ├── prescriptions.csv
│   ├── billing.csv
│   └── insurance.csv
├── Hospital Data Analysis SQL File/
│   └── health care Analysis.sql         # PostgreSQL queries
├── Questions/
│   └── hospital_analysis_questions.pdf  # The 35 analysis questions
└── README.md
```

---

## Dataset Overview

| Table | Rows | Description | Key columns |
|---|---:|---|---|
| `patients` | 825 | Patient demographics and registration | `patient_id`, `gender`, `date_of_birth`, `city`, `insurance_id`, `registration_date` |
| `doctors` | 60 | Doctor profiles | `doctor_id`, `specialty`, `department_id`, `years_experience`, `consultation_fee` |
| `departments` | 14 | Hospital departments | `department_id`, `department_name`, `operating_cost_monthly`, `num_beds` |
| `staff` | 150 | Non-doctor staff | `staff_id`, `role`, `department_id`, `salary_monthly` |
| `appointments` | 3,000 | Outpatient appointments (2023–2025) | `appointment_id`, `status`, `cancellation_reason`, `satisfaction_score` |
| `admissions` | 900 | Inpatient admissions (2023–2025) | `admission_id`, `status`, `room_type`, `readmission_flag`, `discharge_date` |
| `diagnoses` | 1,133 | Diagnoses recorded per admission | `diagnosis_name`, `severity`, `admission_id` |
| `lab_tests` | 1,370 | Lab tests ordered per admission | `test_name`, `result`, `cost` |
| `medications` | 15 | Medication catalogue | `medication_name`, `form`, `unit_price` |
| `prescriptions` | 1,754 | Medications prescribed per admission | `medication_id`, `dosage`, `duration_days` |
| `billing` | 3,006 | Bills for appointments and admissions | `amount`, `payment_status`, `bill_date`, `payment_date`, `insurance_covered` |
| `insurance` | 400 | Insurance policies | `provider_name`, `coverage_amount`, `policy_start_date`, `policy_end_date` |

**Categorical values worth knowing**

- Appointment status: `Completed`, `Cancelled`, `No-Show`, `Scheduled`
- Cancellation reasons: `Patient request`, `Doctor unavailable`, `Emergency`
- Admission status: `Discharged`, `Admitted`, `Transferred`
- Room type: `General`, `ICU`, `Semi-Private`, `Private`
- Payment status: `Paid`, `Unpaid`, `Partially Paid`
- Lab result: `Normal`, `Abnormal`, `Borderline`
- Insurers: National Insurance, Star Health, Care Health, United India, Max Bupa, HDFC Ergo, ICICI Lombard

---

## Table Relationships

```
departments ──< doctors ──< appointments >── patients >── insurance
     │                          │               │
     ├──< staff                 │               ├──< admissions ──< diagnoses
     │                          │               │         │
     ├──< admissions            │               │         ├──< lab_tests
     └──< appointments          │               │         └──< prescriptions >── medications
                                │               │
                                └─────< billing >┘   (billing links to a patient and to
                                                      an appointment OR an admission)
```

| Foreign key | References |
|---|---|
| `patients.insurance_id` | `insurance.insurance_id` |
| `doctors.department_id`, `staff.department_id` | `departments.department_id` |
| `appointments.patient_id / doctor_id / department_id` | `patients`, `doctors`, `departments` |
| `admissions.patient_id / doctor_id / department_id` | `patients`, `doctors`, `departments` |
| `diagnoses`, `lab_tests`, `prescriptions` → `admission_id`, `patient_id` | `admissions`, `patients` |
| `prescriptions.medication_id` | `medications.medication_id` |
| `billing.patient_id / appointment_id / admission_id` | `patients`, `appointments`, `admissions` |

A bill points to either an appointment or an admission, so one of those two columns is always empty.

---

## Business Questions

The full list is in `Questions/hospital_analysis_questions.pdf`.

| Area | Questions | Topics |
|---|---|---|
| Patients and Demographics | 1–4 | Registration growth, age and gender mix, top cities, insurance coverage |
| Appointments | 5–9 | Completion, cancellation and no-show rates, busiest slots, satisfaction by doctor and department |
| Admissions | 10–14 | Length of stay, readmissions, status breakdown, missing discharge dates, bed occupancy |
| Diagnoses and Clinical | 15–19 | Top diagnoses, readmission links, lab tests and abnormal results, medications, prescription duration |
| Doctors and Staff | 20–23 | Experience vs. fee and satisfaction, specialties, salary cost vs. operating cost |
| Billing and Finance | 24–29 | Revenue trends, payment status, bill sizes, insurance vs. out-of-pocket, payment delay, unpaid balances |
| Insurance | 30–32 | Insurer reach, expired and expiring policies, insured vs. uninsured behavior |
| Data Quality | 33–35 | Missing values, duplicates and orphan keys, inconsistent dates |

---

## SQL Coverage

All queries are in `Hospital Data Analysis SQL File/health care Analysis.sql` and are written for **PostgreSQL**. They use `EXTRACT`, `AGE`, `::` casts and `FILTER`.

| Status | Questions |
|---|---|
| Written | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 29B, 30, 31A, 31B, 32 |
| Needs fixing | 29A (patients with the highest unpaid balances; the query header is cut off) |
| Not yet written | 17–28, 33–35 |

**Partial answers**

- **Q4:** the insured percentage is covered. The most common providers are covered by Q30.
- **Q8:** satisfaction is calculated by doctor only, not by department.
- **Q11:** readmission rate by department is in Q11, and by diagnosis in Q16.

---

## Getting Started

### 1. Create the database

```sql
CREATE DATABASE hospital_analysis;
```

### 2. Create the tables and load the CSVs

Create the 12 tables to match the CSV headers, then load each file. For example:

```sql
\copy patients FROM 'Hospital Data Analysis/patients.csv' WITH (FORMAT csv, HEADER true);
```

Repeat for each CSV. Load parent tables first (`insurance`, `departments`, `patients`, `doctors`, `medications`), then the rest.

### 3. Use these column types

The queries depend on specific types:

| Column | Type | Why |
|---|---|---|
| `admissions.readmission_flag` | `BOOLEAN` | Queries use `IS TRUE`. PostgreSQL's `COPY` converts `Yes`/`No` automatically. |
| `billing.insurance_covered` | `BOOLEAN` | Source values are `True`/`False`. |
| All `*_date` columns | `DATE` | Date arithmetic and `AGE()` need real dates. |
| `appointments.appointment_time` | `TIME` or `TEXT` | Source values look like `17:00`. |
| `amount`, `coverage_amount`, `salary_monthly`, `cost` | `NUMERIC` | Avoids rounding errors in sums and averages. |

### 4. Run the analysis

```bash
psql -d hospital_analysis -f "Hospital Data Analysis SQL File/health care Analysis.sql"
```

---

## Data Quality Notes

These were found while profiling the CSVs and affect how some answers should be read.

- **Duplicate departments.** `D13` is `"Cardiology "` (trailing space) and `D14` is `"ENT Dept"`. They appear to duplicate `D01` Cardiology and `D11` ENT, which splits department-level results. Clean the names or map the IDs before grouping.
- **Missing discharge dates.** 137 admissions have no discharge date. All of them are `Admitted` (93) or `Transferred` (44), and none are `Discharged`. This is relevant to Q13 and Q14.
- **Missing cancellation reasons.** 455 appointments are cancelled, but only 337 have a reason recorded.
- **Blank lab results.** 144 lab tests have no result, which affects the abnormal-share calculation in Q17.
- **Sparse satisfaction scores.** 1,356 of 3,000 appointments have no score. Averages cover rated appointments only.
- **Uninsured patients.** 275 of 825 patients have no `insurance_id`.
- **Possible duplicate patients.** 25 patient records share a first name, last name and date of birth with another record. They have different `patient_id` values.
- **Clean links.** Every `appointment_id` and `admission_id` in `billing` matches a real record, and there are no duplicate patient IDs. No admission has a discharge date before its admission date.
- **Policy dates depend on the run date.** Q31 compares policy end dates with `CURRENT_DATE`, so its results change over time.

---

## Known Issues and Next Steps

1. **Repair Q29A.** The query is missing its comment header and `SELECT` line, so it won't run as written. It needs `SELECT` before `p.patient_id`.
2. **Write Q17–28 and Q33–35.** These cover clinical tests and medications, doctors and staff, billing and finance, and data quality checks.
3. **Extend Q8** to include satisfaction by department.
4. **Add a schema script** (`CREATE TABLE` statements) so the database can be built in one step.
5. **Resolve the duplicate departments** before running any department-level analysis.
6. **Add a results summary** with the key findings once all queries are complete.

---

## Tech Stack

- **Database:** PostgreSQL
- **Language:** SQL (CTEs, window functions, `FILTER` aggregates, date arithmetic)
- **Data:** 12 CSV files, about 12,600 records in total
