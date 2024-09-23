*--------------------------------------------------------------------------------------*
|  Author:           Ashley Howard
|					 ashley.howard@duke.edu
|  Program name: 	 1 - CLEAN
|  Program Purpose:  Clean and derive variables
|  Input files:      * file names and path excluded for privacy *
|  Output files:     * file names and path excluded for privacy *
|
|  Activity log:     02/10/2024 - Program created
|					 03/20/2024 - Program edited to add updated Redcap dataset
|					 04/04/2024 - Pogram edited to add updated Redcap dataset
|					 04/08/2024 - Program edited to add updated Redcap dataset
*---------------------------------------------------------------------------------------;

%INCLUDE "../PROGRAMS/0 - Pathways.SAS" / SOURCE2;

PROC CONTENTS DATA=RAW.REDCAP_040824 VARNUM; RUN;

DATA RAW;
  SET RAW.REDCAP_040824;
  IF record_id =15 THEN DELETE; *Missing data for all records in RedCap*;
RUN;							*RedCap notes : "Excluded: 1 albumin dose 02/21/2023"*;

***********************;
* BEGIN QUALITY CHECK 
***********************;
* proc freq includes all categorical variables ;
* output to results exploratory data analysis folder ;
ODS RTF FILE="&main.\Results\EDA\PROC FREQ_&RUNdate.";
PROC FREQ DATA=RAW;
	TABLE sex -- ethnicity admit_diagnosis primary_surgery sot_type mcs_yn -- dialysis_pta_yn
		  albumin_regimen albumin_doses_received meds_inc_bp___1 -- operating_room_confounder
		  baseline_characteris_v_0 ap2_temp_cf ap2_temp_score ap2_map_score
		  ap2_hr_score ap2_resp_score ap2_oxygen ap2_aado_score ap2_pao_score ap2_abg
		  ap2_aph_score ap2_shco3_score ap2_sodium_score ap2_potassium_score ap2_creatinine_score
		  ap2_hematocrit_score ap2_wbc_score ap2_age_points -- ap2_ch_points 
		  apache_ii_score_complete ne_yn norepinephrine_complete epi_yn epinephrine_complete
		  phenyl_yn phenylephrine_complete dopa_yn dopamine_complete vaso_yn vasopressin_complete
		  hour_mean_arterial_p_v_1 hour_ultrafiltration_v_2
		  other_medication_DATA_complete crrt_stop_yn resume_rrt_yn -- extubate_details
		  icu_discharge_yn hosp_discharge_yn mortality hospitalization_DATA_complete;
RUN;
ODS RTF CLOSE;

* proc univariate includes all continuous variables ;
ODS RTF FILE="&main.\Results\EDA\PROC UNIVARIATE_&RUNdate.";
PROC UNIVARIATE DATA=RAW;
	VAR age dosing_weight number_doses_over4 seurm_alb_crrt_initiation
		serum_alb_before_25alb ap2_temp ap2_temp_c ap2_map ap2_hr ap2_resp ap2_aado
		ap2_pao ap2_aph ap2_shco3 ap2_sodium ap2_potassium ap2_creatinine ap2_hematocrit
		ap2_wbc ap2_gc_score ap2_tap_score ap2_total_score time_zero_ne -- ne_48post
		time_zero_epi -- epi_48post time_zero_phenyl -- phenyl_48post
		time_zero_dopa -- dopa_48post time_zero_vaso -- vaso_48post time_zero_map -- map_48post
		time_zero_uf -- uf_48post fluid_bal_48pre -- duration_vasopressors duration_crrt_hours
		duration_mv_hours icu_los_hours hospital_los_hours;
RUN;
ODS RTF CLOSE;

* Check branching logic variables;
* This macro checks if a branching variable is missing when 
  the variable that triggers the branching logic in RedCap is SELECTed ;

