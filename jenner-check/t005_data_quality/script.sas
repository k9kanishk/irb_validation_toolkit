/*******************************************************************************
* Bundle: Data quality checks (missing values, duplicates, PD range)
* Source: macros/01_data_quality.sas (run_data_quality, dq_record_summary,
*         dq_missing_values, dq_duplicates, dq_range_checks) -- unmodified
*         macros/00_utility_macros.sas (init_validation, log_finding) -- unmodified
* Caller builds a small sample portfolio (some deliberately missing/duplicate
* rows, mirroring what a real IRB extract looks like) and drives
* run_data_quality exactly as run_full_validation.sas does.
********************************************************************************/

/*------------------------------------------------------------------------------
* MACRO: Initialize Validation Environment -- unmodified from
*        macros/00_utility_macros.sas
------------------------------------------------------------------------------*/
%MACRO init_validation(reset=Y);

    %IF &reset. = Y %THEN %DO;
        PROC DATASETS LIB=WORK KILL NOLIST; QUIT;
    %END;

    DATA WORK.validation_findings;
        LENGTH
            finding_id      $20
            module          $30
            test_name       $100
            segment         $50
            severity        8
            metric_name     $50
            metric_value    8
            threshold       8
            rag_status      $10
            finding_text    $500
            recommendation  $500
            finding_date    8
        ;
        FORMAT finding_date DATE9. metric_value threshold 8.4;
        STOP;
    RUN;

    %PUT NOTE: Validation environment initialized at %SYSFUNC(DATETIME(), DATETIME20.);

%MEND init_validation;

/*------------------------------------------------------------------------------
* MACRO: Log Finding -- unmodified from macros/00_utility_macros.sas
------------------------------------------------------------------------------*/
%MACRO log_finding(
    module=,
    test_name=,
    segment=OVERALL,
    severity=4,
    metric_name=,
    metric_value=.,
    threshold=.,
    rag_status=,
    finding_text=,
    recommendation=
);

    %LOCAL finding_id;
    %LET finding_id = F%SYSFUNC(PUTN(%SYSFUNC(TIME()), 8.));

    PROC SQL NOPRINT;
        INSERT INTO WORK.validation_findings
        SET finding_id     = "&finding_id.",
            module         = "&module.",
            test_name      = "&test_name.",
            segment        = "&segment.",
            severity       = &severity.,
            metric_name    = "&metric_name.",
            metric_value   = &metric_value.,
            threshold      = &threshold.,
            rag_status     = "&rag_status.",
            finding_text   = "&finding_text.",
            recommendation = "&recommendation.",
            finding_date   = TODAY();
    QUIT;

    %IF &severity. <= 2 %THEN
        %PUT ERROR: [&module.] &finding_text. (Severity=&severity.);
    %ELSE %IF &severity. = 3 %THEN
        %PUT WARNING: [&module.] &finding_text. (Severity=&severity.);
    %ELSE
        %PUT NOTE: [&module.] &finding_text. (Severity=&severity.);

%MEND log_finding;

/*------------------------------------------------------------------------------
* Data quality module -- unmodified from macros/01_data_quality.sas
------------------------------------------------------------------------------*/
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
    %dq_range_checks(indata=&indata., out_report=&out_report.);

    TITLE "Data Quality Report";
    PROC PRINT DATA=&out_report. NOOBS; RUN;
    TITLE;

    %PUT NOTE: Data Quality Assessment Complete;

%MEND run_data_quality;

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

%MACRO dq_missing_values(indata=, out_report=);

    PROC FORMAT;
        VALUE $misstype ' ' = 'MISSING' OTHER = 'PRESENT';
        VALUE  misstype .   = 'MISSING' OTHER = 'PRESENT';
    RUN;

    PROC MEANS DATA=&indata. NMISS N NOPRINT;
        VAR _NUMERIC_;
        OUTPUT OUT=_nmiss_stats(DROP=_TYPE_ _FREQ_) NMISS= / AUTONAME;
    RUN;

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

/*------------------------------------------------------------------------------
* Bundle caller: small sample portfolio with a few duplicate keys and a
* deliberately out-of-range PD, so the checks have something to find --
* the same kind of extract run_data_quality is meant to catch problems in.
------------------------------------------------------------------------------*/
%init_validation(reset=Y);

DATA WORK.portfolio;
    CALL STREAMINIT(2024);
    DO customer_id = 1 TO 200;
        obs_date = '01JAN2023'd + FLOOR(RAND('UNIFORM') * 300);
        predicted_pd = 0.005 + RAND('BETA', 2, 30) * 0.15;
        default_12m = (RAND('UNIFORM') < predicted_pd * 1.1);
        FORMAT obs_date DATE9. predicted_pd PERCENT8.2;
        OUTPUT;
        /* duplicate a handful of keys, and push one PD out of the CRR range */
        IF customer_id IN (5, 17, 42) THEN OUTPUT;
    END;
    IF _N_ = 1 THEN DO;
        customer_id = 9001; obs_date = '15JUN2023'd; predicted_pd = 1.4; default_12m = 0;
        OUTPUT;
    END;
RUN;

%run_data_quality(
    indata=WORK.portfolio,
    key_vars=customer_id obs_date,
    date_var=obs_date,
    out_report=WORK.dq_report
);

TITLE "All Findings";
PROC PRINT DATA=validation_findings NOOBS;
    VAR module test_name rag_status finding_text;
RUN;
TITLE;
