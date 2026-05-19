# 🧹 Medical Data Cleaning & Normalization

![SQL](https://img.shields.io/badge/SQL-MySQL-4479A1?style=flat&logo=mysql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.x-3776AB?style=flat&logo=python&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-150458?style=flat&logo=pandas&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-success)

A data preprocessing showcase - cleaning **25 messy medical records** with MySQL, then normalizing nested medication data into a proper relational structure with Python.

> 📌 **Dataset:** Custom synthetic data designed to simulate real-world healthcare inconsistencies (mixed date formats, inconsistent units, multi-value fields, missing identifiers).

---

## 🎯 Project Overview

The raw dataset (30 columns × 25 patients) contained realistic issues:
- Dates in **3 different formats** (DD/MM/YYYY, MM/DD/YYYY, DD-Mon-YY)
- Inconsistent capitalization (`M` / `Male` / `male` / `m`)
- Composite fields stored as strings (e.g., blood pressure `130/85`)
- **Multi-value columns** violating 1NF — medications listed as `"Metformin, Lisinopril"` with paired dosages `"500, 10"`
- Mixed dosage units (`mg`, `mcg`, `units`) silently stored together
- Missing names, DOBs, and ambiguous dates

The pipeline outputs a **cleaned `medical_data` table** plus a **normalized `patient_medications` table** linked by foreign key.

---

## 🛠️ Tools & Workflow

```
Original CSV ──► MySQL (cleaning) ──► Python (normalization) ──► Cleaned outputs
                  medical_cleaning.sql    populate_patient_medications.ipynb
```

| Tool | Purpose |
|------|---------|
| **MySQL** | Type-correct cleaning, date parsing, standardization, data quality flagging |
| **Python (pandas, regex, mysql-connector)** | Splitting multi-value fields, regex-based dosage parsing, populating the normalized table |

---

## 📁 Project Structure

```
medical-data-cleaning-project/
├── medical_cleaning.sql                    # MySQL cleaning pipeline
├── populate_patient_medications.ipynb      # Python normalization notebook
└── data/
    ├── medical_data.csv                    # Original messy dataset (25 × 30)
    ├── medical_data_cleaned.csv            # Cleaned output (25 × 36)
    └── patient_medications.csv             # Normalized child table (48 rows)
```

---

## 🔄 Before & After

| Column | Before | After |
|--------|--------|-------|
| First Name | `Ahmed`, `fatima`, `MOHAMMED` | `ahmed`, `fatima`, `mohammed` |
| DOB | `15/03/1985`, `12/6/1990`, `7/22/1988` | `1985-03-15`, *NULL (ambiguous)*, `1988-07-22` |
| gender | `M`, `male`, `F`, `Female`, `m` | `Male`, `Female` |
| blood_pressure | `130/85` (single field) | `systolic_bp: 130`, `diastolic_bp: 85` |
| smoker | `Yes`, `no`, `N`, `YES`, `NO` | `yes`, `no` |
| medications | `"Metformin, Lisinopril"` | Moved to separate table (1 row per medication) |
| dosage_mg | `"500, 10"`, `"40units, 1000"` | Parsed into numeric value + unit |
| Department | `Endocrinology`, `cardiology` | `endocrinology`, `cardiology` |
| *(new)* data_quality_flag | — | `"Missing Name \| Ambiguous DOB"` |

---

## 🌟 Technical Highlights

### 1. 🗓️ Ambiguous Date Detection via Cross-Referencing

The dataset had dates like `04/05/2024` — is that **April 5** or **May 4**? Without context, it's impossible to tell. So instead of guessing, the script uses **internal logical constraints** to resolve them: an admission date must come *before* the discharge date, which must come *before* the follow-up date.

For each ambiguous date, the script tries both interpretations (`MM/DD` and `DD/MM`) and picks the one that satisfies the chronological constraint:

```sql
-- Try MM/DD/YYYY — does it fall before the discharge date?
UPDATE medical_data
SET admission_date_clean = STR_TO_DATE(admission_date, '%m/%d/%Y')
WHERE admission_date_clean IS NULL
AND STR_TO_DATE(admission_date, '%m/%d/%Y') < discharge_date_clean
AND STR_TO_DATE(admission_date, '%d/%m/%Y') >= discharge_date_clean;
```

Dates that **can't be resolved** even with cross-referencing are left NULL and flagged, never silently guessed.

### 2. 🚩 Automated Data Quality Flagging

Every row gets a `data_quality_flag` summarizing its issues, built dynamically with `CONCAT_WS` + `COALESCE`:

```sql
UPDATE medical_data
SET data_quality_flag = COALESCE(
    NULLIF(CONCAT_WS(' | ',
        CASE WHEN first_name IS NULL OR last_name IS NULL THEN 'Missing Name' END,
        CASE WHEN dob_clean IS NULL AND dob IS NOT NULL THEN 'Ambiguous DOB' END,
        CASE WHEN dosage_mg REGEXP 'mcg|units' THEN 'Inconsistent Dosage Unit' END
        -- ...more conditions
    ), ''),
    'No Action Required'
);
```

**Result:** 8 of 25 rows passed clean; 17 were flagged with specific, actionable issues like `"Missing Name | Ambiguous DOB | Ambiguous Admission Date"`.

### 3. 🗂️ Database Normalization (1NF Compliance)

The original `medications` and `dosage_mg` columns stored comma-separated values, violating **first normal form** and making queries like *"average metformin dosage"* impossible without string parsing.

Solution: extract into a separate `patient_medications` table linked by foreign key, with one row per medication per patient:

```
medication_id | patient_id | medication | dosage | dosage_unit
1             | P001       | metformin  | 500.00 | mg
2             | P001       | lisinopril | 10.00  | mg
```

**Result:** 25 patient rows → 48 medication rows.

### 4. 🐍 SQL + Python Integration

Some transformations are easier in Python  particularly regex-based dosage parsing. Entries like `"500"`, `"40units"`, `"100mcg"`, and `"N/A"` all needed different treatment:

```python
def parse_dosage(dosage_raw):
    if dosage_raw == 'N/A':
        return None, 'Dosage Not Applicable'
    match = re.match(r'([\d.]+)([a-zA-Z]*)', str(dosage_raw).strip())
    if match:
        value = match.group(1)
        unit = match.group(2) if match.group(2) else 'mg'  # default to mg
        return float(value), unit
    return None, None
```

The notebook uses **parameterized queries** (`%s` placeholders) to safely insert into MySQL.

### 5. 🩸 Composite Field Splitting (brief)

`blood_pressure` was stored as `130/85` - unusable for analysis. Split into `systolic_bp` and `diastolic_bp` integer columns using `SUBSTRING_INDEX`.

---

## 🩺 Clinical Notes — Why Some Things Were Left Alone

I have a clinical background, which shaped a few deliberate decisions:

- **No imputation of patient identifiers.** Missing names, DOBs, and blood types were *flagged*, not filled in. Fabricated identifying data can cause misidentification or wrong-patient errors - a flag prompts human follow-up; an imputed value silently lies.
- **Conflicting notes are flagged, not auto-resolved.** Clinical notes carry context that aggregation can't preserve.
- **Ambiguous dates are left NULL.** Better to admit uncertainty than to guess.
- **Dosage units preserved separately.** `mg`, `mcg`, and `units` are clinically distinct, forcing them into one scale can be life-threatening (e.g., insulin units vs. mg).

---

## ⚙️ Workflow Order

1. Create the database and import the raw CSV into MySQL Workbench as `medical_data`
2. Run `medical_cleaning.sql` top-to-bottom - cleans, parses dates, flags quality issues, creates the empty `patient_medications` table
3. Run `populate_patient_medications.ipynb` - parses comma-separated medication fields and populates the new table
4. *(Optional)* run the commented-out `DROP COLUMN` statements at the end of the SQL script to remove the now-redundant columns

---

## 🔮 Future Work

### Further normalization
- **Diagnoses table.** A patient can have multiple diagnoses - currently stored as one per row (a 1NF violation, same as medications). A `patient_diagnoses` table linked to a `diagnoses` lookup (ICD-10 codes with names and categories) would support multiple diagnoses per patient.
- **Insurance table.** Moving `insurance_provider`, `insurance_id`, `payment_status`, and `total_charges` into a separate `patient_insurance` table would cleanly separate clinical from financial data, a common architectural split in hospital information systems.
- **Reference (lookup) tables** for `department`, `ward`, and `blood_type`, enforcing valid values via foreign key constraints to prevent typos at insertion.

### Additional data quality checks
- **Logical consistency validation** - cross-field rules like *discharge before admission*, *follow-up before discharge*, or *age vs. DOB mismatch*.
- **Out-of-range vital signs.** Heart rate, temperature, blood pressure, weight, and height all have clinically plausible ranges - values outside them likely indicate data entry errors.
- **PHI / cross-patient references in free text.** The `notes` field may contain other patient IDs, family names, or addresses. privacy risks worth flagging (or detecting via NER in a more advanced version).
- **Format validation** via regex on structured identifiers like `insurance_id`.

### Automation & traceability
- **Trigger-based flagging.** A MySQL trigger on INSERT/UPDATE would recompute the data quality flag automatically as new rows arrive.
- **Audit columns** (`created_at`, `updated_at`, `created_by`, `updated_by`) — essential for compliance in healthcare contexts (HIPAA, GDPR).
- **Slowly Changing Dimensions (SCD).** Tracking history with `valid_from` / `valid_to` columns preserves the timeline of changing attributes like insurance.

---

## 📚 Lessons Learned

- **Pipeline ordering matters.** Quality flagging originally ran early in the script but referenced columns created later. Reorganizing it to run after all dependencies made the pipeline reproducible from a fresh database.
- **Honest NULLs beat clever guesses** - especially in healthcare, where a wrong value costs more than a missing one.

---

## 👩‍💻 Author

**Tesneem Fnais** - April 2026
