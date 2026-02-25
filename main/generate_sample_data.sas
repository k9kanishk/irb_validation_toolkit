/*******************************************************************************
* SAMPLE DATA GENERATOR
* Purpose: Create realistic IRB portfolio data for testing
* File: main/generate_sample_data.sas
********************************************************************************/

%MACRO generate_sample_data(n_customers=10000, out_lib=WORK, out_ds=portfolio);

    %PUT NOTE: Generating &n_customers. sample IRB records...;

    DATA &out_lib..&out_ds.;
        LENGTH segment $15 industry $20 region $15;
        CALL STREAMINIT(12345);

        DO customer_id = 1 TO &n_customers.;
            obs_date = '01JAN2021'd + FLOOR(RAND('UNIFORM') * 1000);
            cohort_quarter = CATS(YEAR(obs_date), 'Q', QTR(obs_date));

            /* Segments */
            _r1 = RAND('UNIFORM');
            IF _r1 < 0.33      THEN segment = 'CORPORATE';
            ELSE IF _r1 < 0.67 THEN segment = 'SME';
            ELSE                     segment = 'RETAIL';

            _r2 = RAND('UNIFORM');
            IF _r2 < 0.20      THEN industry = 'MANUFACTURING';
            ELSE IF _r2 < 0.40 THEN industry = 'SERVICES';
            ELSE IF _r2 < 0.60 THEN industry = 'RETAIL';
            ELSE IF _r2 < 0.80 THEN industry = 'CONSTRUCTION';
            ELSE                     industry = 'OTHER';

            _r3 = RAND('UNIFORM');
            IF _r3 < 0.40      THEN region = 'DUBLIN';
            ELSE IF _r3 < 0.60 THEN region = 'LEINSTER';
            ELSE IF _r3 < 0.80 THEN region = 'MUNSTER';
            ELSE                     region = 'CONNACHT';

            rating_grade = CEIL(RAND('UNIFORM') * 10);

            /* PD with segment / grade effects */
            predicted_pd = 0.005 + RAND('BETA', 2, 30) * 0.15;
            IF segment = 'SME'    THEN predicted_pd = predicted_pd * 1.2;
            IF segment = 'RETAIL' THEN predicted_pd = predicted_pd * 0.8;
            IF rating_grade >= 7  THEN predicted_pd = predicted_pd * 1.5;

            /* Actual default (slightly miscalibrated) */
            default_12m = (RAND('UNIFORM') < predicted_pd * 1.1);

            /* LGD */
            IF default_12m = 1 THEN DO;
                predicted_lgd = 0.30 + RAND('BETA', 2, 3) * 0.45;
                realized_lgd  = predicted_lgd + RAND('NORMAL', 0.02, 0.10);
                realized_lgd  = MAX(0.05, MIN(0.95, realized_lgd));
                recovery_months = 6 + FLOOR(RAND('EXPONENTIAL') * 20);
                /* Downturn effect for 2021 */
                IF YEAR(obs_date) = 2021 AND MONTH(obs_date) <= 6
                    THEN realized_lgd = MIN(0.95, realized_lgd * 1.10);
            END;
            ELSE DO;
                predicted_lgd = .; realized_lgd = .; recovery_months = .;
            END;

            /* EAD / CCF */
            credit_limit  = 50000 + FLOOR(RAND('EXPONENTIAL') * 450000);
            current_drawn = credit_limit * RAND('BETA', 3, 2);
            predicted_ccf = 0.20 + RAND('BETA', 2, 4) * 0.50;

            FORMAT obs_date DATE9.
                   predicted_pd predicted_lgd realized_lgd predicted_ccf PERCENT8.2
                   credit_limit current_drawn COMMA12.;
            DROP _r1 _r2 _r3;
            OUTPUT;
        END;
    RUN;

    /* Summary */
    TITLE "Sample Data Summary";
    PROC SQL;
        SELECT COUNT(*)            AS Records,
               SUM(default_12m)    AS Defaults,
               MEAN(default_12m)*100 AS Default_Rate FORMAT=8.2,
               MEAN(predicted_pd)*100 AS Avg_PD     FORMAT=8.2,
               MIN(obs_date)       AS Min_Date       FORMAT=DATE9.,
               MAX(obs_date)       AS Max_Date       FORMAT=DATE9.
        FROM &out_lib..&out_ds.;
    QUIT;
    TITLE;

    %PUT NOTE: Sample data created -> &out_lib..&out_ds.;

%MEND generate_sample_data;
