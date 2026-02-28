/*******************************************************************************
* IRB MODEL VALIDATION TOOLKIT - CONFIGURATION
* Purpose: Central configuration for all validation parameters
* Aligned to: CRR Article 179, EBA GL/2017/16
*
* NOTE: project_root must be set BEFORE this file is loaded.
*       It is set in run_full_validation.sas or run_module_standalone.sas
********************************************************************************/

%LET project_name = IRB_Validation_2024Q4;
%LET validation_date = %SYSFUNC(TODAY(), DATE9.);
%LET validator_name = Model Validation Unit;

/*------------------------------------------------------------------------------
* DATA PATHS (derived from project_root set in runner files)
------------------------------------------------------------------------------*/
%LET input_lib  = &project_root.\sample_data;
%LET output_lib = &project_root.\output\excel;

OPTIONS DLCREATEDIR;
LIBNAME indata  "&input_lib.";
LIBNAME outdata "&output_lib.";

/*------------------------------------------------------------------------------
* MODEL SPECIFICATIONS
------------------------------------------------------------------------------*/
%LET pd_model_name    = CORP_PD_2023;
%LET pd_score_var     = pd_score;
%LET pd_predicted_var = predicted_pd;
%LET default_flag     = default_12m;
%LET observation_date = obs_date;

%LET lgd_model_name    = CORP_LGD_2023;
%LET lgd_predicted_var = predicted_lgd;
%LET lgd_realized_var  = realized_lgd;
%LET recovery_var      = recovery_rate;

%LET ead_model_name    = CORP_EAD_2023;
%LET ccf_predicted_var = predicted_ccf;
%LET ccf_realized_var  = realized_ccf;
%LET limit_var         = credit_limit;
%LET drawn_var         = current_drawn;
%LET ead_at_default    = ead_realized;

/*------------------------------------------------------------------------------
* SEGMENTATION VARIABLES
------------------------------------------------------------------------------*/
%LET segment_vars = segment rating_grade industry region;
%LET time_var     = cohort_quarter;

/*------------------------------------------------------------------------------
* VALIDATION THRESHOLDS (EBA-aligned)
------------------------------------------------------------------------------*/
%LET auc_green_threshold = 0.70;
%LET auc_amber_threshold = 0.60;
%LET gini_min_acceptable = 0.40;

%LET calibration_slope_lower        = 0.8;
%LET calibration_slope_upper        = 1.2;
%LET calibration_intercept_tolerance = 0.02;
%LET hosmer_lemeshow_pvalue          = 0.05;
%LET calibration_bias_green          = 0.01;
%LET calibration_bias_amber          = 0.02;

%LET psi_green_threshold = 0.10;
%LET psi_amber_threshold = 0.25;
%LET csi_green_threshold = 0.10;
%LET csi_amber_threshold = 0.25;

%LET lgd_bias_tolerance  = 0.05;
%LET lgd_mape_threshold  = 0.20;

%LET ccf_bias_tolerance = 0.10;

/*------------------------------------------------------------------------------
* OUTPUT SETTINGS
------------------------------------------------------------------------------*/
%LET output_format  = EXCEL;
%LET decimal_places = 4;

/*------------------------------------------------------------------------------
* FINDING SEVERITY DEFINITIONS (EBA IRB Assessment Methodology)
*
* 1 = Critical : Material non-compliance, immediate remediation
* 2 = High     : Significant weakness, remediation within 3 months
* 3 = Medium   : Moderate weakness, remediation within 6 months
* 4 = Low      : Minor observation, next model review cycle
* 5 = Observation : Best practice recommendation
------------------------------------------------------------------------------*/

%PUT NOTE: ============================================;
%PUT NOTE: IRB Validation Toolkit Configuration Loaded;
%PUT NOTE: Project : &project_name.;
%PUT NOTE: Date    : &validation_date.;
%PUT NOTE: Root    : &project_root.;
%PUT NOTE: ============================================;
