/*******************************************************************************
* REPORTING MODULE
* Purpose: Export all validation results to Excel
********************************************************************************/

%MACRO generate_validation_report(out_dir=, report_name=IRB_Validation_Report);

    %PUT NOTE: ========================================;
    %PUT NOTE: Generating Validation Reports;
    %PUT NOTE: Output: &out_dir.;
    %PUT NOTE: ========================================;

    /* 1. PD Discrimination */
    %export_if_exists(ds=pd_val_auc_overall,
        file=&out_dir.\01_PD_Discrimination.xlsx, sheet=Overall_AUC);
    %export_if_exists(ds=pd_val_auc_by_segment,
        file=&out_dir.\01_PD_Discrimination.xlsx, sheet=AUC_By_Segment);

    /* 2. PD Calibration */
    %export_if_exists(ds=pd_val_calibration_deciles,
        file=&out_dir.\02_PD_Calibration.xlsx, sheet=Deciles);
    %export_if_exists(ds=pd_val_calibration_overall,
        file=&out_dir.\02_PD_Calibration.xlsx, sheet=Overall);
    %export_if_exists(ds=pd_val_calibration_by_segment,
        file=&out_dir.\02_PD_Calibration.xlsx, sheet=By_Segment);

    /* 3. LGD */
    %export_if_exists(ds=lgd_val_accuracy_overall,
        file=&out_dir.\03_LGD_Validation.xlsx, sheet=Overall);
    %export_if_exists(ds=lgd_val_accuracy_by_segment,
        file=&out_dir.\03_LGD_Validation.xlsx, sheet=By_Segment);
    %export_if_exists(ds=lgd_val_backtest_horizon,
        file=&out_dir.\03_LGD_Validation.xlsx, sheet=Recovery_Horizon);
    %export_if_exists(ds=lgd_val_stress_test,
        file=&out_dir.\03_LGD_Validation.xlsx, sheet=Stress_Test);
    %export_if_exists(ds=lgd_val_lgd_by_year,
        file=&out_dir.\03_LGD_Validation.xlsx, sheet=By_Year);

    /* 4. Findings */
    %export_if_exists(ds=validation_findings,
        file=&out_dir.\04_Validation_Findings.xlsx, sheet=Findings_Log);

    /* 5. PSI */
    %export_if_exists(ds=pd_val_psi_summary,
        file=&out_dir.\05_PSI_Stability.xlsx, sheet=PSI_Summary);

    /* 6. EAD/CCF */
    %export_if_exists(ds=ead_val_ccf_accuracy,
        file=&out_dir.\06_EAD_CCF_Validation.xlsx, sheet=CCF_Overall);
    %export_if_exists(ds=ead_val_ccf_by_segment,
        file=&out_dir.\06_EAD_CCF_Validation.xlsx, sheet=CCF_By_Segment);
    %export_if_exists(ds=ead_val_ead_accuracy,
        file=&out_dir.\06_EAD_CCF_Validation.xlsx, sheet=EAD_Accuracy);

    /* 7. Overrides */
    %export_if_exists(ds=pd_val_override_summary,
        file=&out_dir.\07_Override_Analysis.xlsx, sheet=Summary);
    %export_if_exists(ds=pd_val_override_direction,
        file=&out_dir.\07_Override_Analysis.xlsx, sheet=Direction);

    %PUT NOTE: Report generation complete;

%MEND generate_validation_report;

/*------------------------------------------------------------------------------
* Helper: Export dataset only if it exists
------------------------------------------------------------------------------*/
%MACRO export_if_exists(ds=, file=, sheet=Sheet1);

    %IF %SYSFUNC(EXIST(&ds.)) %THEN %DO;
        %LOCAL _nobs;
        PROC SQL NOPRINT;
            SELECT COUNT(*) INTO :_nobs FROM &ds.;
        QUIT;

        %IF &_nobs. > 0 %THEN %DO;
            PROC EXPORT DATA=&ds.
                OUTFILE="&file."
                DBMS=XLSX REPLACE;
                SHEET="&sheet.";
            RUN;
            %PUT NOTE: Exported &ds. (&_nobs. rows) -> &file. [&sheet.];
        %END;
        %ELSE %PUT WARNING: &ds. exists but has 0 rows. Skipped.;
    %END;
    %ELSE %PUT WARNING: Dataset &ds. does not exist. Skipped.;

%MEND export_if_exists;
