-- Data preparation queries for IRB validation toolkit
SELECT *
FROM indata.raw_portfolio
WHERE obs_date >= DATE '2020-01-01';
