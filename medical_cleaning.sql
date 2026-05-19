CREATE DATABASE medical_cleaning;
USE medical_cleaning;

# Project: Medical Data Cleaning
# Dataset: synthetic data
# Objective: enhance my data cleaning and preprocessing skills 
# Author: Tesneem Fnais
# Date: 15 April 2026

---------------------------------------------------

# dataset overview

Select * FROM medical_data;

DESCRIBE medical_data;

SELECT 
COUNT(*) AS total_rows
FROM medical_data;
# 25 rows

SELECT 
COUNT(*) AS total_columns
FROM INFORMATION_SCHEMA.columns
WHERE table_name = 'medical_data'
AND table_schema = 'medical_cleaning';
# 30 columns


ALTER TABLE medical_data RENAME COLUMN `First Name` TO first_name;
ALTER TABLE medical_data RENAME COLUMN `AGE` TO age;
ALTER TABLE medical_data RENAME COLUMN `DOB` TO dob;
ALTER TABLE medical_data RENAME COLUMN `Blood Type` TO blood_type;
ALTER TABLE medical_data RENAME COLUMN `Department` TO department;

### NOTES:
# transform data according to their types accurately ,check how to clean dates, 2 types of appendicitis, lower case all words,
# devide blood pressure column into 2 (systolic and diastolic), unify smoker and gender and payement_status,
# work on medications and dosage_mg

SELECT
MIN(age),
ROUND(AVG(age),0),
MAX(age)
FROM medical_data;

SELECT
DISTINCT blood_type
FROM medical_data
ORDER BY blood_type;

SELECT
insurance_provider
FROM medical_data
GROUP BY insurance_provider;

-------------------------------------------------------

# DATA CLEANING

# first_name and last_name
ALTER TABLE medical_data
# ADD COLUMN name_flag VARCHAR(50) DEFAULT 'No Action Required' AFTER last_name; ## CHANGED
ADD COLUMN data_quality_flag VARCHAR(100) DEFAULT 'No Action Required' AFTER notes;

SET SQL_SAFE_UPDATES = 0;

UPDATE medical_data
SET first_name = LOWER(first_name),
last_name = LOWER(last_name);

# NOTE: data_quality_flag UPDATE moved to end of script
# (it references _clean columns that don't exist yet at this point)

SELECT * FROM medical_data;

################ SET SQL_SAFE_UPDATES = 1;

# fixing dob (format should be YYYY-MM-DD)
SELECT patient_id, dob
FROM medical_data
WHERE CAST(SUBSTRING_INDEX(dob, '/', 1) AS UNSIGNED) > 12;

SELECT patient_id, dob
FROM medical_data
WHERE CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(dob, '/', 2), '/', -1) AS UNSIGNED) >12;

ALTER TABLE medical_data
ADD COLUMN dob_clean DATE AFTER dob;

UPDATE medical_data
SET dob_clean = STR_TO_DATE(dob, '%d/%m/%Y')
WHERE dob IS NOT NULL AND dob!=''
AND CAST(SUBSTRING_INDEX(dob, '/', 1) AS UNSIGNED) > 12;

UPDATE medical_data
SET dob_clean = STR_TO_DATE(dob, '%m/%d/%Y')
WHERE dob IS NOT NULL AND dob !=''
AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(dob, '/', 2), '/', -1) AS UNSIGNED) >12;

UPDATE medical_data
SET dob_clean = STR_TO_DATE(dob, '%d/%m/%Y')
WHERE dob IS NOT NULL AND dob !='' AND dob_clean IS NULL
AND CAST(SUBSTRING_INDEX(dob, '/', 1) AS UNSIGNED) = 
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(dob, '/', 2), '/', -1) AS UNSIGNED);

# gender column
Update medical_data
SET gender = CASE
WHEN gender = 'M' OR gender = 'male' THEN 'Male'
WHEN gender = 'F' OR gender = 'female' THEN 'Female'
ELSE gender
END;