%macro check_branching(var1, value, var2);
    PROC SQL;
        SELECT record_id FROM RAW
        WHERE &var1 = &value and &var2 = .;
    QUIT;
%mend;

%check_branching(primary_surgery, 1, sot_type);
%check_branching(esrd_pta_yn, 1, dialysis_pta_yn );
%check_branching(albumin_doses_received, 4, number_doses_over4 );
%check_branching(ap2_oxygen, 1, ap2_aado );
%check_branching(ap2_oxygen, 1, ap2_aado_score );
%check_branching(ap2_oxygen, 2, ap2_pao );
%check_branching(ap2_oxygen, 2, ap2_pao_score );
%check_branching(ap2_abg, 1, ap2_aph );
%check_branching(ap2_abg, 1, ap2_aph_score );
%check_branching(ap2_abg, 2, ap2_shco3 );
%check_branching(ap2_abg, 2, ap2_shco3_score );
%check_branching(ap2_ch, 1, ap2_ch_points);
%check_branching(ne_yn, 1, time_zero_ne -- ne_48post);
%check_branching(epi_yn, 1, time_zero_epi -- epi_48post);
%check_branching(phenyl_yn, 1, time_zero_phenyl -- phenyl_48post);
%check_branching(dopa_yn, 1, time_zero_dopa -- dopa_48post);
%check_branching(vaso_yn, 1, time_zero_vaso -- vaso_48post);
%check_branching(crrt_stop_yn, 1, resume_rrt_yn);
%check_branching(extubate_yn, 1, extubate_details);
%check_branching(icu_discharge_yn, 1, icu_los_hours);
%check_branching(host_discharge_yn, 1, hospital_los_hours);

* manual branching checks;
* check branching logic variables for missing branching variables when multiple conditions
  trigger the branching and cannot be captured in macro above ;
* mcs_type - checkbox style RedCap variable ;
PROC SQL;;
	SELECT record_id FROM RAW
	WHERE mcs_yn=1 AND mcs_type___1=. AND mcs_type___2=. AND mcs_type___3=. AND mcs_type___4=.
					AND mcs_type___5=.;
QUIT;
* duration_crrt_hours;
PROC SQL;
	SELECT record_id FROM RAW
	WHERE (crrt_stop_yn=1 AND duration_crrt_hours=.) or
		  (crrt_stop_yn=1 AND duration_crrt_hours-.);
QUIT;
* duration_mv_hours;
PROC SQL;;
	SELECT record_id FROM RAW
	WHERE mv_crrt_yn=1 AND extubate_yn=1 AND duration_mv_hours=.;
QUIT;

********************************;
* check record id of outliers;
* this macro selects record id
  for specific potential outliers
  identified in proc freq/univariate;
********************************;
%macro recordid_outlier(var, operator, value, title_value);
    PROC SQL;
		title "Record ID for potential outlier: &var &title_value";
        SELECT record_id FROM RAW
        WHERE &var &operator &value
			and &var is not missing;
    QUIT;

%mend;

%recordid_outlier(ap2_map, = , 144 , = 144 );
%recordid_outlier(ap2_wbc, =, 167.6, = 167.6);
%recordid_outlier(dopa_32post, =, 10 , = 10 );
%recordid_outlier(map_12pre, =, 214 , = 214 );
%recordid_outlier(crystalloid_48post, = , -1663.8, = -1663.8);
%recordid_outlier(hospital_los_hours, = , 14610.28, = 14610.28);
%recordid_outlier(map_44pre, = , 0, = 0);
%recordid_outlier(map_48pre, = , 0, = 0);
%recordid_outlier(map_20post, = , 0, = 0);
%recordid_outlier(map_24post, = , 0, = 0);
%recordid_outlier(map_28post, = , 0, = 0);
%recordid_outlier(map_32post, = , 0, = 0);
%recordid_outlier(map_36post, = , 0, = 0);
%recordid_outlier(map_40post, = , 0, = 0);
%recordid_outlier(map_44post, = , 0, = 0);
%recordid_outlier(map_48post, = , 0, = 0);

