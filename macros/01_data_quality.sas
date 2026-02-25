/*******************************************************************************
* DATA QUALITY MODULE
* Purpose: Pre-validation data quality checks
* Reference: EBA GL/2017/16 Section 5 (Data Quality)
********************************************************************************/

%MACRO run_data_quality(indata=, key_vars=, date_var=, out_report=work.dq_report);

    %PUT NOTE: ========================================;
    %PUT NOTE: Starting Data Quality Assessment;
    %PUT NOTE: Dataset: &indata.;
    %PUT NOTE: ========================================;

    DATA &out_report.;
        LENGTH check_name $50 variable $32 result $20
               detail $200 records_affected 8 pct_affected 8;
        STOP;
    RUN;

    %dq_record_summary(indata=&indata., date_var=&date_var.);
    %dq_missing_values(indata=&indata., out_report=&out_report.);
    %dq_duplicates(indata=&indata., key_vars=&key_vars., out_report=&out_report.);
    %dq_outliers(indata=&indata., out_report=&out_report.);
    %dq_range_checks(indata=&indata., out_report=&out_report.);

    TITLE "Data Quality Report";
    PROC PRINT DATA=&out_report. NOOBS; RUN;
    TITLE;

    %PUT NOTE: Data Quality Assessment Complete;

%MEND run_data_quality;

/*------------------------------------------------------------------------------
* Record Summary
------------------------------------------------------------------------------*/
%MACRO dq_record_summary(indata=, date_var=);

    PROC SQL NOPRINT;
        SELECT COUNT(*),
               MIN(&date_var.) FORMAT=DATE9.,
               MAX(&date_var.) FORMAT=DATE9.,
               COUNT(DISTINCT &date_var.)
        INTO :n_records, :min_date, :max_date, :n_periods
        FROM &indata.;
    QUIT;

    %PUT NOTE: Records=&n_records. | Date range: &min_date. to &max_date. | Periods=&n_periods.;

    %IF &n_records. < 1000 %THEN %DO;
        %log_finding(
            module=DATA_QUALITY, test_name=Sample Size,
            severity=2, metric_name=N_Records,
            metric_value=&n_records., threshold=1000,
            rag_status=RED,
            finding_text=Sample size &n_records. below minimum 1000,
            recommendation=Pool additional cohorts
        );
    %END;

%MEND dq_record_summary;

/*------------------------------------------------------------------------------
* Missing Values
------------------------------------------------------------------------------*/
%MACRO dq_missing_values(indata=, out_report=);

    PROC FORMAT;
        VALUE $misstype ' ' = 'MISSING' OTHER = 'PRESENT';
        VALUE  misstype .   = 'MISSING' OTHER = 'PRESENT';
    RUN;

    PROC MEANS DATA=&indata. NMISS N NOPRINT;
        VAR _NUMERIC_;
        OUTPUT OUT=_nmiss_stats(DROP=_TYPE_ _FREQ_) NMISS= / AUTONAME;
    RUN;

    /* Transpose to long form */
    PROC TRANSPOSE DATA=_nmiss_stats OUT=_nmiss_long(RENAME=(COL1=n_missing _NAME_=variable));
    RUN;

    PROC SQL NOPRINT;
        SELECT COUNT(*) INTO :tot FROM &indata.;
    QUIT;

    DATA _nmiss_long;
        SET _nmiss_long;
        pct_missing = n_missing / &tot. * 100;
        IF pct_missing > 5 THEN result = 'FAIL';
        ELSE IF pct_missing > 1 THEN result = 'WARNING';
        ELSE result = 'PASS';
    RUN;

    /* Append high-missing vars to report */
    DATA _high_miss;
        SET _nmiss_long;
        WHERE pct_missing > 5;
        LENGTH check_name $50 detail $200;
        check_name = 'Missing Values';
        records_affected = n_missing;
        pct_affected = pct_missing;
        detail = CATX(' ', 'Missing rate', PUT(pct_missing, 5.1), '% exceeds 5%');
        KEEP check_name variable result detail records_affected pct_affected;
    RUN;

    PROC APPEND BASE=&out_report. DATA=_high_miss FORCE; RUN;

    /* Log findings */
    DATA _NULL_;
        SET _nmiss_long;
        WHERE pct_missing > 5;
        sev = IFN(pct_missing > 20, 2, 3);
        CALL EXECUTE(CATS(
            '%log_finding(module=DATA_QUALITY, test_name=Missing Values, segment=', variable,
            ', severity=', PUT(sev, 1.),
            ', metric_name=Missing_Pct, metric_value=', PUT(pct_missing, 8.2),
            ', threshold=5, rag_status=', IFC(sev=2, 'RED', 'AMBER'),
            ', finding_text=Variable ', variable, ' has ', PUT(pct_missing, 5.1), '% missing',
            ', recommendation=Review data sourcing)'
        ));
    RUN;

    PROC DATASETS LIB=WORK NOLIST; DELETE _nmiss_stats _nmiss_long _high_miss; QUIT;

