/*******************************************************************************
* IRB MODEL VALIDATION TOOLKIT - CONFIGURATION
* Purpose: Central configuration for all validation parameters
* Aligned to: CRR Article 179, EBA GL/2017/16
*
* USAGE: Update project_root to match your local environment
*        All other paths derive from project_root automatically
********************************************************************************/

%LET project_name = IRB_Validation_2024Q4;
%LET validation_date = %SYSFUNC(TODAY(), DATE9.);
%LET validator_name = Model Validation Unit;

/*------------------------------------------------------------------------------
* DATA PATHS — UPDATE project_root FOR YOUR ENVIRONMENT
*
* Example Windows:  C:\Users\yourname\irb_validation_toolkit
* Example Linux:    /home/yourname/irb_validation_toolkit
* Example SAS Server: /sasdata/irb/validation
------------------------------------------------------------------------------*/
%LET project_root = C:\Users\k9kan\Downloads\irb_validation_toolkit-main\irb_validation_toolkit-main;

%LET input_lib  = &project_root.\sample_data;
%LET output_lib = &project_root.\output\excel;

/* Create directories if they do not exist (Windows) */
OPTIONS DLCREATEDIR;
LIBNAME indata  "&input_lib.";
LIBNAME outdata "&output_lib.";

/*------------------------------------------------------------------------------
* MODEL SPECIFICATIONS
------------------------------------------------------------------------------*/
/* PD Model */
%LET pd_model_name    = CORP_PD_2023;
%LET pd_score_var     = pd_score;
%LET pd_predicted_var = predicted_pd;
%LET default_flag     = default_12m;
%LET observation_date = obs_date;

/* LGD Model */
%LET lgd_model_name    = CORP_LGD_2023;
%LET lgd_predicted_var = predicted_lgd;
%LET lgd_realized_var  = realized_lgd;
%LET recovery_var      = recovery_rate;

/* EAD/CCF Model */
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
/* Discrimination */
%LET auc_green_threshold = 0.70;
%LET auc_amber_threshold = 0.60;
%LET gini_min_acceptable = 0.40;

/* Calibration */
%LET calibration_slope_lower        = 0.8;
%LET calibration_slope_upper        = 1.2;
%LET calibration_intercept_tolerance = 0.02;
%LET hosmer_lemeshow_pvalue          = 0.05;
%LET calibration_bias_green          = 0.01;
%LET calibration_bias_amber          = 0.02;

/* Stability */
%LET psi_green_threshold = 0.10;
%LET psi_amber_threshold = 0.25;
%LET csi_green_threshold = 0.10;
%LET csi_amber_threshold = 0.25;

/* LGD Backtesting */
%LET lgd_bias_tolerance  = 0.05;
%LET lgd_mape_threshold  = 0.20;

/* CCF Backtesting */
%LET ccf_bias_tolerance = 0.10;

/*------------------------------------------------------------------------------
* OUTPUT SETTINGS
------------------------------------------------------------------------------*/
%LET output_format  = EXCEL;
%LET decimal_places = 4;

/*------------------------------------------------------------------------------
* FINDING SEVERITY DEFINITIONS
* Aligned to EBA IRB Assessment Methodology
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