********************************;
* check record id of missing values;
* this macro selects record id
  for specific missing values
  identified in proc freq/univariate;
********************************;
%macro recordid_missing(var);
    PROC SQL;
		title "Record IDs for &var missing";
        SELECT record_id FROM RAW
        WHERE &var = .;
    QUIT;
%mend;

%recordid_missing(ap2_map_score);
%recordid_missing(ap2_tap_score);
%recordid_missing(ap2_total_score);

**********************************
END QUALITY CHECK;
*********************************;

********************************;
* BEGIN VARIABLE DERIVATION * ;
********************************;
* Create a macro to calculate vasopressor dosage
  at each timepoint ;
%macro vasodose(hour, timepoint, DATA);
    DATA &DATA.; 
        SET &DATA.;
    vasodose_&hour.&timepoint = SUM(ne_&hour.&timepoint,
									epi_&hour.&timepoint,
									(phenyl_&hour.&timepoint/10),
      								(dopa_&hour.&timepoint/100), 
									(vaso_&hour.&timepoint * 2.5));
RUN;

proc sort DATA=&DATA.;
by record_id;
RUN;
%mend vasodose;

* Second macro calls the above macro for
	each vasodose_pre time interval
	and each vasodose post time interval ;
%macro generate_vasodose;
    %do i = 48 %to 4 %by -4;
        %vasodose(&i, pre, raw)
    %end;

    %do i = 4 %to 48 %by 4;
        %vasodose(&i, post, raw)
    %end;
%mend generate_vasodose;

%generate_vasodose;

*CLEAN VARIABLES*;

DATA DERIVED; 
SET RAW;
* time zero format different from other dosages, calculate separately ;
vasodose_time_zero = SUM(time_zero_ne,
						 time_zero_epi,
						(time_zero_phenyl/10),
      					(time_zero_dopa/100), 
						(time_zero_vaso * 2.5));
* mean variables for vasodose, map, and uf rate ;
* all are measured every 4 hours, 48 hours pre and 48 hours post albumin administration ;
mean_vasodose_pre = mean(vasodose_48pre-- vasodose_time_zero);
mean_vasodose_post = mean(vasodose_4post -- vasodose_48post);
mean_map_pre= mean(map_48pre --time_zero_map);
mean_map_post = mean(map_4post -- map_48post);
mean_uf_pre = mean(uf_48pre -- time_zero_uf);
mean_uf_post = mean(uf_4post -- uf_48post);

* absolute changes/differences;
absolute_change_mean_vasodose = mean_vasodose_post - mean_vasodose_pre;
percent_change_vasodose = ((mean_vasodose_post - mean_vasodose_pre) / mean_vasodose_pre)*100;
absolute_change_mean_map = mean_map_post - mean_map_pre;
absolute_change_mean_uf = mean_uf_post - mean_uf_pre;
fluid_bal_diff = fluid_bal_48post - fluid_bal_48pre;
uop_diff = uop_48post - uop_48pre;
crystalloid_diff = crystalloid_48post - crystalloid_48pre;

* duration variables ;
duration_vasopressors_hours = duration_vasopressors;
duration_vasopressors_days = duration_vasopressors/24;
duration_crrt_days = duration_crrt_hours/24;
duration_mv_days = duration_mv_hours/24;
icu_los_days = icu_los_hours/24;
hospital_los_days = hospital_los_hours/24;

* SET SOT type missing to "None";
IF sot_type = . THEN sot_type = 0;
* SET dialysis prior to admission missing as "No";
IF dialysis_pta_yn = . THEN dialysis_pta_yn = 0;