# admission_date and discharge_date column
ALTER TABLE medical_data
ADD COLUMN admission_date_clean DATE AFTER admission_date;

ALTER TABLE medical_data
ADD COLUMN discharge_date_clean DATE AFTER discharge_date;

SELECT * FROM medical_data;

# clean the DD-Mon-YY in ADMISSION
UPDATE medical_data
SET admission_date_clean = str_to_date(admission_date, '%d-%b-%y')
WHERE admission_date LIKE '%-%'
AND admission_date IS NOT NULL
AND admission_date !='';


# clean the DD/MM/YYYY > 12 in ADMISSION
UPDATE medical_data
SET admission_date_clean = str_to_date(admission_date, '%d/%m/%Y')
WHERE admission_date IS NOT NULL
AND admission_date !=''
AND admission_date NOT LIKE '%-%'
AND CAST(SUBSTRING_INDEX(admission_date, '/', 1) AS UNSIGNED) >12;

# clean the MM/DD/YYYY > 12 in ADMISSION
UPDATE medical_data
SET admission_date_clean = str_to_date(admission_date, '%m/%d/%Y')
WHERE admission_date IS NOT NULL
AND admission_date !=''
AND admission_date NOT LIKE '%-%'
AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(admission_date, '/', 2), '/', -1) AS UNSIGNED) >12;

# clean the DD/MM/YYYY > 12 in DISCHARGE
UPDATE medical_data
SET discharge_date_clean = str_to_date(discharge_date, '%d/%m/%Y')
WHERE discharge_date IS NOT NULL
AND discharge_date !=''
AND CAST(SUBSTRING_INDEX(discharge_date, '/', 1) AS UNSIGNED) >12;

# clean the MM/DD/YYYY > 12 in DISCHARGE
UPDATE medical_data
SET discharge_date_clean = str_to_date(discharge_date, '%m/%d/%Y')
WHERE discharge_date IS NOT NULL
AND discharge_date !=''
AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(discharge_date, '/', 2), '/', -1) AS UNSIGNED) >12;

# CROSS-REFERENCING (fixing ADMISSION CLEAN)
SELECT 
patient_id, 
admission_date, 
discharge_date_clean,
str_to_date(admission_date, '%m/%d/%Y') AS adm_md,
str_to_date(admission_date, '%d/%m/%Y') AS adm_dm
FROM medical_data
WHERE admission_date_clean IS NULL
AND admission_date IS NOT NULL
AND admission_date !=''
AND admission_date NOT LIKE '%-%'
AND discharge_date_clean IS NOT NULL
     -- Only MM/DD is less than discharge
AND (str_to_date(admission_date, '%m/%d/%Y') < discharge_date_clean
     AND str_to_date(admission_date, '%d/%m/%Y') >= discharge_date_clean)
	-- Only DD/MM is less than discharge
OR (str_to_date(admission_date, '%d/%m/%Y') < discharge_date_clean
	AND str_to_date(admission_date, '%m/%d/%Y') >= discharge_date_clean);

SELECT * FROM medical_data;

-- MM/DD wins
UPDATE medical_data
SET admission_date_clean = STR_TO_DATE(admission_date, '%m/%d/%Y')
WHERE admission_date_clean IS NULL
AND admission_date IS NOT NULL
AND admission_date != ''
AND admission_date NOT LIKE '%-%'
AND discharge_date_clean IS NOT NULL
AND STR_TO_DATE(admission_date, '%m/%d/%Y') < discharge_date_clean
AND STR_TO_DATE(admission_date, '%d/%m/%Y') >= discharge_date_clean;

