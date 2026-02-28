/*******************************************************************************
* STANDALONE MODULE RUNNER
* Purpose: Run a single validation module independently
*
* SETUP:
*   1. Update project_root on LINE 15
*   2. Set module_to_run on LINE 16 (DQ, PD, LGD, EAD_CCF, or ALL)
********************************************************************************/

DM 'LOG; CLEAR; OUTPUT; CLEAR;';

/* !! UPDATE THESE TWO LINES !! */
%LET project_root = ;  /* e.g. C:\Users\yourname\irb_validation_toolkit */
%LET module_to_run = PD;  /* Options: DQ, PD, LGD, EAD_CCF, ALL */

/* Validate path is set */
%IF &project_root. = %THEN %DO;
    %PUT ERROR: project_root is not set! Update LINE 15 with your path.;
    %ABORT CANCEL;
%END;

/* Load config + macros */
%INCLUDE "&project_root.\config\validation_config.sas" / SOURCE2;
%INCLUDE "&project_root.\config\model_parameters.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\00_utility_macros.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\01_data_quality.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\02_pd_validation.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\03_lgd_validation.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\04_ead_ccf_validation.sas" / SOURCE2;
%INCLUDE "&project_root.\macros\05_reporting.sas" / SOURCE2;
%INCLUDE "&project_root.\main\generate_sample_data.sas" / SOURCE2;

/* Initialize + Generate Data */
%init_validation(reset=Y);
%generate_sample_data(n_customers=10000, out_lib=WORK, out_ds=portfolio);

/* Run Selected Module */
%IF &module_to_run. = DQ OR &module_to_run. = ALL %THEN %DO;
    %run_data_quality(indata=WORK.portfolio, key_vars=customer_id obs_date,
                      date_var=obs_date, out_report=WORK.dq_report);
%END;

%IF &module_to_run. = PD OR &module_to_run. = ALL %THEN %DO;
    %run_pd_validation(indata=WORK.portfolio, pd_var=predicted_pd,
                       default_var=default_12m, segment_vars=segment rating_grade,
                       time_var=obs_date, out_prefix=pd_val);
%END;

%IF &module_to_run. = LGD OR &module_to_run. = ALL %THEN %DO;
    %run_lgd_validation(indata=WORK.portfolio, lgd_predicted=predicted_lgd,
                        lgd_realized=realized_lgd, segment_vars=segment,
                        time_var=obs_date, recovery_time_var=recovery_months,
                        out_prefix=lgd_val);
%END;

%IF &module_to_run. = EAD_CCF OR &module_to_run. = ALL %THEN %DO;
    %run_ead_ccf_validation(indata=WORK.portfolio, limit_var=credit_limit,
                            drawn_obs_var=current_drawn, ccf_predicted=predicted_ccf,
                            segment_vars=segment, out_prefix=ead_val);
%END;

/* Export + Summary */
%generate_validation_report(out_dir=&output_lib.);

TITLE "Findings";
PROC PRINT DATA=validation_findings NOOBS;
    VAR module test_name rag_status finding_text;
RUN;
TITLE;

%PUT NOTE: Standalone module &module_to_run. complete;
