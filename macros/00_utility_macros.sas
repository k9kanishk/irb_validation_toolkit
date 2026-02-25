/*******************************************************************************
* UTILITY MACROS
* Purpose: Common functions used across all validation modules
********************************************************************************/

/*------------------------------------------------------------------------------
* MACRO: Initialize Validation Environment
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

    DATA WORK.validation_summary;
        LENGTH
            module          $30
            segment         $50
            metric_name     $50
            metric_value    8
            n_observations  8
            calculation_date 8
        ;
        FORMAT calculation_date DATE9.;
        STOP;
    RUN;

    %PUT NOTE: Validation environment initialized at %SYSFUNC(DATETIME(), DATETIME20.);

%MEND init_validation;

/*------------------------------------------------------------------------------
* MACRO: Log Finding
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
* MACRO: Calculate AUC / Gini via PROC LOGISTIC Association table
*        (Compatible with SAS 9.4 — uses c-statistic from Association output)
------------------------------------------------------------------------------*/
%MACRO calc_auc(
    indata=,
    target=,
    predicted=,
    out_auc=work.auc_results
);

    ODS EXCLUDE ALL;
    PROC LOGISTIC DATA=&indata. DESCENDING;
        MODEL &target. = &predicted.;
        ODS OUTPUT Association=_assoc_temp;
    RUN;
    ODS EXCLUDE NONE;

    DATA &out_auc.;
        SET _assoc_temp;
        WHERE Label2 = 'c';
        AUC  = nValue2;
        Gini = 2 * AUC - 1;
        KEEP AUC Gini;
        FORMAT AUC Gini 8.4;
    RUN;

    PROC DATASETS LIB=WORK NOLIST; DELETE _assoc_temp; QUIT;

%MEND calc_auc;

/*------------------------------------------------------------------------------
* MACRO: Calculate AUC for a specific segment value
------------------------------------------------------------------------------*/
%MACRO calc_auc_segment(indata=, target=, predicted=, segment_var=, segment_val=, out_auc=);

    ODS EXCLUDE ALL;
    PROC LOGISTIC DATA=&indata.(WHERE=(&segment_var.="&segment_val.")) DESCENDING;
        MODEL &target. = &predicted.;
        ODS OUTPUT Association=_assoc_seg;
    RUN;
    ODS EXCLUDE NONE;

    DATA &out_auc.;
        SET _assoc_seg;
        WHERE Label2 = 'c';
        LENGTH Segment $30;
        Segment = "&segment_val.";
        AUC  = nValue2;
        Gini = 2 * AUC - 1;

        LENGTH RAG_Status $10;
        IF AUC >= &auc_green_threshold. THEN RAG_Status = 'GREEN';
        ELSE IF AUC >= &auc_amber_threshold. THEN RAG_Status = 'AMBER';
        ELSE RAG_Status = 'RED';

        KEEP Segment AUC Gini RAG_Status;
        FORMAT AUC Gini 8.4;
    RUN;

    PROC DATASETS LIB=WORK NOLIST; DELETE _assoc_seg; QUIT;

%MEND calc_auc_segment;

/*------------------------------------------------------------------------------
* MACRO: Calculate PSI (Population Stability Index)
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