%MEND dq_missing_values;

/*------------------------------------------------------------------------------
* Duplicate Check
------------------------------------------------------------------------------*/
%MACRO dq_duplicates(indata=, key_vars=, out_report=);

    PROC SQL NOPRINT;
        SELECT COUNT(*) INTO :n_total FROM &indata.;
        SELECT COUNT(*) INTO :n_unique FROM (SELECT DISTINCT &key_vars. FROM &indata.);
    QUIT;

    %LET n_dupes = %EVAL(&n_total. - &n_unique.);
    %LET dupe_pct = %SYSEVALF(&n_dupes. / &n_total. * 100);

    %IF &n_dupes. > 0 %THEN %DO;
        PROC SQL;
            INSERT INTO &out_report.
            SET check_name       = 'Duplicates',
                variable         = "&key_vars.",
                result           = IFC(&dupe_pct. > 1, 'FAIL', 'WARNING'),
                detail           = "&n_dupes. duplicates found (&dupe_pct.%)",
                records_affected = &n_dupes.,
                pct_affected     = &dupe_pct.;
        QUIT;

        %log_finding(
            module=DATA_QUALITY, test_name=Duplicates,
            severity=%SYSFUNC(IFC(%SYSEVALF(&dupe_pct. > 5), 2, 4)),
            metric_name=Duplicate_Pct, metric_value=&dupe_pct., threshold=0,
            rag_status=%SYSFUNC(IFC(%SYSEVALF(&dupe_pct. > 1), AMBER, GREEN)),
            finding_text=&n_dupes. duplicates on keys &key_vars.,
            recommendation=Review deduplication logic
        );
    %END;

%MEND dq_duplicates;

/*------------------------------------------------------------------------------
* Outlier Detection (IQR method)
------------------------------------------------------------------------------*/
%MACRO dq_outliers(indata=, out_report=, iqr_mult=3);

    PROC MEANS DATA=&indata. NOPRINT;
        VAR _NUMERIC_;
        OUTPUT OUT=_outlier_stats Q1= Q3= / AUTONAME;
    RUN;

    /* For each numeric variable, count outliers */
    PROC MEANS DATA=&indata. NOPRINT;
        VAR predicted_pd;
        OUTPUT OUT=_pd_stats Q1=q1 Q3=q3;
    RUN;

    DATA _NULL_;
        SET _pd_stats;
        iqr = q3 - q1;
        CALL SYMPUTX('pd_lower', q1 - &iqr_mult. * iqr);
        CALL SYMPUTX('pd_upper', q3 + &iqr_mult. * iqr);
    RUN;

    PROC SQL NOPRINT;
        SELECT COUNT(*) INTO :n_outliers
        FROM &indata.
        WHERE predicted_pd < &pd_lower. OR predicted_pd > &pd_upper.;

        SELECT COUNT(*) INTO :n_valid
        FROM &indata.
        WHERE predicted_pd IS NOT NULL;
    QUIT;

    %LET outlier_pct = %SYSEVALF(&n_outliers. / &n_valid. * 100);

    %IF %SYSEVALF(&outlier_pct. > 2) %THEN %DO;
        PROC SQL;
            INSERT INTO &out_report.
            SET check_name       = 'Outliers',
                variable         = 'predicted_pd',
                result           = 'WARNING',
                detail           = "&outlier_pct.% outside &iqr_mult.xIQR",
                records_affected = &n_outliers.,
                pct_affected     = &outlier_pct.;
        QUIT;
    %END;

    %PUT NOTE: Outlier check complete. PD outliers=&n_outliers. (&outlier_pct.%);

    PROC DATASETS LIB=WORK NOLIST; DELETE _outlier_stats _pd_stats; QUIT;

%MEND dq_outliers;

/*------------------------------------------------------------------------------
* Range Validation (IRB-specific)
------------------------------------------------------------------------------*/
%MACRO dq_range_checks(indata=, out_report=);

    /* PD must be in [0.0003, 1] per CRR */
    PROC SQL NOPRINT;
        SELECT COUNT(*) INTO :pd_viol
        FROM &indata.
        WHERE predicted_pd IS NOT NULL
          AND (predicted_pd < 0.0003 OR predicted_pd > 1);
    QUIT;

    %IF &pd_viol. > 0 %THEN %DO;
        PROC SQL;
            INSERT INTO &out_report.
            SET check_name       = 'PD Range',
                variable         = 'predicted_pd',
                result           = 'FAIL',
                detail           = "&pd_viol. values outside [0.03%, 100%]",
                records_affected = &pd_viol.,
                pct_affected     = .;
        QUIT;

        %log_finding(
            module=DATA_QUALITY, test_name=PD Range Check,
            severity=2, metric_name=PD_Violations,
            metric_value=&pd_viol., threshold=0, rag_status=RED,
            finding_text=&pd_viol. PD values outside CRR range,
            recommendation=Review PD floor application
        );
    %END;

%MEND dq_range_checks;
