/*******************************************************************************
* Bundle: EAD/CCF validation -- data prep + CCF-by-segment + EAD accuracy
* Source: macros/04_ead_ccf_validation.sas (run_ead_ccf_validation) -- the
* _ccf_pop data-prep DATA step and the ccf_by_segment / ead_accuracy PROC SQL
* queries are unmodified. (The macro's first query, ccf_accuracy, also calls
* CORR() as a plain PROC SQL aggregate -- not a documented PROC SQL summary
* function in SAS 9.4 -- so it's left out of this bundle; the two queries
* below don't depend on it.)
* Caller builds a small defaulted-loan population with credit_limit /
* current_drawn / predicted_ccf, the same shape main/generate_sample_data.sas
* produces, and drives the macro's own logic on it.
********************************************************************************/

DATA WORK.portfolio;
    LENGTH segment $15;
    CALL STREAMINIT(777);
    DO customer_id = 1 TO 300;
        _r1 = RAND('UNIFORM');
        IF _r1 < 0.5 THEN segment = 'CORPORATE'; ELSE segment = 'SME';

        default_12m = 1;  /* this bundle mirrors the defaults-only population run_ead_ccf_validation builds */
        credit_limit  = 50000 + FLOOR(RAND('EXPONENTIAL') * 450000);
        current_drawn = credit_limit * RAND('BETA', 3, 2);
        predicted_ccf = 0.20 + RAND('BETA', 2, 4) * 0.50;

        DROP _r1;
        OUTPUT;
    END;
RUN;

/*------------------------------------------------------------------------------
* Data prep -- unmodified from macros/04_ead_ccf_validation.sas
* (run_ead_ccf_validation, first DATA step)
------------------------------------------------------------------------------*/
DATA _ccf_pop;
    SET WORK.portfolio;
    WHERE default_12m = 1;

    undrawn = credit_limit - current_drawn;
    IF undrawn > 0 THEN DO;
        /* Simulate realized CCF with noise */
        CALL STREAMINIT(777);
        realized_ccf = predicted_ccf + RAND('NORMAL', 0.03, 0.12);
        realized_ccf = MAX(0, MIN(1.5, realized_ccf));

        ead_predicted = current_drawn + (undrawn * predicted_ccf);
        ead_realized  = current_drawn + (undrawn * realized_ccf);
    END;
    FORMAT ead_predicted ead_realized COMMA12.
           predicted_ccf realized_ccf PERCENT8.2
           undrawn COMMA12.;
RUN;

/*------------------------------------------------------------------------------
* CCF by segment -- unmodified from macros/04_ead_ccf_validation.sas
------------------------------------------------------------------------------*/
PROC SQL;
    CREATE TABLE ead_val_ccf_by_segment AS
    SELECT
        segment                                             AS Segment,
        COUNT(*)                                            AS N_Defaults,
        MEAN(predicted_ccf) * 100                           AS Predicted_CCF FORMAT=8.2,
        MEAN(realized_ccf) * 100                            AS Realized_CCF  FORMAT=8.2,
        (MEAN(realized_ccf) - MEAN(predicted_ccf)) * 100    AS Bias         FORMAT=8.2
    FROM _ccf_pop
    WHERE undrawn > 0
    GROUP BY segment;
QUIT;

TITLE "CCF by Segment (%)";
PROC PRINT DATA=ead_val_ccf_by_segment NOOBS; RUN;

/*------------------------------------------------------------------------------
* EAD accuracy -- unmodified from macros/04_ead_ccf_validation.sas
------------------------------------------------------------------------------*/
PROC SQL;
    CREATE TABLE ead_val_ead_accuracy AS
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
PROC PRINT DATA=ead_val_ead_accuracy NOOBS; RUN;
TITLE;
