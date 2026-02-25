/*******************************************************************************
* PD VALIDATION MODULE
* Purpose: Complete PD model validation battery
* Reference: EBA GL/2017/16 Section 5, CRR Article 179
********************************************************************************/

/*------------------------------------------------------------------------------
* Master PD Validation Runner
------------------------------------------------------------------------------*/
%MACRO run_pd_validation(
    indata=,
    pd_var=,
    default_var=,
    segment_vars=,
    time_var=,
    out_prefix=pd_val
);

    %PUT NOTE: ========================================;
    %PUT NOTE: Starting PD Model Validation;
    %PUT NOTE: ========================================;

    %pd_discrimination(indata=&indata., pd_var=&pd_var., default_var=&default_var.,
                       segment_vars=&segment_vars., out_prefix=&out_prefix.);

    %pd_calibration(indata=&indata., pd_var=&pd_var., default_var=&default_var.,
                    segment_vars=&segment_vars., out_prefix=&out_prefix.);

    %pd_stability(indata=&indata., pd_var=&pd_var., time_var=&time_var.,
                  out_prefix=&out_prefix.);

    %pd_override_analysis(indata=&indata., pd_var=&pd_var., default_var=&default_var.,
                          out_prefix=&out_prefix.);

    %PUT NOTE: PD Validation Complete;

%MEND run_pd_validation;

/*------------------------------------------------------------------------------
* Discrimination Analysis (AUC / Gini)
------------------------------------------------------------------------------*/
%MACRO pd_discrimination(indata=, pd_var=, default_var=, segment_vars=, out_prefix=);

    %PUT NOTE: --- Discrimination Analysis ---;

    /* Overall AUC */
    %calc_auc(indata=&indata., target=&default_var., predicted=&pd_var.,
              out_auc=&out_prefix._auc_overall);

    DATA &out_prefix._auc_overall;
        SET &out_prefix._auc_overall;
        LENGTH Segment $30 RAG_Status $10;
        Segment = 'OVERALL';
        IF AUC >= &auc_green_threshold. THEN RAG_Status = 'GREEN';
        ELSE IF AUC >= &auc_amber_threshold. THEN RAG_Status = 'AMBER';
        ELSE RAG_Status = 'RED';
    RUN;

    TITLE "PD Discrimination - Overall";
    PROC PRINT DATA=&out_prefix._auc_overall NOOBS; RUN;

    /* Log finding */
    DATA _NULL_;
        SET &out_prefix._auc_overall;
        IF RAG_Status NE 'GREEN' THEN DO;
            sev = IFN(RAG_Status='RED', 2, 3);
            CALL EXECUTE(CATS(
                '%log_finding(module=PD, test_name=Overall AUC, severity=', PUT(sev,1.),
                ', metric_name=AUC, metric_value=', PUT(AUC,8.4),
                ', threshold=', PUT(&auc_green_threshold.,8.4),
                ', rag_status=', RAG_Status,
                ', finding_text=AUC=', PUT(AUC,8.4), ' (', STRIP(RAG_Status), ')',
                ', recommendation=Monitor or recalibrate)'
            ));
        END;
    RUN;

    /* AUC by Segment */
    %LET _n_segs = %SYSFUNC(COUNTW(&segment_vars.));
    %LET _first_seg = %SCAN(&segment_vars., 1);

    /* Get distinct values for first segment variable */
    PROC SQL NOPRINT;
        SELECT DISTINCT &_first_seg. INTO :_seg_vals SEPARATED BY '|'
        FROM &indata.
        WHERE &_first_seg. IS NOT NULL;
    QUIT;

    %LET _n_vals = %SYSFUNC(COUNTW(&_seg_vals., |));

    %DO _s = 1 %TO &_n_vals.;
        %LET _sv = %SCAN(&_seg_vals., &_s., |);
        %calc_auc_segment(indata=&indata., target=&default_var., predicted=&pd_var.,
                          segment_var=&_first_seg., segment_val=&_sv.,
                          out_auc=_auc_seg_&_s.);
    %END;

    DATA &out_prefix._auc_by_segment;
        SET %DO _s = 1 %TO &_n_vals.; _auc_seg_&_s. %END; ;
    RUN;

    TITLE "PD Discrimination by Segment";
    PROC PRINT DATA=&out_prefix._auc_by_segment NOOBS; RUN;

    /* Log segment findings */
    DATA _NULL_;
        SET &out_prefix._auc_by_segment;
        IF RAG_Status = 'RED' THEN DO;
            CALL EXECUTE(CATS(
                '%log_finding(module=PD, test_name=Segment AUC, segment=', Segment,
                ', severity=2, metric_name=AUC, metric_value=', PUT(AUC,8.4),
                ', threshold=', PUT(&auc_amber_threshold.,8.4),
                ', rag_status=RED',
                ', finding_text=Segment ', Segment, ' AUC=', PUT(AUC,8.4), ' is RED',
                ', recommendation=Investigate segment model performance)'
            ));
        END;
    RUN;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE %DO _s = 1 %TO &_n_vals.; _auc_seg_&_s. %END; ;
    QUIT;

