/*******************************************************************************
* EAD/CCF VALIDATION MODULE
* Purpose: EAD and Credit Conversion Factor validation
* Reference: EBA GL/2017/16, CRR Article 182
********************************************************************************/

%MACRO run_ead_ccf_validation(indata=, limit_var=, drawn_obs_var=, drawn_default_var=, ccf_predicted=, segment_vars=, time_var=, out_prefix=ead_val);
    %PUT NOTE: Starting EAD/CCF validation workflow.;
%MEND run_ead_ccf_validation;
