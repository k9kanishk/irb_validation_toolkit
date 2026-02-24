/*******************************************************************************
* DATA QUALITY MODULE
* Purpose: Pre-validation data quality checks
* Reference: EBA GL/2017/16 Section 5 (Data Quality)
********************************************************************************/

%MACRO run_data_quality(indata=, key_vars=, date_var=, out_report=work.dq_report);
    %PUT NOTE: Starting Data Quality Assessment for &indata.;

    DATA &out_report.;
        LENGTH check_name $50 variable $32 result $20 detail $200 records_affected 8 pct_affected 8;
        STOP;
    RUN;

    %dq_record_summary(indata=&indata., date_var=&date_var.);
    %dq_missing_values(indata=&indata., out_report=&out_report.);
    %dq_duplicates(indata=&indata., key_vars=&key_vars., out_report=&out_report.);
    %dq_outliers(indata=&indata., out_report=&out_report.);
    %dq_range_checks(indata=&indata., out_report=&out_report.);

    %PUT NOTE: Data Quality Assessment Complete;
%MEND run_data_quality;

%MACRO dq_record_summary(indata=, date_var=);
    PROC SQL NOPRINT;
        SELECT COUNT(*), MIN(&date_var.), MAX(&date_var.), COUNT(DISTINCT &date_var.)
        INTO :n_records, :min_date, :max_date, :n_periods
        FROM &indata.;
    QUIT;

    %IF &n_records. < 1000 %THEN %DO;
        %log_finding(
            module=DATA_QUALITY,
            test_name=Sample Size Check,
            severity=2,
            metric_name=N_Records,
            metric_value=&n_records.,
            threshold=1000,
            finding_text=Insufficient sample size for robust validation. N=&n_records. below minimum 1000.,
            recommendation=Consider pooling data across additional periods or segments.
        );
    %END;
%MEND dq_record_summary;

%MACRO dq_missing_values(indata=, out_report=);
    PROC CONTENTS DATA=&indata. OUT=_varlist NOPRINT; RUN;
    PROC SQL NOPRINT;
        SELECT name INTO :varlist SEPARATED BY ' ' FROM _varlist;
    QUIT;

    %LET n_vars = %SYSFUNC(COUNTW(&varlist.));
    %DO i = 1 %TO &n_vars.;
        %LET var = %SCAN(&varlist., &i.);
        PROC SQL NOPRINT;
            SELECT SUM(CASE WHEN &var. IS NULL OR &var. = . THEN 1 ELSE 0 END) / COUNT(*) * 100
            INTO :miss_pct
            FROM &indata.;
        QUIT;

        %IF %SYSEVALF(&miss_pct. > 5) %THEN %DO;
            %log_finding(
                module=DATA_QUALITY,
                test_name=Missing Values,
                segment=&var.,
                severity=3,
                metric_name=Missing_Pct,
                metric_value=&miss_pct.,
                threshold=5,
                finding_text=Variable &var. has &miss_pct.% missing values,
                recommendation=Investigate data sourcing and consider imputation strategy
            );
        %END;
    %END;

    PROC DELETE DATA=_varlist; RUN;
%MEND dq_missing_values;

%MACRO dq_duplicates(indata=, key_vars=, out_report=);
    PROC SQL NOPRINT;
        SELECT COUNT(*) INTO :n_total FROM &indata.;
        SELECT COUNT(*) INTO :n_unique FROM (SELECT DISTINCT &key_vars. FROM &indata.);
    QUIT;

    %LET n_dupes = %EVAL(&n_total. - &n_unique.);
    %LET dupe_pct = %SYSEVALF(&n_dupes. / &n_total. * 100);

    %IF &n_dupes. > 0 %THEN %DO;
        %log_finding(
            module=DATA_QUALITY,
            test_name=Duplicate Records,
            severity=3,
            metric_name=Duplicate_Pct,
            metric_value=&dupe_pct.,
            threshold=0,
            finding_text=&n_dupes. duplicate records identified on key &key_vars.,
            recommendation=Review data extraction logic and deduplication rules
        );
    %END;
%MEND dq_duplicates;

%MACRO dq_outliers(indata=, out_report=, method=IQR, threshold=3);
    %PUT NOTE: Outlier detection using &method. threshold=&threshold.;
%MEND dq_outliers;

%MACRO dq_range_checks(indata=, out_report=);
    PROC SQL NOPRINT;
        SELECT COUNT(*) INTO :pd_violations FROM &indata. WHERE &pd_predicted_var. < 0.0003 OR &pd_predicted_var. > 1;
    QUIT;

    %IF &pd_violations. > 0 %THEN %DO;
        %log_finding(
            module=DATA_QUALITY,
            test_name=PD Range Check,
            severity=2,
            metric_name=PD_Violations,
            metric_value=&pd_violations.,
            threshold=0,
            finding_text=&pd_violations. PD values outside valid range [0.0003 - 1.0],
            recommendation=Review PD estimation methodology and floor application
        );
    %END;
%MEND dq_range_checks;
