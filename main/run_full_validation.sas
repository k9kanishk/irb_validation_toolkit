%INCLUDE "../config/validation_config.sas";
%INCLUDE "../config/model_parameters.sas";
%INCLUDE "../macros/00_utility_macros.sas";
%INCLUDE "../macros/01_data_quality.sas";
%INCLUDE "../macros/02_pd_validation.sas";
%INCLUDE "../macros/03_lgd_validation.sas";
%INCLUDE "../macros/04_ead_ccf_validation.sas";
%INCLUDE "../macros/05_reporting.sas";

%init_validation(reset=Y);
%PUT NOTE: Full validation run initialized.;