-- DD/MM wins
UPDATE medical_data
SET admission_date_clean = STR_TO_DATE(admission_date, '%d/%m/%Y')
WHERE admission_date_clean IS NULL
AND admission_date IS NOT NULL
AND admission_date != ''
AND admission_date NOT LIKE '%-%'
AND discharge_date_clean IS NOT NULL
AND STR_TO_DATE(admission_date, '%d/%m/%Y') < discharge_date_clean
AND STR_TO_DATE(admission_date, '%m/%d/%Y') >= discharge_date_clean;


# CROSS-REFERENCING (fixing DISCHARGE CLEAN)
SELECT 
    patient_id,
    discharge_date,
    admission_date_clean,
    STR_TO_DATE(discharge_date, '%m/%d/%Y') AS dis_as_mmdd,
    STR_TO_DATE(discharge_date, '%d/%m/%Y') AS dis_as_ddmm
FROM medical_data
WHERE discharge_date_clean IS NULL
AND discharge_date IS NOT NULL
AND discharge_date != ''
AND discharge_date NOT LIKE '%-%'
AND admission_date_clean IS NOT NULL
AND (
    (STR_TO_DATE(discharge_date, '%m/%d/%Y') > admission_date_clean
    AND STR_TO_DATE(discharge_date, '%d/%m/%Y') <= admission_date_clean)
    OR
    (STR_TO_DATE(discharge_date, '%d/%m/%Y') > admission_date_clean
    AND STR_TO_DATE(discharge_date, '%m/%d/%Y') <= admission_date_clean));

-- DD/MM wins
UPDATE medical_data
SET discharge_date_clean = STR_TO_DATE(discharge_date, '%d/%m/%Y')
WHERE discharge_date_clean IS NULL
AND discharge_date IS NOT NULL
AND discharge_date != ''
AND discharge_date NOT LIKE '%-%'
AND admission_date_clean IS NOT NULL
AND STR_TO_DATE(discharge_date, '%d/%m/%Y') > admission_date_clean
AND STR_TO_DATE(discharge_date, '%m/%d/%Y') <= admission_date_clean;

-- MM/DD wins
UPDATE medical_data
SET discharge_date_clean = STR_TO_DATE(discharge_date, '%m/%d/%Y')
WHERE discharge_date_clean IS NULL
AND discharge_date IS NOT NULL
AND discharge_date != ''
AND discharge_date NOT LIKE '%-%'
AND admission_date_clean IS NOT NULL
AND STR_TO_DATE(discharge_date, '%m/%d/%Y') > admission_date_clean
AND STR_TO_DATE(discharge_date, '%d/%m/%Y') <= admission_date_clean;

update medical_data
set doctor_name = lower(doctor_name);

update medical_data
set department = lower(department);

update medical_data
set ward = lower(ward);


select * from medical_data;

# blood pressure
ALTER TABLE medical_data
add column systolic_bp int after blood_pressure;

alter table medical_data
add column diastolic_bp int after systolic_bp;

update medical_data
set systolic_bp = substring_index(blood_pressure, '/', 1) ;

update medical_data
set diastolic_bp = substring_index(blood_pressure, '/', -1);

select 
min(temperature),
round(avg(temperature), 1),
max(temperature)
from medical_data;

update medical_data
set smoker = case
when smoker ='Yes' or smoker = 'YES' then 'yes'
when smoker = 'N' or smoker = 'No' or smoker = 'NO' then 'no'
else smoker
end;

select
distinct allergies 
from medical_data
order by allergies;

update medical_data
set allergies = lower(allergies);

select * from medical_data;

update medical_data
set medications = lower(medications);

update medical_data 
set allergies = 'unknown'
where allergies is null or allergies ='' ; 

update medical_data
set insurance_provider = lower(insurance_provider);

select
insurance_provider,
substring_index(insurance_id, '-', 1) as suffix
from medical_data
group by insurance_provider, suffix;

update medical_data
set payment_status = lower(payment_status);

select * from medical_data;

select 
follow_up_date
from medical_data;

alter table medical_data
add column followup_date_clean date after follow_up_date;