%MEND pd_discrimination;

/*------------------------------------------------------------------------------
* Calibration Analysis
------------------------------------------------------------------------------*/
%MACRO pd_calibration(indata=, pd_var=, default_var=, segment_vars=, n_bins=10, out_prefix=);

    %PUT NOTE: --- Calibration Analysis ---;

    /* Decile calibration */
    PROC RANK DATA=&indata. OUT=_ranked GROUPS=&n_bins.;
        VAR &pd_var.;
        RANKS pd_decile;
    RUN;

    PROC SQL;
        CREATE TABLE &out_prefix._calibration_deciles AS
        SELECT
            pd_decile                                       AS Decile,
            COUNT(*)                                        AS N_Obs,
            SUM(&default_var.)                              AS N_Defaults,
            MEAN(&pd_var.) * 100                            AS Predicted_PD FORMAT=8.3,
            MEAN(&default_var.) * 100                       AS Observed_DR  FORMAT=8.3,
            (MEAN(&default_var.) - MEAN(&pd_var.)) * 100   AS Bias         FORMAT=8.3,
            MIN(&pd_var.) * 100                             AS PD_Min       FORMAT=8.3,
            MAX(&pd_var.) * 100                             AS PD_Max       FORMAT=8.3
        FROM _ranked
        GROUP BY pd_decile
        ORDER BY pd_decile;
    QUIT;

    TITLE "PD Calibration by Decile (values in %)";
    PROC PRINT DATA=&out_prefix._calibration_deciles NOOBS; RUN;

    /* Overall calibration */
    PROC SQL;
        CREATE TABLE &out_prefix._calibration_overall AS
        SELECT
            COUNT(*)                                        AS N_Total,
            SUM(&default_var.)                              AS N_Defaults,
            MEAN(&default_var.) * 100                       AS Observed_DR_Pct  FORMAT=8.3,
            MEAN(&pd_var.) * 100                            AS Predicted_PD_Pct FORMAT=8.3,
            (MEAN(&default_var.) - MEAN(&pd_var.)) * 100   AS Bias_Pct         FORMAT=8.3,
            MEAN(&default_var.) / MEAN(&pd_var.)            AS Accuracy_Ratio   FORMAT=8.2,
            CASE
                WHEN ABS(MEAN(&default_var.) - MEAN(&pd_var.)) <= &calibration_bias_green.
                    THEN 'GREEN'
                WHEN ABS(MEAN(&default_var.) - MEAN(&pd_var.)) <= &calibration_bias_amber.
                    THEN 'AMBER'
                ELSE 'RED'
            END AS RAG_Status LENGTH=10
        FROM &indata.;
    QUIT;

    TITLE "PD Calibration - Overall";
    PROC PRINT DATA=&out_prefix._calibration_overall NOOBS; RUN;

    /* Calibration by segment */
    %LET _first_seg = %SCAN(&segment_vars., 1);

    PROC SQL;
        CREATE TABLE &out_prefix._calibration_by_segment AS
        SELECT
            &_first_seg.                                     AS Segment,
            COUNT(*)                                         AS N_Obs,
            SUM(&default_var.)                               AS N_Defaults,
            MEAN(&pd_var.) * 100                             AS Predicted_PD_Pct FORMAT=8.3,
            MEAN(&default_var.) * 100                        AS Observed_DR_Pct  FORMAT=8.3,
            (MEAN(&default_var.) - MEAN(&pd_var.)) * 100    AS Bias_Pct         FORMAT=8.3
        FROM &indata.
        GROUP BY &_first_seg.;
    QUIT;

    TITLE "PD Calibration by Segment (%)";
    PROC PRINT DATA=&out_prefix._calibration_by_segment NOOBS; RUN;

    /* Log calibration finding */
    DATA _NULL_;
        SET &out_prefix._calibration_overall;
        IF RAG_Status NE 'GREEN' THEN DO;
            sev = IFN(RAG_Status='RED', 2, 3);
            CALL EXECUTE(CATS(
                '%log_finding(module=PD, test_name=Calibration Bias, severity=', PUT(sev,1.),
                ', metric_name=Bias_Pct, metric_value=', PUT(Bias_Pct,8.4),
                ', threshold=1, rag_status=', RAG_Status,
                ', finding_text=Calibration bias ', PUT(Bias_Pct,8.3), '% (',RAG_Status,')',
                ', recommendation=Consider PD scaling adjustment)'
            ));
        END;
    RUN;

    PROC DATASETS LIB=WORK NOLIST; DELETE _ranked; QUIT;
    TITLE;

