/*******************************************************************************
* EAD/CCF VALIDATION MODULE
* Purpose: EAD and Credit Conversion Factor validation
* Reference: EBA GL/2017/16, CRR Article 182
********************************************************************************/

%MACRO run_ead_ccf_validation(
    indata=,
    limit_var=,
    drawn_obs_var=,
    ccf_predicted=,
    segment_vars=,
    out_prefix=ead_val
);

    %PUT NOTE: ========================================;
    %PUT NOTE: Starting EAD/CCF Validation;
    %PUT NOTE: ========================================;

    /* Prepare CCF data — defaults with revolving undrawn */
    DATA _ccf_pop;
        SET &indata.;
        WHERE default_12m = 1;

        undrawn = &limit_var. - &drawn_obs_var.;
        IF undrawn > 0 THEN DO;
            /* Simulate realized CCF with noise */
            CALL STREAMINIT(777);
            realized_ccf = &ccf_predicted. + RAND('NORMAL', 0.03, 0.12);
            realized_ccf = MAX(0, MIN(1.5, realized_ccf));

            ead_predicted = &drawn_obs_var. + (undrawn * &ccf_predicted.);
            ead_realized  = &drawn_obs_var. + (undrawn * realized_ccf);
        END;
        FORMAT ead_predicted ead_realized COMMA12.
               &ccf_predicted. realized_ccf PERCENT8.2
               undrawn COMMA12.;
    RUN;

    /* CCF Overall Accuracy */
    PROC SQL;
        CREATE TABLE &out_prefix._ccf_accuracy AS
        SELECT
            COUNT(*)                                          AS N_Defaults,
            MEAN(&ccf_predicted.) * 100                       AS Predicted_CCF FORMAT=8.2,
            MEAN(realized_ccf) * 100                          AS Realized_CCF  FORMAT=8.2,
            (MEAN(realized_ccf) - MEAN(&ccf_predicted.))*100  AS Bias         FORMAT=8.2,
            MEAN(ABS(realized_ccf - &ccf_predicted.)) * 100   AS MAE          FORMAT=8.2,
            CORR(&ccf_predicted., realized_ccf)               AS Correlation   FORMAT=8.3,
            CASE
                WHEN ABS(MEAN(realized_ccf) - MEAN(&ccf_predicted.)) <= 0.05 THEN 'GREEN'
                WHEN ABS(MEAN(realized_ccf) - MEAN(&ccf_predicted.)) <= 0.10 THEN 'AMBER'
                ELSE 'RED'
            END AS RAG_Status LENGTH=10
        FROM _ccf_pop
        WHERE undrawn > 0;
    QUIT;

    TITLE "CCF Model Accuracy (%)";
    PROC PRINT DATA=&out_prefix._ccf_accuracy NOOBS; RUN;

    /* CCF by segment */
    %LET _seg = %SCAN(&segment_vars., 1);
    PROC SQL;
        CREATE TABLE &out_prefix._ccf_by_segment AS
        SELECT
            &_seg.                                              AS Segment,
            COUNT(*)                                            AS N_Defaults,
            MEAN(&ccf_predicted.) * 100                         AS Predicted_CCF FORMAT=8.2,
            MEAN(realized_ccf) * 100                            AS Realized_CCF  FORMAT=8.2,
            (MEAN(realized_ccf) - MEAN(&ccf_predicted.)) * 100  AS Bias         FORMAT=8.2
        FROM _ccf_pop
        WHERE undrawn > 0
        GROUP BY &_seg.;
    QUIT;

    TITLE "CCF by Segment (%)";
    PROC PRINT DATA=&out_prefix._ccf_by_segment NOOBS; RUN;

    /* EAD accuracy */
    PROC SQL;
        CREATE TABLE &out_prefix._ead_accuracy AS
        SELECT
            COUNT(*)              AS N_Defaults,
            MEAN(ead_predicted)   AS Avg_EAD_Predicted FORMAT=COMMA12.,
            MEAN(ead_realized)    AS Avg_EAD_Realized  FORMAT=COMMA12.,
            MEAN(ead_realized) - MEAN(ead_predicted) AS Avg_EAD_Bias FORMAT=COMMA12.,
            MEAN(ead_realized) / MEAN(ead_predicted) AS EAD_Ratio    FORMAT=8.3
        FROM _ccf_pop
        WHERE undrawn > 0;
    QUIT;

    TITLE "EAD Model Accuracy";
    PROC PRINT DATA=&out_prefix._ead_accuracy NOOBS; RUN;
    TITLE;

    /* Log CCF finding */
    DATA _NULL_;
        SET &out_prefix._ccf_accuracy;
        IF RAG_Status NE 'GREEN' THEN DO;
            sev = IFN(RAG_Status='RED', 2, 3);
            CALL EXECUTE(CATS(
                '%log_finding(module=EAD_CCF, test_name=CCF Accuracy, severity=', PUT(sev,1.),
                ', metric_name=CCF_Bias, metric_value=', PUT(Bias,8.4),
                ', threshold=5, rag_status=', RAG_Status,
                ', finding_text=CCF bias ', PUT(Bias,8.2), '% (',RAG_Status,')',
                ', recommendation=Review CCF estimation methodology)'
            ));
        END;
    RUN;

    PROC DATASETS LIB=WORK NOLIST; DELETE _ccf_pop; QUIT;

    %PUT NOTE: EAD/CCF Validation Complete;

%MEND run_ead_ccf_validation;