update medical_data
set followup_date_clean = str_to_date(follow_up_date, '%d/%m/%Y')
where follow_up_date is not null and follow_up_date !='' and follow_up_date not like 'N/A'
and cast(substring_index(follow_up_date, '/', 1) as unsigned) > 12;

update medical_data
set followup_date_clean = str_to_date(follow_up_date, '%m/%d/%Y')
where follow_up_date is not null and follow_up_date !='' and follow_up_date not like 'N/A'
and cast(substring_index(substring_index(follow_up_date, '/', 2), '/', -1) as unsigned) > 12;

# N/A as no follow-up required
alter table medical_data
add column follow_up_required varchar(5) default 'yes' after followup_date_clean;

update medical_data
set follow_up_required = 'no'
where follow_up_date = 'N/A';

select * from medical_data;

SELECT
    patient_id,
    discharge_date_clean,
    follow_up_date,
    followup_date_clean
FROM medical_data;

# formats of the dates
## discharge and follow-update
### dis m/d/y fol d/m/y 
### dis m/d/y fol m/d/y
### dis m/d/y fol could be m/d/y or d/m/y
### dis could be m/d/y or d/m/y fol m/d/y
### dis clean y/m/d fol could be m/d/y or d/m/y
### dis m/d/y fol could be either
### dis m/d/y fol could be either
### dis m/d/y fol clean is y/m/d
### dis m/d/y fol clean is y/m/d
### dis m/d/y fol clean is y/m/d
### dis m/d/y fol could be either 

# fixing discharge dates where followup_date_clean is NOT null
with discharge_resolved as (
	 select patient_id,
        case 
		    when str_to_date(discharge_date, '%d/%m/%Y') < followup_date_clean
            and str_to_date(discharge_date, '%m/%d/%Y') >= followup_date_clean
                then str_to_date(discharge_date, '%d/%m/%Y')
			when str_to_date(discharge_date, '%m/%d/%Y') < followup_date_clean
            and str_to_date(discharge_date, '%d/%m/%Y') >= followup_date_clean
		        then str_to_date(discharge_date, '%m/%d/%Y')
		end as resolved_discharge
	from medical_data
    where discharge_date_clean is null
    and discharge_date is not null
    and discharge_date !=''
    and followup_date_clean is not null)
update ignore medical_data m
join discharge_resolved r on m.patient_id = r.patient_id
set m.discharge_date_clean = r.resolved_discharge
where r.resolved_discharge is not null;
      
# fixing DISCHARGE based on follow-up 
with discharge_resolved2 as (
     select patient_id,
        case 
            when str_to_date(discharge_date, '%m/%d/%Y') < str_to_date(follow_up_date, '%m/%d/%Y')
            and str_to_date(discharge_date, '%d/%m/%Y') >= str_to_date(follow_up_date, '%m/%d/%Y')
                then str_to_date(discharge_date, '%m/%d/%Y')
            when str_to_date(discharge_date, '%m/%d/%Y') < str_to_date(follow_up_date, '%d/%m/%Y')
            and str_to_date(discharge_date, '%d/%m/%Y') >= str_to_date(follow_up_date, '%d/%m/%Y')
                then str_to_date(discharge_date, '%m/%d/%Y')
		end as resolved_discharge2
	from medical_data
    where discharge_date_clean is null
    and discharge_date is not null
    and discharge_date !=''
    and follow_up_date is not null 
    and follow_up_date !='')
update ignore medical_data m2
join discharge_resolved2 r2 on m2.patient_id = r2.patient_id
set m2.discharge_date_clean = r2.resolved_discharge2
where r2.resolved_discharge2 is not null;

