/*******************************************************************************
* Bundle: PSI (Population Stability Index) via PROC RANK/SQL
* Source: macros/00_utility_macros.sas (calc_psi) -- unmodified
* Caller builds two small score populations (base + comparison, mimicking
* the base=2021 vs comparison-year split in macros/02_pd_validation.sas's
* pd_stability) and drives calc_psi exactly as the toolkit does.
********************************************************************************/

/*------------------------------------------------------------------------------
* MACRO: Calculate PSI (Population Stability Index) -- unmodified from
*        macros/00_utility_macros.sas
------------------------------------------------------------------------------*/
%MACRO calc_psi(
    base_data=,
    comparison_data=,
    score_var=,
    n_bins=10,
    out_psi=work.psi_results
);

    PROC RANK DATA=&base_data. OUT=_base_ranked GROUPS=&n_bins.;
        VAR &score_var.;
        RANKS score_bin;
    RUN;

    PROC RANK DATA=&comparison_data. OUT=_comp_ranked GROUPS=&n_bins.;
        VAR &score_var.;
        RANKS score_bin;
    RUN;

    PROC SQL;
        CREATE TABLE _base_dist AS
        SELECT score_bin,
               COUNT(*) / (SELECT COUNT(*) FROM _base_ranked) AS base_pct
        FROM _base_ranked
        GROUP BY score_bin;

        CREATE TABLE _comp_dist AS
        SELECT score_bin,
               COUNT(*) / (SELECT COUNT(*) FROM _comp_ranked) AS comp_pct
        FROM _comp_ranked
        GROUP BY score_bin;

        CREATE TABLE &out_psi. AS
        SELECT COALESCE(b.score_bin, c.score_bin) AS score_bin,
               COALESCE(b.base_pct, 0.0001)      AS base_pct,
               COALESCE(c.comp_pct, 0.0001)      AS comp_pct,
               (COALESCE(c.comp_pct, 0.0001) - COALESCE(b.base_pct, 0.0001))
                 * LOG(COALESCE(c.comp_pct, 0.0001) / COALESCE(b.base_pct, 0.0001))
                 AS psi_component
        FROM _base_dist b
        FULL JOIN _comp_dist c ON b.score_bin = c.score_bin
        ORDER BY score_bin;

        SELECT SUM(psi_component) INTO :total_psi FROM &out_psi.;
    QUIT;

    %PUT NOTE: PSI = &total_psi.;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE _base_ranked _comp_ranked _base_dist _comp_dist;
    QUIT;

%MEND calc_psi;

/*------------------------------------------------------------------------------
* Bundle caller: two small score cohorts, base (2021-like) and comparison
* (2022-like) with a deliberate score shift, mirroring pd_stability's
* base=2021 vs later-year split in macros/02_pd_validation.sas.
------------------------------------------------------------------------------*/
DATA base_pop;
    CALL STREAMINIT(2021);
    DO customer_id = 1 TO 300;
        predicted_pd = 0.005 + RAND('BETA', 2, 30) * 0.15;
        OUTPUT;
    END;
RUN;

DATA comp_pop;
    CALL STREAMINIT(2022);
    DO customer_id = 1 TO 300;
        /* modest upward drift vs. the base cohort */
        predicted_pd = 0.010 + RAND('BETA', 2, 25) * 0.18;
        OUTPUT;
    END;
RUN;

%calc_psi(
    base_data=base_pop,
    comparison_data=comp_pop,
    score_var=predicted_pd,
    out_psi=psi_results
);

TITLE "PSI Detail by Score Bin";
PROC PRINT DATA=psi_results NOOBS; RUN;
TITLE;