*renal recovery status ;
IF record_id = "21" THEN renal_recovery = 3;
ELSE IF crrt_stop_yn = 3 OR resume_rrt_yn =1 OR resume_rrt_yn = 2 THEN renal_recovery = 0;
ELSE IF crrt_stop_yn = 2 THEN renal_recovery = 1;
ELSE IF resume_rrt_yn = 3 THEN renal_recovery = 2;
LABEL renal_recovery = "Renal recovery";

*albumin regimen and albumin doses received;
IF albumin_regimen = 1 AND albumin_doses_received = 3
THEN albumin_regimen_dose = 0;
ELSE albumin_regimen_dose = 1;
LABEL albumin_regimen_dose = "Albumin administration";

* binary indicator for meds that increase blood pressure ;
IF meds_inc_bp___1= 1 OR meds_inc_bp___2= 1 OR meds_inc_bp___3= 1 OR meds_inc_bp___4= 1
THEN meds_increase_bp = 1;
ELSE meds_increase_bp = 0;
LABEL meds_increase_bp = "Any concurrent medications that could increase BP";

* binary indicator for meds that decrease blood pressure ;
IF meds_dec_bp___1= 1 OR meds_dec_bp___2= 1 OR meds_dec_bp___3= 1 OR meds_dec_bp___4= 1
   	OR meds_dec_bp___5= 1 OR meds_dec_bp___6= 1 
THEN meds_decrease_bp = 1;
ELSE meds_decrease_bp = 0;
LABEL meds_decrease_bp = "Any concurrent medications that could decrease BP";

* add labels to outcome variables;
LABEL absolute_change_mean_vasodose = "Mean dosage change (mcg/kg/min)";
LABEL percent_change_vasodose = "Mean dosage percentage change";
LABEL mean_vasodose_pre = "Pre-albumin 48-hour NEE requirements (mcg/kg/min)";
LABEL mean_vasodose_post = "Post-albumin 48-hour NEE requirements (mcg/kg/min)" ;

LABEL mean_map_pre = "Pre-albumin mean MAP (mmHg)";
LABEL mean_map_post = "Post-albumin mean MAP (mmHg)" ;
LABEL absolute_change_mean_map = "Mean MAP change across 48 hours before and after albumin (mmHg)";

LABEL mean_uf_pre = "Pre-albumin mean ultrafiltration rates (mL/hr)";
LABEL mean_uf_post = "Post-albumin mean ultrafiltration rates (mL/hr)";
LABEL absolute_change_mean_uf = "Mean UF rate change across 48 hours before and after albumin (mL/hr)";

LABEL fluid_bal_diff = "Difference in fluid balance 48 hours before and after albumin (mL/48 hr)";
LABEL uop_diff = "Difference in urine output 48 hours before and after albumin (mL/48 hr)";
LABEL crystalloid_diff = "Difference in crystalloid requirements 48 hours before and after albumin (mL/48hr)";
LABEL map_48pre = "Mean arterial pressure 48 hours PRE-albumin";
LABEL map_48post = "Mean arterial pressure 48 hours POST-albumin";
LABEL uf_48pre = "Ultrafiltration rate 48 hours PRE-albumin";
LABEL uf_48post = "Ultrafiltration rate 48 hours POST-albumin";

LABEL fluid_bal_48pre = "Fluid balance 48 hours PRE-albumin";
LABEL fluid_bal_48post = "Fluid balance 48 hours POST-albumin";
LABEL uop_48pre = "Urine output 48 hours PRE-albumin";
LABEL uop_48post = "Urine output 48 hours POST-albumin";

LABEL crystalloid_48pre = "Crystalloid requirement 48 hours PRE-albumin";
LABEL crystalloid_48post = "Crystalloid requirement 48 hours POST-albumin";