# fixing ADMISSION based on discharge
with admission_resolved as (
    select patient_id,
          case 
              when str_to_date(admission_date, '%m/%d/%Y') < discharge_date_clean
              and str_to_date(admission_date, '%d/%m/%Y') >= discharge_date_clean
				 then str_to_date(admission_date, '%m/%d/%Y')
			  when str_to_date(admission_date, '%d/%m/%Y') < discharge_date_clean
              and str_to_date(admission_date, '%m/%d/%Y') >= discharge_date_clean
			     then str_to_date(admission_date, '%d/%m/%Y')
		  end as resolved_admission
	from medical_data
    where admission_date_clean is null
    and admission_date is not null
    and admission_date !=''
    and discharge_date_clean is not null)
update ignore medical_data m
join admission_resolved a on m.patient_id = a.patient_id
set m.admission_date_clean = a.resolved_admission
where a.resolved_admission is not null;

# fixing FOLLOW-UP based on discharge
with followup_resolved as( 
     select patient_id,
           case
               when str_to_date(follow_up_date, '%m/%d/%Y') > discharge_date_clean
               and str_to_date(follow_up_date, '%d/%m/%Y') <= discharge_date_clean
                  then str_to_date(follow_up_date, '%m/%d/%Y')
			   when str_to_date(follow_up_date, '%d/%m/%Y') > discharge_date_clean
               and str_to_date(follow_up_date, '%m/%d/%Y') <= discharge_date_clean
                  then str_to_date(follow_up_date, '%d/%m/%Y')
		   end as resolved_followup
	 from medical_data
     where followup_date_clean is null
     and follow_up_date is not null
     and follow_up_date !=''
     and follow_up_date != 'N/A'
     and discharge_date_clean is not null)
update ignore medical_data m
join followup_resolved f on m.patient_id = f.patient_id
set m.followup_date_clean = f.resolved_followup
where f.resolved_followup is not null;

select * from medical_data;

update medical_data
set notes = lower(notes);

-------------------------------------------------------

# populate data_quality_flag (moved here so all _clean columns exist)
# conditions for data_quality_flag column
UPDATE medical_data
SET data_quality_flag = coalesce(
	nullif(concat_ws(' |', 
           case when (first_name is null or first_name='')
                   or(last_name is null or last_name='')
					 then 'Missing Name' end,
           case when (dob is null or dob='')
                     then 'Missing DOB' end,
		   case when (dob_clean is null and dob is not null and dob!='')
					 then 'Ambiguous DOB' end, 
		   case when (discharge_date is null or discharge_date='')
					 then 'Missing Discharge Date' end,
		   case when (admission_date_clean is null and admission_date is not null and admission_date !='')
                     then 'Ambiguous Admission Date' end,
		   case when (discharge_date_clean is null and discharge_date is not null and discharge_date !='')
					 then 'Ambiguous Discharge Date' end,
		   case when dosage_mg regexp 'mcg|units'
					 then 'Inconsistent Dosage Unit' end,
		   case when (insurance_provider is null or insurance_provider ='')
					 then 'Missing Insurance Info' end,
		   case when (notes like '%conflict%')
					then 'Check Notes - Conflict Flagged' end,
		   case when (followup_date_clean is null and follow_up_date is not null and follow_up_date !='' and follow_up_date !='N/A')
		            then 'Ambiguous Follow-up Date' end
				     ), ''), 
		   'No Action Required');

select * from medical_data;

-------------------------------------------------------

# creating a new table for medications and dosages
alter table medical_data
modify patient_id varchar(10) not null,
add primary key(patient_id);

create table patient_medications (
	medication_id int auto_increment primary key,
    patient_id varchar(10),
    medication varchar(50),
    dosage decimal(6,2),
    dosage_unit varchar (10),
    foreign key (patient_id) references medical_data (patient_id)); 

ALTER TABLE patient_medications
MODIFY COLUMN dosage_unit VARCHAR(30);

######### edit patient_medications table in python :)

select * from patient_medications;

# drop medications and dosage_mg columns from medical_data dataset
alter table medical_data
drop column medications;

alter table medical_data
drop column dosage_mg;

select * from medical_data;

select * from patient_medications;

















































