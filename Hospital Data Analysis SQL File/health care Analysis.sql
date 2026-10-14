-- 1. Total patients and registration growth by year
SELECT COUNT(*) AS total_patients
FROM patients;

SELECT
    EXTRACT(YEAR FROM registration_date)::INT AS registration_year,
    COUNT(*) AS total_registered
FROM patients
WHERE registration_date IS NOT NULL
GROUP BY EXTRACT(YEAR FROM registration_date)
ORDER BY registration_year;


-- 2. Age and gender distribution
SELECT
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth))::INT AS age,
    gender,
    COUNT(*) AS patient_count
FROM patients
WHERE date_of_birth IS NOT NULL
GROUP BY age, gender
ORDER BY age, gender;


-- 3. Cities with the most patients
SELECT city, COUNT(*) AS total_patients
FROM patients
GROUP BY city
ORDER BY total_patients DESC;


-- 4. Insurance coverage percentage
SELECT
    COUNT(*) AS total_patients,
    COUNT(*) FILTER (WHERE insurance_id IS NOT NULL) AS insured,
    COUNT(*) FILTER (WHERE insurance_id IS NULL) AS uninsured,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE insurance_id IS NOT NULL)
        / NULLIF(COUNT(*), 0),
        2
    ) AS insured_percentage
FROM patients;


-- 5. Appointment status rates
SELECT
    status,
    COUNT(*) AS total,
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS percentage
FROM appointments
GROUP BY status;


-- 6. Cancellation reasons
SELECT
    cancellation_reason,
    COUNT(*) AS total_cancellations
FROM appointments
WHERE LOWER(status) = 'cancelled'
GROUP BY cancellation_reason
ORDER BY total_cancellations DESC;


-- 7. Busiest days and time slots
-- Assumes appointment_date and appointment_time columns exist.
SELECT
    TRIM(TO_CHAR(appointment_date, 'Day')) AS weekday,
    appointment_time,
    COUNT(*) AS total_appointments
FROM appointments
WHERE appointment_date IS NOT NULL
GROUP BY weekday, appointment_time
ORDER BY total_appointments DESC;


-- 8. Average satisfaction by doctor
SELECT
    doc.doctor_id,
    doc.doctor_name,
    ROUND(AVG(a.satisfaction_score)::NUMERIC, 2) AS avg_satisfaction
FROM doctors doc
LEFT JOIN appointments a ON a.doctor_id = doc.doctor_id
GROUP BY doc.doctor_id, doc.doctor_name
ORDER BY avg_satisfaction DESC NULLS LAST;


-- 9. Doctor cancellation rates
SELECT
    doc.doctor_id,
    doc.doctor_name,
    COUNT(a.appointment_id) AS total_appointments,
    COUNT(*) FILTER (WHERE LOWER(a.status) = 'cancelled') AS cancelled,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE LOWER(a.status) = 'cancelled')
        / NULLIF(COUNT(a.appointment_id), 0),
        2
    ) AS cancellation_rate
FROM doctors doc
LEFT JOIN appointments a ON a.doctor_id = doc.doctor_id
GROUP BY doc.doctor_id, doc.doctor_name
ORDER BY cancellation_rate DESC NULLS LAST;


-- 10. Average length of stay by department and room type
SELECT
    dep.department_name,
    adm.room_type,
    ROUND(
        AVG(adm.discharge_date::DATE - adm.admission_date::DATE)::NUMERIC,
        2
    ) AS avg_stay_days
FROM admissions adm
LEFT JOIN departments dep ON dep.department_id = adm.department_id
WHERE adm.admission_date IS NOT NULL
  AND adm.discharge_date IS NOT NULL
  AND adm.discharge_date >= adm.admission_date
GROUP BY dep.department_name, adm.room_type;


-- 11. Readmission rate by department
SELECT
    dep.department_name,
    COUNT(*) AS total_admissions,
    COUNT(*) FILTER (WHERE adm.readmission_flag IS TRUE) AS readmissions,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE adm.readmission_flag IS TRUE)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate
FROM admissions adm
JOIN departments dep ON dep.department_id = adm.department_id
GROUP BY dep.department_name;


-- 12. Admission status breakdown
SELECT status, COUNT(*) AS total
FROM admissions
GROUP BY status;


-- 13. Missing discharge dates
SELECT
    status,
    COUNT(*) AS missing_discharge_dates
FROM admissions
WHERE discharge_date IS NULL
GROUP BY status
ORDER BY missing_discharge_dates DESC;


-- 14. Estimated bed occupancy
-- Assumes num_beds is department capacity.
SELECT
    dep.department_name,
    dep.num_beds,
    COUNT(adm.admission_id) FILTER (
        WHERE adm.discharge_date IS NULL
          AND LOWER(COALESCE(adm.status, '')) NOT IN ('discharged', 'cancelled')
    ) AS occupied_beds_estimate,
    ROUND(
        100.0 * COUNT(adm.admission_id) FILTER (
            WHERE adm.discharge_date IS NULL
              AND LOWER(COALESCE(adm.status, '')) NOT IN ('discharged', 'cancelled')
        ) / NULLIF(dep.num_beds, 0),
        2
    ) AS occupancy_percentage
FROM departments dep
LEFT JOIN admissions adm ON adm.department_id = dep.department_id
GROUP BY dep.department_name, dep.num_beds;


-- 15. Top 10 diagnoses by frequency and severity
SELECT
    diagnosis_name,
    severity,
    COUNT(*) AS total
FROM diagnoses
WHERE diagnosis_name IS NOT NULL
GROUP BY diagnosis_name, severity
ORDER BY total DESC
LIMIT 10;