LABEL duration_vasopressors_hours = "Vasopressor duration (hours)";
LABEL duration_vasopressors_days = "Vasopressor duration (days)";
LABEL duration_crrt_hours = "CRRT duration (hours)";
LABEL duration_crrt_days = "CRRT duration (days)";
LABEL duration_mv_hours = "Mechanical ventilation duration (hours)";
LABEL duration_mv_days = "Mechanical ventilation duration (days)";
LABEL icu_los_hours = "ICU length of stay (hours)";
LABEL icu_los_days = "ICU length of stay (days)";
LABEL hospital_los_hours = "Hospital length of stay (hours)";
LABEL hospital_los_days = "Hospital length of stay (days) ";

LABEL ne_yn = "Received Norepinephrine";
LABEL epi_yn = "Received Epinephrine";
LABEL phenyl_yn = "Received Phenylephrine";
LABEL dopa_yn = "Received Dopamine";
LABEL vaso_yn = "Received Vasopressin";

FORMAT sot_type sot_type_new. mcs_type___1 -- mcs_type___5 meds_inc_bp___1 -- meds_inc_bp___4
		meds_dec_bp___1 -- meds_dec_bp___6 mcs_type___1_new.
		renal_recovery renal_recovery. albumin_regimen_dose albumin_regimen_dose.
		meds_increase_bp meds_decrease_bp yn. percent_change_vasodose 10.1;
RUN;

* SET derived dataset with updated date;
* will save to derived library ;
DATA DERIVED.ANALYSIS_04082024;
SET DERIVED;
RUN;

********************************************
********************************************
Begin code for plots of mean vasopressor dosage
over time;
********************************************
********************************************;

***********************************************
VASOPRESSOR DOSAGE
***********************************************;
* Calculate mean of vasopressor dosage (vasodose) at each time point among all patients ; 
* This will be used to create a plot of mean vasopressor dosage over time (48h pre - 48h post) ;
PROC MEANS DATA=derived.analysis_04082024 MEAN ;
    VAR vasodose_48pre vasodose_44pre vasodose_40pre vasodose_36pre vasodose_32pre
        vasodose_28pre vasodose_24pre vasodose_20pre vasodose_16pre vasodose_12pre
        vasodose_8pre vasodose_4pre
		vasodose_time_zero
        vasodose_4post vasodose_8post vasodose_12post vasodose_16post vasodose_20post
        vasodose_24post vasodose_28post vasodose_32post vasodose_36post vasodose_40post
        vasodose_44post vasodose_48post;
		OUTPUT OUT=mean_vasodose_out(drop=_type_ _freq_) MEAN=;
RUN;

* transpose the DATA for plotting format ;
* this will save the results FROM PROC MEANS above ;
* and KEEP in long format ;
PROC TRANSPOSE DATA=mean_vasodose_out OUT=mean_vasodose_transpose;
    VAR _all_;
RUN;

DATA mean_vasodose_transpose_new;
    SET mean_vasodose_transpose;
    LENGTH timepoint $25; * Increase length to correct errors ;
    RENAME COL1 = mean_vasodose;

	*LABEL_var is in format "vasodose_48pre" ;
    LABEL_var = _NAME_;

    * Handle 'time_zero' separately since format 
		is different than other LABEL_var vars ;
    IF LABEL_var = 'vasodose_time_zero' THEN DO;
        timepoint = 'Time zero';
        hour = 0;
    END;
    ELSE DO;
        * Extract numeric part of the variable name ;
		* create "hour" variable that is an integer represent hour in LABEL_var;
        timepoint_num = COMPRESS(LABEL_var, 'abcdefghijklmnopqrstuvwxyz_');
        hour = INPUT(timepoint_num, 8.);

        * Check for 'pre' or 'post' and format accordingly ;
        IF INDEX(LABEL_var, 'pre') THEN timepoint = CATX(' ', timepoint_num, 'hours pre');
        ELSE IF INDEX(LABEL_var, 'post') THEN timepoint = CATX(' ', timepoint_num, 'hours post');
    END;

 * Create variable "t" that ranges FROM 1 to 25 ;
	* this will help format when plotting ;
    t = _N_;

    * Format t as hours ;
    FORMAT t hours.;
    DROP LABEL_var timepoint_num;