%MEND pd_calibration;

/*------------------------------------------------------------------------------
* Stability Analysis (PSI)
------------------------------------------------------------------------------*/
%MACRO pd_stability(indata=, pd_var=, time_var=, out_prefix=);

    %PUT NOTE: --- Stability Analysis (PSI) ---;

    /* Split by year using obs_date */
    DATA _base_pop _comp_pops;
        SET &indata.;
        _year = YEAR(&time_var.);
        IF _year = 2021 THEN OUTPUT _base_pop;
        ELSE IF _year >= 2022 THEN OUTPUT _comp_pops;
    RUN;

    /* Check base has data */
    %LOCAL base_n;
    PROC SQL NOPRINT;
        SELECT COUNT(*) INTO :base_n FROM _base_pop;
    QUIT;

    %IF &base_n. < 100 %THEN %DO;
        %PUT WARNING: Base period has fewer than 100 records. PSI may be unreliable.;
        DATA &out_prefix._psi_summary;
            LENGTH Period $20 RAG_Status $10 Interpretation $50;
            Period = 'N/A'; PSI = .; RAG_Status = 'N/A'; Interpretation = 'Insufficient base data';
        RUN;
        %RETURN;
    %END;

    /* Initialize PSI summary */
    DATA &out_prefix._psi_summary;
        LENGTH Period $20 PSI 8 RAG_Status $10 Interpretation $50;
        FORMAT PSI 8.4;
        STOP;
    RUN;

    /* Get distinct comparison years */
    PROC SQL NOPRINT;
        SELECT DISTINCT _year INTO :comp_years SEPARATED BY '|'
        FROM _comp_pops ORDER BY _year;
    QUIT;

    %LET n_comp = %SYSFUNC(COUNTW(&comp_years., |));

    %DO _y = 1 %TO &n_comp.;
        %LET _yr = %SCAN(&comp_years., &_y., |);

        DATA _this_comp;
            SET _comp_pops;
            WHERE _year = &_yr.;
        RUN;

        %calc_psi(base_data=_base_pop, comparison_data=_this_comp,
                  score_var=&pd_var., out_psi=_psi_detail);

        PROC SQL NOPRINT;
            SELECT SUM(psi_component) FORMAT=8.4 INTO :psi_val FROM _psi_detail;
        QUIT;

        DATA _psi_row;
            LENGTH Period $20 RAG_Status $10 Interpretation $50;
            Period = "&_yr.";
            PSI = &psi_val.;
            IF PSI <= &psi_green_threshold. THEN DO;
                RAG_Status = 'GREEN'; Interpretation = 'Stable'; END;
            ELSE IF PSI <= &psi_amber_threshold. THEN DO;
                RAG_Status = 'AMBER'; Interpretation = 'Some shift detected'; END;
            ELSE DO;
                RAG_Status = 'RED'; Interpretation = 'Significant population shift'; END;
            FORMAT PSI 8.4;
        RUN;

        PROC APPEND BASE=&out_prefix._psi_summary DATA=_psi_row FORCE; RUN;
    %END;

    TITLE "PSI - Score Stability (Base=2021)";
    PROC PRINT DATA=&out_prefix._psi_summary NOOBS; RUN;
    TITLE;

    /* Log PSI findings */
    DATA _NULL_;
        SET &out_prefix._psi_summary;
        IF RAG_Status NE 'GREEN' THEN DO;
            sev = IFN(RAG_Status='RED', 2, 3);
            CALL EXECUTE(CATS(
                '%log_finding(module=PD, test_name=PSI Score Stability, segment=', Period,
                ', severity=', PUT(sev,1.),
                ', metric_name=PSI, metric_value=', PUT(PSI,8.4),
                ', threshold=', PUT(&psi_green_threshold.,8.4),
                ', rag_status=', RAG_Status,
                ', finding_text=PSI=', PUT(PSI,8.4), ' for ', STRIP(Period), ' - ', STRIP(Interpretation),
                ', recommendation=Investigate population changes)'
            ));
        END;
    RUN;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE _base_pop _comp_pops _this_comp _psi_detail _psi_row;
    QUIT;

