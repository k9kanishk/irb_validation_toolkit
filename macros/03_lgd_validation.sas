/*******************************************************************************
* LGD VALIDATION MODULE
* Purpose: Complete LGD model validation battery
* Reference: EBA GL/2017/16, CRR Article 181
********************************************************************************/

%MACRO run_lgd_validation(indata=, lgd_predicted=, lgd_realized=, segment_vars=, time_var=, recovery_time_var=, out_prefix=lgd_val);
    %lgd_accuracy(indata=&indata., lgd_predicted=&lgd_predicted., lgd_realized=&lgd_realized., segment_vars=&segment_vars., out_prefix=&out_prefix.);
    %lgd_backtest_horizon(indata=&indata., lgd_predicted=&lgd_predicted., lgd_realized=&lgd_realized., recovery_time_var=&recovery_time_var., out_prefix=&out_prefix.);
    %lgd_downturn_analysis(indata=&indata., lgd_predicted=&lgd_predicted., lgd_realized=&lgd_realized., time_var=&time_var., out_prefix=&out_prefix.);
    %lgd_distribution_analysis(indata=&indata., lgd_predicted=&lgd_predicted., lgd_realized=&lgd_realized., out_prefix=&out_prefix.);
%MEND run_lgd_validation;

%MACRO lgd_accuracy(indata=, lgd_predicted=, lgd_realized=, segment_vars=, out_prefix=);
%MEND lgd_accuracy;
%MACRO lgd_backtest_horizon(indata=, lgd_predicted=, lgd_realized=, recovery_time_var=, out_prefix=);
%MEND lgd_backtest_horizon;
%MACRO lgd_downturn_analysis(indata=, lgd_predicted=, lgd_realized=, time_var=, out_prefix=);
%MEND lgd_downturn_analysis;
%MACRO lgd_distribution_analysis(indata=, lgd_predicted=, lgd_realized=, out_prefix=);
%MEND lgd_distribution_analysis;
