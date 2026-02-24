/*******************************************************************************
* REPORTING MODULE
* Purpose: Consolidated report generation for IRB model validation
********************************************************************************/

%MACRO generate_validation_report(out_dir=, report_name=IRB_Validation_Report);
    %PUT NOTE: Generating validation report to &out_dir.
%MEND generate_validation_report;
