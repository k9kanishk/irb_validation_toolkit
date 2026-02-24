/*******************************************************************************
* UTILITY MACROS
* Purpose: Common functions used across all validation modules
********************************************************************************/

/*------------------------------------------------------------------------------
* MACRO: Initialize Validation Environment
------------------------------------------------------------------------------*/
%MACRO init_validation(reset=Y);
    
    %IF &reset. = Y %THEN %DO;
        /* Clear previous work datasets */
        PROC DATASETS LIB=WORK KILL NOLIST; QUIT;
    %END;
    
    /* Create findings dataset */
    DATA WORK.validation_findings;
        LENGTH 
            finding_id $20
            module $20
            test_name $100
            segment $50
            severity 8
            metric_name $50
            metric_value 8
            threshold 8
            finding_text $500
            recommendation $500
            finding_date 8
        ;
        FORMAT finding_date DATE9.;
        STOP;
    RUN;
    
    /* Create summary statistics dataset */
    DATA WORK.validation_summary;
        LENGTH
            module $20
            segment $50
            metric_name $50
            metric_value 8
            n_observations 8
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
    finding_text=,
    recommendation=
);

    %LOCAL finding_id;
    %LET finding_id = F%SYSFUNC(DATETIME(), B8601DN.)_%SYSFUNC(RANUNI(0)*1000, 4.);
    
    PROC SQL NOPRINT;
        INSERT INTO WORK.validation_findings
        VALUES (
            "&finding_id.",
            "&module.",
            "&test_name.",
            "&segment.",
            &severity.,
            "&metric_name.",
            &metric_value.,
            &threshold.,
            "&finding_text.",
            "&recommendation.",
            TODAY()
        );
    QUIT;
    
    /* Console output based on severity */
    %IF &severity. <= 2 %THEN %DO;
        %PUT ERROR: [&module.] &finding_text. (Severity: &severity.);
    %END;
    %ELSE %IF &severity. = 3 %THEN %DO;
        %PUT WARNING: [&module.] &finding_text. (Severity: &severity.);
    %END;
    %ELSE %DO;
        %PUT NOTE: [&module.] &finding_text. (Severity: &severity.);
    %END;

%MEND log_finding;

/*------------------------------------------------------------------------------
* MACRO: Calculate AUC and Gini
------------------------------------------------------------------------------*/
%MACRO calc_auc_gini(
    indata=,
    target=,
    predicted=,
    segment=,
    out_auc=work.auc_results
);

    /* Use PROC LOGISTIC for ROC analysis */
    PROC LOGISTIC DATA=&indata. DESCENDING NOPRINT;
        %IF &segment. NE %THEN %DO;
            BY &segment.;
        %END;
        MODEL &target. = &predicted. / NOFIT;
        ROC PRED=&predicted.;
        ROCCONTRAST / ESTIMATE;
        ODS OUTPUT ROCAssociation=_roc_assoc;
    RUN;
    
    DATA &out_auc.;
        SET _roc_assoc;
        WHERE ROCModel = 'Model';
        AUC = Area;
        Gini = 2 * Area - 1;
        KEEP %IF &segment. NE %THEN &segment.; AUC Gini;
    RUN;
    
    PROC DELETE DATA=_roc_assoc; RUN;

%MEND calc_auc_gini;

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
    
    PROC SQL NOPRINT;
        CREATE TABLE _base_dist AS
        SELECT 
            score_bin,
            COUNT(*) AS base_count,
            COUNT(*) / (SELECT COUNT(*) FROM _base_ranked) AS base_pct
        FROM _base_ranked
        GROUP BY score_bin;

        CREATE TABLE _comp_dist AS
        SELECT 
            score_bin,
            COUNT(*) AS comp_count,
            COUNT(*) / (SELECT COUNT(*) FROM &comparison_data.) AS comp_pct
        FROM &comparison_data.
        GROUP BY score_bin;
    QUIT;
    
    PROC SQL;
        CREATE TABLE &out_psi. AS
        SELECT 
            COALESCE(b.score_bin, c.score_bin) AS score_bin,
            COALESCE(b.base_pct, 0.0001) AS base_pct,
            COALESCE(c.comp_pct, 0.0001) AS comp_pct,
            (COALESCE(c.comp_pct, 0.0001) - COALESCE(b.base_pct, 0.0001)) * 
                LOG(COALESCE(c.comp_pct, 0.0001) / COALESCE(b.base_pct, 0.0001)) AS psi_component,
            SUM(CALCULATED psi_component) AS total_psi
        FROM _base_dist b
        FULL JOIN _comp_dist c ON b.score_bin = c.score_bin
        GROUP BY CALCULATED score_bin;
    QUIT;
    
    PROC DELETE DATA=_base_ranked _base_dist _comp_dist; RUN;

%MEND calc_psi;

/*------------------------------------------------------------------------------
* MACRO: Calculate CSI (Characteristic Stability Index)
------------------------------------------------------------------------------*/
%MACRO calc_csi(
    base_data=,
    comparison_data=,
    char_var=,
    n_bins=10,
    out_csi=work.csi_results
);
    %calc_psi(
        base_data=&base_data.,
        comparison_data=&comparison_data.,
        score_var=&char_var.,
        n_bins=&n_bins.,
        out_psi=&out_csi.
    );
%MEND calc_csi;

/*------------------------------------------------------------------------------
* MACRO: RAG Status Assignment
------------------------------------------------------------------------------*/
%MACRO assign_rag(value, green_threshold, amber_threshold, direction=LOWER);
    
    %IF &direction. = LOWER %THEN %DO;
        CASE 
            WHEN &value. <= &green_threshold. THEN 'GREEN'
            WHEN &value. <= &amber_threshold. THEN 'AMBER'
            ELSE 'RED'
        END
    %END;
    %ELSE %DO;
        CASE 
            WHEN &value. >= &green_threshold. THEN 'GREEN'
            WHEN &value. >= &amber_threshold. THEN 'AMBER'
            ELSE 'RED'
        END
    %END;
    
%MEND assign_rag;
