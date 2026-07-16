/*******************************************************************************
* Bundle: PD Override Analysis (override simulation + direction bucketing)
* Source: macros/02_pd_validation.sas (pd_override_analysis) -- unmodified
* Caller builds a small sample portfolio (reusing main/generate_sample_data.sas's
* PD-generation logic) and drives pd_override_analysis exactly as
* run_pd_validation does.
********************************************************************************/

/*------------------------------------------------------------------------------
* Override Analysis -- unmodified from macros/02_pd_validation.sas
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

/*------------------------------------------------------------------------------
* Bundle caller: small sample portfolio (PD + default flag only), matching
* the PD-generation logic in main/generate_sample_data.sas.
------------------------------------------------------------------------------*/
DATA WORK.portfolio;
    CALL STREAMINIT(12345);
    DO customer_id = 1 TO 400;
        predicted_pd = 0.005 + RAND('BETA', 2, 30) * 0.15;
        default_12m = (RAND('UNIFORM') < predicted_pd * 1.1);
        FORMAT predicted_pd PERCENT8.2;
        OUTPUT;
    END;
RUN;

%pd_override_analysis(
    indata=WORK.portfolio,
    pd_var=predicted_pd,
    default_var=default_12m,
    out_prefix=pd_val
);