RUN;

DATA derived.mean_vasodose;
SET mean_vasodose_transpose_new;
FORMAT mean_vasodose 10.3;
RUN;

PROC PRINT DATA=derived.mean_vasodose;
RUN;

********************************************
********************************************
End code for plot of mean vasopressor dosage
over time;
********************************************
********************************************;

*********************************************
* Begin code to transpose table 4 variables *
* This code transposes the data in table 4
* so that we can use the macro in our 2-Tables
* program to stratify my group (pre, post, absolute change)
* for our desired format
********************************************;

* create grp variables that will be used to ;
* stratify the table by pre, post, and absolute change groups ;

DATA pre_table4;
    SET DERIVED.analysis_04082024;
    grp = 1; /* 48 hours Pre-albumin */
    KEEP record_id mean_map_pre mean_uf_pre 
         fluid_bal_48pre uop_48pre crystalloid_48pre grp;
    RENAME mean_map_pre = map mean_uf_pre = uf fluid_bal_48pre = fluid_bal
           uop_48pre = urine_output crystalloid_48pre = crystalloid;
RUN;

DATA post_table4;
    SET DERIVED.analysis_04082024;
    grp = 2; /* 48 hours Post-albumin */
    KEEP record_id mean_map_post mean_uf_post 
         fluid_bal_48post uop_48post crystalloid_48post grp;
    RENAME mean_map_post = map mean_uf_post = uf fluid_bal_48post = fluid_bal
           uop_48post = urine_output crystalloid_48post = crystalloid;
RUN;

DATA diff_table4;
    SET DERIVED.analysis_04082024;
    grp = 3; /* Absolute Change */
    KEEP record_id absolute_change_mean_map absolute_change_mean_uf 
         fluid_bal_diff uop_diff crystalloid_diff grp;
    RENAME absolute_change_mean_map = map absolute_change_mean_uf = uf fluid_bal_diff = fluid_bal
           uop_diff = urine_output crystalloid_diff = crystalloid;
RUN;

DATA table4;
    SET pre_table4 post_table4 diff_table4;
RUN;

* Create formats for the grp variable ;
PROC FORMAT;
    VALUE grp_ 
        1 = '48 hours Pre-albumin'
        2 = '48 hours Post-albumin'
        3 = 'Absolute Change';
RUN;

*Apply the format to the grp variable ;
DATA table4;
    SET table4;
    FORMAT grp grp_;
RUN;

* Sort the table4 DATASET by grp;
PROC SORT DATA=table4;
    BY grp;
RUN;

*****************************************
* End code to transpose table 4 variables ;
*****************************************;

*********************************************************************
* Begin code for 95% confidence interval for mean vasopressor dosage
* Use boostrapping to obtain 95% CI 
*********************************************************************;
proc surveySELECT DATA=derived.analysis_04082024 NOPRINT SEED=202204
     OUT=bootsample(RENAME=(Replicate=SampleID))
     METHOD=urs              /* resample with replacement */
     SAMPRATE=1              /* each bootstrap sample has N observations */
     /* OUTHITS                 option to suppress the frequency var */
     reps=1000;       /* generate NumSamples bootstrap resamples */
RUN;
 
PROC MEANS DATA=bootsample NOPRINT;
   BY SampleID;
   FREQ NumberHits;
   *class group;
   VAR absolute_change_mean_vasodose;
   OUTPUT OUT=OutStats MEAN(absolute_change_mean_vasodose)=mean_change
		MEDIAN(absolute_change_mean_vasodose)=median_change;  /* approx sampling distribution */
RUN;
 
PROC UNIVARIATE DATA=OutStats NOPRINT;
   *class group;
   VAR mean_change;
   OUTPUT OUT=Pctl pctlpre =CI95_
          pctlpts =2.5  97.5       /* compute 95% bootstrap confidence interval */
          pctlname=Lower Upper;
