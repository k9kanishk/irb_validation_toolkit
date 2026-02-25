/*******************************************************************************
* MASTER VALIDATION RUNNER
* Purpose: Execute complete IRB validation pipeline
* Usage: Update project_root, then run this file in SAS
********************************************************************************/

DM 'LOG; CLEAR; OUTPUT; CLEAR;';

/*=============================================================================
  STEP 1: CONFIGURATION
=============================================================================*/
%INCLUDE "config/validation_config.sas" / SOURCE2;
%INCLUDE "config/model_parameters.sas"  / SOURCE2;

/*=============================================================================
  STEP 2: LOAD MACROS
=============================================================================*/
%INCLUDE "macros/00_utility_macros.sas"     / SOURCE2;
%INCLUDE "macros/01_data_quality.sas"       / SOURCE2;
%INCLUDE "macros/02_pd_validation.sas"      / SOURCE2;
%INCLUDE "macros/03_lgd_validation.sas"     / SOURCE2;
%INCLUDE "macros/04_ead_ccf_validation.sas" / SOURCE2;
%INCLUDE "macros/05_reporting.sas"          / SOURCE2;
%INCLUDE "main/generate_sample_data.sas"    / SOURCE2;

/*=============================================================================
  STEP 3: INITIALIZE
=============================================================================*/
%init_validation(reset=Y);

/*=============================================================================
  STEP 4: GENERATE SAMPLE DATA
=============================================================================*/
%generate_sample_data(n_customers=10000, out_lib=WORK, out_ds=portfolio);

/*=============================================================================
  STEP 5: DATA QUALITY
=============================================================================*/
%run_data_quality(
    indata=WORK.portfolio,
    key_vars=customer_id obs_date,
    date_var=obs_date,
    out_report=WORK.dq_report
);

/*=============================================================================
  STEP 6: PD VALIDATION
=============================================================================*/
%run_pd_validation(
    indata=WORK.portfolio,
    pd_var=predicted_pd,
    default_var=default_12m,
    segment_vars=segment rating_grade,
    time_var=obs_date,
    out_prefix=pd_val
);

/*=============================================================================
  STEP 7: LGD VALIDATION
=============================================================================*/
%run_lgd_validation(
    indata=WORK.portfolio,
    lgd_predicted=predicted_lgd,
    lgd_realized=realized_lgd,
    segment_vars=segment,
    time_var=obs_date,
    recovery_time_var=recovery_months,
    out_prefix=lgd_val
);

/*=============================================================================
  STEP 8: EAD/CCF VALIDATION
=============================================================================*/
%run_ead_ccf_validation(
    indata=WORK.portfolio,
    limit_var=credit_limit,
    drawn_obs_var=current_drawn,
    ccf_predicted=predicted_ccf,
    segment_vars=segment,
    out_prefix=ead_val
);

/*=============================================================================
  STEP 9: EXPORT REPORTS
=============================================================================*/
%generate_validation_report(out_dir=&output_lib.);

/*=============================================================================
  STEP 10: PRINT SUMMARY
=============================================================================*/
TITLE "========================================";
TITLE2 "IRB VALIDATION - EXECUTIVE SUMMARY";
TITLE3 "Generated: %SYSFUNC(TODAY(), WORDDATE.)";
TITLE4 "========================================";

PROC PRINT DATA=pd_val_auc_overall NOOBS; RUN;
PROC PRINT DATA=pd_val_calibration_overall NOOBS; RUN;
PROC PRINT DATA=lgd_val_accuracy_overall NOOBS; RUN;

TITLE "ALL VALIDATION FINDINGS";
PROC PRINT DATA=validation_findings NOOBS;
    VAR finding_id module test_name segment severity rag_status finding_text;
RUN;
TITLE;

%PUT;
%PUT NOTE: ================================================;
%PUT NOTE: IRB VALIDATION COMPLETE;
%PUT NOTE: ================================================;
%PUT NOTE: Output: &output_lib.;
%PUT NOTE: ================================================;
