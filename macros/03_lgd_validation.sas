/*******************************************************************************
* LGD VALIDATION MODULE
* Purpose: Complete LGD model validation battery
* Reference: EBA GL/2017/16, CRR Article 181
********************************************************************************/

%MACRO run_lgd_validation(
    indata=,
    lgd_predicted=,
    lgd_realized=,
    segment_vars=,
    time_var=,
    recovery_time_var=,
    out_prefix=lgd_val
);

    %PUT NOTE: ========================================;
    %PUT NOTE: Starting LGD Validation;
    %PUT NOTE: ========================================;

    /* Filter to defaults only */
    DATA _lgd_pop;
        SET &indata.;
        WHERE default_12m = 1 AND &lgd_realized. IS NOT NULL;
    RUN;

    %lgd_accuracy(indata=_lgd_pop, lgd_predicted=&lgd_predicted.,
                  lgd_realized=&lgd_realized., segment_vars=&segment_vars.,
                  out_prefix=&out_prefix.);

    %lgd_backtest_horizon(indata=_lgd_pop, lgd_predicted=&lgd_predicted.,
                          lgd_realized=&lgd_realized.,
                          recovery_time_var=&recovery_time_var.,
                          out_prefix=&out_prefix.);

    %lgd_downturn_analysis(indata=_lgd_pop, lgd_predicted=&lgd_predicted.,
                           lgd_realized=&lgd_realized., time_var=&time_var.,
                           out_prefix=&out_prefix.);

    PROC DATASETS LIB=WORK NOLIST; DELETE _lgd_pop; QUIT;

    %PUT NOTE: LGD Validation Complete;

%MEND run_lgd_validation;

/*------------------------------------------------------------------------------
* LGD Accuracy
------------------------------------------------------------------------------*/
%MACRO lgd_accuracy(indata=, lgd_predicted=, lgd_realized=, segment_vars=, out_prefix=);

    %PUT NOTE: --- LGD Accuracy Analysis ---;

    PROC SQL;
        CREATE TABLE &out_prefix._accuracy_overall AS
        SELECT
            COUNT(*)                                          AS N_Defaults,
            MEAN(&lgd_predicted.) * 100                       AS Predicted_LGD FORMAT=8.2,
            MEAN(&lgd_realized.) * 100                        AS Realized_LGD  FORMAT=8.2,
            (MEAN(&lgd_realized.) - MEAN(&lgd_predicted.)) * 100 AS Bias      FORMAT=8.2,
            MEAN(ABS(&lgd_realized. - &lgd_predicted.)) * 100   AS MAE        FORMAT=8.2,
            SQRT(MEAN((&lgd_realized. - &lgd_predicted.)**2)) * 100 AS RMSE   FORMAT=8.2,
            CORR(&lgd_predicted., &lgd_realized.)             AS Correlation   FORMAT=8.3,
            CASE
                WHEN ABS(MEAN(&lgd_realized.) - MEAN(&lgd_predicted.)) <= &lgd_bias_tolerance.
                    THEN 'GREEN'
                WHEN ABS(MEAN(&lgd_realized.) - MEAN(&lgd_predicted.)) <= 2 * &lgd_bias_tolerance.
                    THEN 'AMBER'
                ELSE 'RED'
            END AS RAG_Status LENGTH=10
        FROM &indata.;
    QUIT;

    TITLE "LGD Accuracy - Overall (%)";
    PROC PRINT DATA=&out_prefix._accuracy_overall NOOBS; RUN;

    /* By segment */
    %LET _seg = %SCAN(&segment_vars., 1);

    PROC SQL;
        CREATE TABLE &out_prefix._accuracy_by_segment AS
        SELECT
            &_seg.                                             AS Segment,
            COUNT(*)                                           AS N_Defaults,
            MEAN(&lgd_predicted.) * 100                        AS Predicted_LGD FORMAT=8.2,
            MEAN(&lgd_realized.) * 100                         AS Realized_LGD  FORMAT=8.2,
            (MEAN(&lgd_realized.) - MEAN(&lgd_predicted.)) * 100 AS Bias       FORMAT=8.2
        FROM &indata.
        GROUP BY &_seg.;
    QUIT;

    TITLE "LGD Accuracy by Segment (%)";
    PROC PRINT DATA=&out_prefix._accuracy_by_segment NOOBS; RUN;
    TITLE;

    /* Log finding */
    DATA _NULL_;
        SET &out_prefix._accuracy_overall;
        IF RAG_Status NE 'GREEN' THEN DO;
            sev = IFN(RAG_Status='RED', 2, 3);
            CALL EXECUTE(CATS(
                '%log_finding(module=LGD, test_name=LGD Accuracy, severity=', PUT(sev,1.),
                ', metric_name=LGD_Bias, metric_value=', PUT(Bias,8.4),
                ', threshold=', PUT(&lgd_bias_tolerance.*100,8.2),
                ', rag_status=', RAG_Status,
                ', finding_text=LGD bias ', PUT(Bias,8.2), '% (',RAG_Status,')',
                ', recommendation=Review LGD estimation methodology)'
            ));
        END;
    RUN;

