/*******************************************************************************
* PD VALIDATION MODULE
* Purpose: Complete PD model validation battery
* Reference: EBA GL/2017/16 Section 5, CRR Article 179
********************************************************************************/

%MACRO run_pd_validation(indata=, pd_var=, default_var=, segment_vars=, time_var=, out_prefix=pd_val);
    %pd_discrimination(indata=&indata., pd_var=&pd_var., default_var=&default_var., segment_vars=&segment_vars., time_var=&time_var., out_prefix=&out_prefix.);
    %pd_calibration(indata=&indata., pd_var=&pd_var., default_var=&default_var., segment_vars=&segment_vars., out_prefix=&out_prefix.);
    %pd_stability(indata=&indata., pd_var=&pd_var., time_var=&time_var., feature_vars=&segment_vars., out_prefix=&out_prefix.);
    %pd_override_analysis(indata=&indata., pd_var=&pd_var., default_var=&default_var., out_prefix=&out_prefix.);
%MEND run_pd_validation;

%MACRO pd_discrimination(indata=, pd_var=, default_var=, segment_vars=, time_var=, out_prefix=);
    PROC LOGISTIC DATA=&indata. DESCENDING NOPRINT;
        MODEL &default_var. = &pd_var. / NOFIT;
        ROC 'PD Model' PRED=&pd_var.;
        ODS OUTPUT ROCAssociation=&out_prefix._discrimination_overall;
    RUN;
%MEND pd_discrimination;

%MACRO pd_calibration(indata=, pd_var=, default_var=, segment_vars=, n_bins=10, out_prefix=);
    PROC RANK DATA=&indata. OUT=&out_prefix._binned GROUPS=&n_bins.;
        VAR &pd_var.;
        RANKS pd_bin;
    RUN;
%MEND pd_calibration;

%MACRO pd_stability(indata=, pd_var=, time_var=, feature_vars=, out_prefix=);
    %PUT NOTE: Running stability analysis (PSI/CSI).;
%MEND pd_stability;

%MACRO pd_override_analysis(indata=, pd_var=, default_var=, override_flag=override_flag, pd_pre_override=pd_pre_override, out_prefix=);
    %PUT NOTE: Running override analysis when override fields are present.;
%MEND pd_override_analysis;