RUN;
PROC PRINT DATA=Pctl NOOBS; RUN;

* 95% CI: -0.054, 0.006;
* updated 4/5/2024: -0.053, 0.006
* updated 4/8/2024: -0.053, 0.006

*********************************************;
* End code for 95% confidence interval for mean vasopressor dosage
* Use boostrapping to obtain 95% CI ;
**********************************************;



***********************************;
* Begin code to quality check derived variables
***********************************;

PROC SQL;
SELECT record_id FROM derived
WHERE percent_change_vasodose > 5;
QUIT;

PROC SQL;
SELECT mean_vasodose_pre FROM derived
WHERE record_id in ( "19" "47" "64");
QUIT;


PROC SQL;
SELECT record_id FROM derived
WHERE (meds_dec_bp___1= 1 OR meds_dec_bp___2= 1 OR meds_dec_bp___3= 1 OR meds_dec_bp___4= 1
   	OR meds_dec_bp___5= 1 OR meds_dec_bp___6= 1) 
	AND meds_decrease_bp = 0;
QUIT;


***********************************************************
Begin code to output which record IDs have vasopressor
dosage of 0 at each 4 hour time interval
***********************************************************;

ods rtf file="&main.\Results\Vasopressor Dosage Zero_&RUNdate.";
%macro check_zero_vasodose(var1, timepoint);
    PROC SQL;
		title "Record ID for vasopressor dosage of 0 at &timepoint";
        SELECT record_id FROM derived.analysis_04052024
        WHERE &var1 = 0;
    QUIT;
%mend;

%check_zero_vasodose(vasodose_48pre, 48 hours pre-albumin);
%check_zero_vasodose(vasodose_44pre, 44 hours pre-albumin);
%check_zero_vasodose(vasodose_40pre, 40 hours pre-albumin);
%check_zero_vasodose(vasodose_36pre, 36 hours pre-albumin);
%check_zero_vasodose(vasodose_32pre, 32 hours pre-albumin);
%check_zero_vasodose(vasodose_28pre, 28 hours pre-albumin);
%check_zero_vasodose(vasodose_24pre, 24 hours pre-albumin);
%check_zero_vasodose(vasodose_20pre, 20 hours pre-albumin);
%check_zero_vasodose(vasodose_16pre, 16 hours pre-albumin);
%check_zero_vasodose(vasodose_12pre, 12 hours pre-albumin);
%check_zero_vasodose(vasodose_8pre, 8 hours pre-albumin);
%check_zero_vasodose(vasodose_4pre, 4 hours pre-albumin);
%check_zero_vasodose(vasodose_time_zero, time zero);
%check_zero_vasodose(vasodose_4post, 4 hours post-albumin);
%check_zero_vasodose(vasodose_8post, 8 hours post-albumin);
%check_zero_vasodose(vasodose_12post, 12 hours post-albumin);
%check_zero_vasodose(vasodose_16post, 16 hours post-albumin);
%check_zero_vasodose(vasodose_20post, 20 hours post-albumin);
%check_zero_vasodose(vasodose_24post, 24 hours post-albumin);
%check_zero_vasodose(vasodose_28post, 28 hours post-albumin);
%check_zero_vasodose(vasodose_32post, 32 hours post-albumin);
%check_zero_vasodose(vasodose_36post, 36 hours post-albumin);
%check_zero_vasodose(vasodose_40post, 40 hours post-albumin);
%check_zero_vasodose(vasodose_44post, 44 hours post-albumin);
%check_zero_vasodose(vasodose_48post, 48 hours post-albumin);
ods rtf close; 

***********************************************************
End code to output which record IDs have vasopressor
dosage of 0 at each 4 hour time interval
***********************************************************;

***********************************;
* End code to quality check derived variables
***********************************;