%MEND pd_stability;

/*------------------------------------------------------------------------------
* Override Analysis
------------------------------------------------------------------------------*/
%MACRO pd_override_analysis(indata=, pd_var=, default_var=, out_prefix=);

    %PUT NOTE: --- Override Analysis ---;

    /* Simulate overrides (10% of population) */
    DATA _override_sim;
        SET &indata.;
        CALL STREAMINIT(999);
        override_flag = (RAND('UNIFORM') < 0.10);
        IF override_flag = 1 THEN DO;
            pd_pre_override  = &pd_var.;
            IF RAND('UNIFORM') < 0.6 THEN
                pd_post_override = &pd_var. * (0.5 + RAND('UNIFORM') * 0.4);
            ELSE
                pd_post_override = &pd_var. * (1.1 + RAND('UNIFORM') * 0.5);
        END;
        ELSE DO;
            pd_pre_override  = &pd_var.;
            pd_post_override = &pd_var.;
        END;
    RUN;

    PROC SQL;
        CREATE TABLE &out_prefix._override_summary AS
        SELECT
            CASE WHEN override_flag = 1 THEN 'Overridden' ELSE 'Not Overridden' END
                AS Override_Status LENGTH=20,
            COUNT(*)                         AS N_Accounts,
            SUM(&default_var.)               AS N_Defaults,
            MEAN(&default_var.) * 100        AS Default_Rate_Pct FORMAT=8.2,
            MEAN(&pd_var.) * 100             AS Avg_PD_Pct       FORMAT=8.2,
            MEAN(pd_post_override) * 100     AS Avg_Post_PD_Pct  FORMAT=8.2
        FROM _override_sim
        GROUP BY CALCULATED Override_Status;
    QUIT;

    PROC SQL;
        CREATE TABLE &out_prefix._override_direction AS
        SELECT
            CASE
                WHEN pd_post_override < pd_pre_override * 0.95 THEN 'Risk Downgraded'
                WHEN pd_post_override > pd_pre_override * 1.05 THEN 'Risk Upgraded'
                ELSE 'No Material Change'
            END AS Direction LENGTH=30,
            COUNT(*)                          AS N_Overrides,
            MEAN(&default_var.) * 100         AS Default_Rate_Pct FORMAT=8.2,
            MEAN(pd_pre_override) * 100       AS Avg_Original_PD  FORMAT=8.2,
            MEAN(pd_post_override) * 100      AS Avg_Final_PD     FORMAT=8.2
        FROM _override_sim
        WHERE override_flag = 1
        GROUP BY CALCULATED Direction;
    QUIT;

    TITLE "Override Impact Summary";
    PROC PRINT DATA=&out_prefix._override_summary NOOBS; RUN;
    TITLE "Override Direction Analysis";
    PROC PRINT DATA=&out_prefix._override_direction NOOBS; RUN;
    TITLE;

    PROC DATASETS LIB=WORK NOLIST; DELETE _override_sim; QUIT;

%MEND pd_override_analysis;