%MEND lgd_accuracy;

/*------------------------------------------------------------------------------
* LGD Backtest by Recovery Horizon
------------------------------------------------------------------------------*/
%MACRO lgd_backtest_horizon(indata=, lgd_predicted=, lgd_realized=, recovery_time_var=, out_prefix=);

    %PUT NOTE: --- LGD Backtest by Recovery Horizon ---;

    DATA _recovery_bucketed;
        SET &indata.;
        LENGTH recovery_bucket $20;
        IF &recovery_time_var. IS NULL THEN recovery_bucket = 'Unknown';
        ELSE IF &recovery_time_var. <= 12 THEN recovery_bucket = '0-12 months';
        ELSE IF &recovery_time_var. <= 24 THEN recovery_bucket = '13-24 months';
        ELSE IF &recovery_time_var. <= 36 THEN recovery_bucket = '25-36 months';
        ELSE recovery_bucket = '36+ months';
    RUN;

    PROC SQL;
        CREATE TABLE &out_prefix._backtest_horizon AS
        SELECT
            recovery_bucket,
            COUNT(*)                                              AS N_Defaults,
            MEAN(&recovery_time_var.)                             AS Avg_Months    FORMAT=8.1,
            MEAN(&lgd_predicted.) * 100                           AS Predicted_LGD FORMAT=8.2,
            MEAN(&lgd_realized.) * 100                            AS Realized_LGD  FORMAT=8.2,
            (MEAN(&lgd_realized.) - MEAN(&lgd_predicted.)) * 100 AS Bias          FORMAT=8.2
        FROM _recovery_bucketed
        GROUP BY recovery_bucket;
    QUIT;

    TITLE "LGD Backtest by Recovery Horizon (%)";
    PROC PRINT DATA=&out_prefix._backtest_horizon NOOBS; RUN;
    TITLE;

    PROC DATASETS LIB=WORK NOLIST; DELETE _recovery_bucketed; QUIT;

%MEND lgd_backtest_horizon;

/*------------------------------------------------------------------------------
* LGD Downturn / Stress Analysis
------------------------------------------------------------------------------*/
%MACRO lgd_downturn_analysis(indata=, lgd_predicted=, lgd_realized=, time_var=, out_prefix=);

    %PUT NOTE: --- LGD Downturn Stress Analysis ---;

    /* LGD by year */
    PROC SQL;
        CREATE TABLE &out_prefix._lgd_by_year AS
        SELECT
            YEAR(&time_var.)                                      AS Year,
            COUNT(*)                                              AS N_Defaults,
            MEAN(&lgd_predicted.) * 100                           AS Predicted_LGD FORMAT=8.2,
            MEAN(&lgd_realized.) * 100                            AS Realized_LGD  FORMAT=8.2,
            (MEAN(&lgd_realized.) - MEAN(&lgd_predicted.)) * 100 AS Bias          FORMAT=8.2
        FROM &indata.
        GROUP BY CALCULATED Year;
    QUIT;

    TITLE "LGD by Year (Downturn Detection)";
    PROC PRINT DATA=&out_prefix._lgd_by_year NOOBS; RUN;

    /* Stress scenarios */
    PROC SQL;
        CREATE TABLE &out_prefix._stress_test AS
        SELECT 'Base Case'               AS Scenario LENGTH=30,
               MEAN(&lgd_realized.)*100  AS LGD_Pct FORMAT=8.2,
               MEAN(&lgd_predicted.)*100 AS Model_LGD FORMAT=8.2,
               (MEAN(&lgd_realized.) - MEAN(&lgd_predicted.))*100 AS Gap FORMAT=8.2
        FROM &indata.
        UNION ALL
        SELECT '10% Recovery Haircut',
               MEAN(1-(1-&lgd_realized.)*0.90)*100,
               MEAN(&lgd_predicted.)*100,
               (MEAN(1-(1-&lgd_realized.)*0.90) - MEAN(&lgd_predicted.))*100
        FROM &indata.
        UNION ALL
        SELECT '20% Recovery Haircut',
               MEAN(1-(1-&lgd_realized.)*0.80)*100,
               MEAN(&lgd_predicted.)*100,
               (MEAN(1-(1-&lgd_realized.)*0.80) - MEAN(&lgd_predicted.))*100
        FROM &indata.
        UNION ALL
        SELECT '30% Severe Haircut',
               MEAN(1-(1-&lgd_realized.)*0.70)*100,
               MEAN(&lgd_predicted.)*100,
               (MEAN(1-(1-&lgd_realized.)*0.70) - MEAN(&lgd_predicted.))*100
        FROM &indata.;
    QUIT;

    TITLE "LGD Stress Test Scenarios (%)";
    PROC PRINT DATA=&out_prefix._stress_test NOOBS; RUN;
    TITLE;

%MEND lgd_downturn_analysis;
