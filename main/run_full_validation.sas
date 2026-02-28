/*******************************************************************************
* MASTER VALIDATION RUNNER
* Purpose: Execute complete IRB validation pipeline
*
* SETUP: Update project_root on LINE 14 to your local folder path
*
* Examples:
*   Windows:  C:\Users\yourname\irb_validation_toolkit
*   Mac/Linux: /home/yourname/irb_validation_toolkit
*   SAS Server: /sasdata/irb/validation
********************************************************************************/

DM 'LOG; CLEAR; OUTPUT; CLEAR;';

/* !! UPDATE THIS PATH TO YOUR LOCAL FOLDER !! */
%LET project_root = ;  /* e.g. C:\Users\yourname\irb_validation_toolkit */

/* Validate path is set */
%IF &project_root. = %THEN %DO;
    %PUT ERROR: ================================================;
    %PUT ERROR: project_root is not set!;
    %PUT ERROR: Open this file and update LINE 14 with your path;
    %PUT ERROR: Example: %nrstr(%LET project_root = C:\Users\yourname\irb_validation_toolkit;);
    %PUT ERROR: ================================================;
    %ABORT CANCEL;
%END;

/* Load configuration */
%INCLUDE "&project_root.\config\validation_config.sas" / SOURCE2;
%INCLUDE "&project_root.\config\model_parameters.sas" / SOURCE2;

/* Load macros */
%INCLUDE "&project_root.\macros\00_utility_macros.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\01_data_quality.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\02_pd_validation.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\03_lgd_validation.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\04_ead_ccf_validation.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\05_reporting.sas" / SOURCE2;
%INCLUDE "&project_root.\main\generate_sample_data.sas" / SOURCE2;

/* Initialize */
%init_validation(reset=Y);

/* Generate sample data */
%generate_sample_data(n_customers=10000, out_lib=WORK, out_ds=portfolio);

/* Data Quality */
%run_data_quality(
    indata=WORK.portfolio,
    key_vars=customer_id obs_date,
    date_var=obs_date,
    out_report=WORK.dq_report
);

/* PD Validation */
%run_pd_validation(
    indata=WORK.portfolio,
    pd_var=predicted_pd,
    default_var=default_12m,
    segment_vars=segment rating_grade,
    time_var=obs_date,
    out_prefix=pd_val
);

/* LGD Validation */
%run_lgd_validation(
    indata=WORK.portfolio,
    lgd_predicted=predicted_lgd,
    lgd_realized=realized_lgd,
    segment_vars=segment,
    time_var=obs_date,
    recovery_time_var=recovery_months,
    out_prefix=lgd_val
);

/* EAD/CCF Validation */
%run_ead_ccf_validation(
    indata=WORK.portfolio,
    limit_var=credit_limit,
    drawn_obs_var=current_drawn,
    ccf_predicted=predicted_ccf,
    segment_vars=segment,
    out_prefix=ead_val
);

/* Export Reports */
%generate_validation_report(out_dir=&output_lib.);

/* Print Summary */
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
