-- Aggregation queries for validation summaries
SELECT segment,
       cohort_quarter,
       COUNT(*) AS n_obs,
       AVG(predicted_pd) AS avg_pd,
       AVG(default_12m) AS observed_dr
FROM indata.validation_base
GROUP BY segment, cohort_quarter;
