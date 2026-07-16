/*******************************************************************************
* Bundle: PD calibration (decile + overall + by-segment) via PROC RANK/SQL
* Source: macros/02_pd_validation.sas (pd_calibration) -- unmodified
* Caller at the bottom builds a small sample portfolio (reusing
* main/generate_sample_data.sas) and drives pd_calibration exactly as
* run_full_validation.sas does.
********************************************************************************/

/* Thresholds normally loaded from config/validation_config.sas */
%LET calibration_bias_green = 0.01;
%LET calibration_bias_amber = 0.02;

/*------------------------------------------------------------------------------
* Calibration Analysis -- unmodified from macros/02_pd_validation.sas
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

    PROC DATASETS LIB=WORK NOLIST; DELETE _ranked; QUIT;
    TITLE;

%MEND pd_calibration;

/*------------------------------------------------------------------------------
* Sample data generator -- unmodified from main/generate_sample_data.sas
------------------------------------------------------------------------------*/
%MACRO generate_sample_data(n_customers=10000, out_lib=WORK, out_ds=portfolio);

    DATA &out_lib..&out_ds.;
        LENGTH segment $15;
        CALL STREAMINIT(12345);

        DO customer_id = 1 TO &n_customers.;
            _r1 = RAND('UNIFORM');
            IF _r1 < 0.33      THEN segment = 'CORPORATE';
            ELSE IF _r1 < 0.67 THEN segment = 'SME';
            ELSE                     segment = 'RETAIL';

            rating_grade = CEIL(RAND('UNIFORM') * 10);

            predicted_pd = 0.005 + RAND('BETA', 2, 30) * 0.15;
            IF segment = 'SME'    THEN predicted_pd = predicted_pd * 1.2;
            IF segment = 'RETAIL' THEN predicted_pd = predicted_pd * 0.8;
            IF rating_grade >= 7  THEN predicted_pd = predicted_pd * 1.5;

            default_12m = (RAND('UNIFORM') < predicted_pd * 1.1);

            FORMAT predicted_pd PERCENT8.2;
            DROP _r1;
            OUTPUT;
        END;
    RUN;

%MEND generate_sample_data;

/* Bundle caller */
%generate_sample_data(n_customers=500, out_lib=WORK, out_ds=portfolio);

%pd_calibration(
    indata=WORK.portfolio,
    pd_var=predicted_pd,
    default_var=default_12m,
    segment_vars=segment,
    out_prefix=pd_val
);