-- 16. Diagnoses linked to readmissions and long stays
-- Assumes diagnoses.admission_id exists.
SELECT
    dia.diagnosis_name,
    COUNT(DISTINCT adm.admission_id) AS total_admissions,
    COUNT(DISTINCT adm.admission_id)
        FILTER (WHERE adm.readmission_flag IS TRUE) AS readmissions,
    ROUND(
        AVG(adm.discharge_date::DATE - adm.admission_date::DATE)::NUMERIC,
        2
    ) AS avg_stay_days
FROM diagnoses dia
JOIN admissions adm ON adm.admission_id = dia.admission_id
GROUP BY dia.diagnosis_name
ORDER BY readmissions DESC, avg_stay_days DESC NULLS LAST;



    p.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    COUNT(b.billing_id) AS outstanding_bill_count,
    ROUND(SUM(b.amount), 2) AS outstanding_bill_amount
FROM billing b
JOIN patients p ON b.patient_id = p.patient_id
WHERE LOWER(COALESCE(b.payment_status, '')) IN
    ('unpaid', 'partially paid', 'pending', 'overdue')
GROUP BY p.patient_id, p.first_name, p.last_name
ORDER BY outstanding_bill_amount DESC
LIMIT 20;


-- 29B. Departments with highest unpaid/partially paid bill totals
WITH department_bills AS (
    SELECT b.billing_id, b.amount, a.department_id
    FROM billing b
    JOIN appointments a ON b.appointment_id = a.appointment_id
    WHERE LOWER(COALESCE(b.payment_status, '')) IN
        ('unpaid', 'partially paid', 'pending', 'overdue')

    UNION ALL

    SELECT b.billing_id, b.amount, ad.department_id
    FROM billing b
    JOIN admissions ad ON b.admission_id = ad.admission_id
    WHERE LOWER(COALESCE(b.payment_status, '')) IN
        ('unpaid', 'partially paid', 'pending', 'overdue')
)
SELECT
    dep.department_name,
    COUNT(db.billing_id) AS outstanding_bill_count,
    ROUND(SUM(db.amount), 2) AS outstanding_bill_amount
FROM department_bills db
LEFT JOIN departments dep ON db.department_id = dep.department_id
GROUP BY dep.department_name
ORDER BY outstanding_bill_amount DESC;



-- 30. Insurers with most patients and highest policy coverage
SELECT
    i.provider_name,
    COUNT(DISTINCT i.insurance_id) AS total_policies,
    COUNT(DISTINCT p.patient_id) AS total_patients,
    ROUND(SUM(i.coverage_amount), 2) AS total_policy_coverage,
    ROUND(AVG(i.coverage_amount), 2) AS average_coverage_per_policy
FROM insurance i
LEFT JOIN patients p ON p.insurance_id = i.insurance_id
GROUP BY i.provider_name
ORDER BY total_patients DESC, total_policy_coverage DESC;


-- 31A. Expired, expiring soon, and other policies
SELECT
    insurance_id,
    provider_name,
    policy_number,
    coverage_amount,
    policy_start_date,
    policy_end_date,
    CASE
        WHEN policy_end_date < CURRENT_DATE THEN 'Expired'
        WHEN policy_end_date <= CURRENT_DATE + 30 THEN 'Expiring Soon'
        ELSE 'Active / Not Expiring Soon'
    END AS policy_status,
    policy_end_date - CURRENT_DATE AS days_until_expiry
FROM insurance
ORDER BY policy_end_date;


-- 31B. Policy counts and coverage by expiration status
SELECT
    CASE
        WHEN policy_end_date < CURRENT_DATE THEN 'Expired'
        WHEN policy_end_date <= CURRENT_DATE + 30 THEN 'Expiring Soon'
        ELSE 'Active / Not Expiring Soon'
    END AS policy_status,
    COUNT(*) AS total_policies,
    ROUND(SUM(coverage_amount), 2) AS total_coverage_amount
FROM insurance
GROUP BY
    CASE
        WHEN policy_end_date < CURRENT_DATE THEN 'Expired'
        WHEN policy_end_date <= CURRENT_DATE + 30 THEN 'Expiring Soon'
        ELSE 'Active / Not Expiring Soon'
    END
ORDER BY total_policies DESC;


-- 32. Compare bills and admissions for patients with/without insurance IDs
WITH patient_billing AS (
    SELECT
        patient_id,
        COUNT(*) AS total_bills,
        AVG(amount) AS average_bill_amount,
        SUM(amount) AS total_billed_amount
    FROM billing
    GROUP BY patient_id
),
patient_admissions AS (
    SELECT patient_id, COUNT(*) AS total_admissions
    FROM admissions
    GROUP BY patient_id
)
SELECT
    CASE
        WHEN p.insurance_id IS NOT NULL THEN 'Insurance ID Present'
        ELSE 'No Insurance ID'
    END AS insurance_group,
    COUNT(DISTINCT p.patient_id) AS total_patients,
    ROUND(AVG(pb.average_bill_amount), 2) AS average_bill_per_patient,
    ROUND(AVG(pb.total_billed_amount), 2) AS average_total_billed_per_patient,
    ROUND(AVG(COALESCE(pa.total_admissions, 0)), 2)
        AS average_admissions_per_patient,
    SUM(COALESCE(pa.total_admissions, 0)) AS total_admissions
FROM patients p
LEFT JOIN patient_billing pb ON p.patient_id = pb.patient_id
LEFT JOIN patient_admissions pa ON p.patient_id = pa.patient_id
GROUP BY
    CASE
        WHEN p.insurance_id IS NOT NULL THEN 'Insurance ID Present'
        ELSE 'No Insurance ID'
    END
ORDER BY average_bill_per_patient DESC NULLS LAST;
