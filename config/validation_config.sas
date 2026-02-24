/*******************************************************************************
* IRB MODEL VALIDATION TOOLKIT - CONFIGURATION
* Purpose: Central configuration for all validation parameters
* Aligned to: CRR Article 179, EBA GL/2017/16
********************************************************************************/

%LET project_name = IRB_Validation_2024Q4;
%LET validation_date = %SYSFUNC(TODAY(), DATE9.);
%LET validator_name = Model Validation Unit;

/*------------------------------------------------------------------------------
* DATA PATHS
------------------------------------------------------------------------------*/
%LET input_lib = /data/irb/input;
%LET output_lib = /data/irb/output;
%LET archive_lib = /data/irb/archive;

LIBNAME indata "&input_lib.";
LIBNAME outdata "&output_lib.";
LIBNAME archive "&archive_lib.";

/*------------------------------------------------------------------------------
* MODEL SPECIFICATIONS
------------------------------------------------------------------------------*/
/* PD Model Parameters */
%LET pd_model_name = CORP_PD_2023;
%LET pd_score_var = pd_score;
%LET pd_predicted_var = predicted_pd;
%LET default_flag = default_12m;
%LET observation_date = obs_date;

/* LGD Model Parameters */
%LET lgd_model_name = CORP_LGD_2023;
%LET lgd_predicted_var = predicted_lgd;
%LET lgd_realized_var = realized_lgd;
%LET recovery_var = recovery_rate;

/* EAD/CCF Model Parameters */
%LET ead_model_name = CORP_EAD_2023;
%LET ccf_predicted_var = predicted_ccf;
%LET ccf_realized_var = realized_ccf;
%LET limit_var = credit_limit;
%LET drawn_var = current_drawn;
%LET ead_at_default = ead_realized;

/*------------------------------------------------------------------------------
* SEGMENTATION VARIABLES
------------------------------------------------------------------------------*/
%LET segment_vars = segment rating_grade industry region;
%LET time_var = cohort_quarter;
%LET time_periods = 2020Q1 2020Q2 2020Q3 2020Q4 2021Q1 2021Q2 2021Q3 2021Q4 
                    2022Q1 2022Q2 2022Q3 2022Q4 2023Q1 2023Q2 2023Q3 2023Q4;

/*------------------------------------------------------------------------------
* VALIDATION THRESHOLDS (EBA-aligned)
------------------------------------------------------------------------------*/
/* Discrimination */
%LET auc_green_threshold = 0.70;
%LET auc_amber_threshold = 0.60;
%LET gini_min_acceptable = 0.40;

/* Calibration */
%LET calibration_slope_lower = 0.8;
%LET calibration_slope_upper = 1.2;
%LET calibration_intercept_tolerance = 0.02;
%LET hosmer_lemeshow_pvalue = 0.05;

/* Stability */
%LET psi_green_threshold = 0.10;
%LET psi_amber_threshold = 0.25;
%LET csi_green_threshold = 0.10;
%LET csi_amber_threshold = 0.25;

/* LGD Backtesting */
%LET lgd_bias_tolerance = 0.05;
%LET lgd_mape_threshold = 0.20;

/* CCF Backtesting */
%LET ccf_bias_tolerance = 0.10;

/*------------------------------------------------------------------------------
* OUTPUT SETTINGS
------------------------------------------------------------------------------*/
%LET output_format = EXCEL PDF;  /* Options: EXCEL, PDF, HTML, ALL */
%LET chart_width = 800;
%LET chart_height = 600;
%LET decimal_places = 4;

/*------------------------------------------------------------------------------
* FINDING SEVERITY DEFINITIONS
------------------------------------------------------------------------------*/
/* 
Severity Levels (EBA IRB Assessment Methodology aligned):
1 = Critical: Material non-compliance, immediate remediation required
2 = High: Significant weakness, remediation within 3 months
3 = Medium: Moderate weakness, remediation within 6 months  
4 = Low: Minor observation, next model review cycle
5 = Observation: Best practice recommendation
*/
