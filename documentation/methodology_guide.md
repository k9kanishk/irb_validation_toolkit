# IRB Validation Toolkit — Methodology Guide

## 1. Scope

This toolkit provides independent model validation for IRB credit risk parameters:

| Parameter | Article | What is validated |
|-----------|---------|-------------------|
| PD | CRR Art. 179 | Probability of Default estimates |
| LGD | CRR Art. 181 | Loss Given Default estimates |
| EAD/CCF | CRR Art. 182 | Exposure at Default / Credit Conversion Factors |

## 2. PD Validation

### 2.1 Discrimination (AUC / Gini)

Measures the model's ability to rank-order defaulters vs non-defaulters.

- **AUC** (Area Under ROC Curve): Calculated via c-statistic from PROC LOGISTIC
- **Gini** = 2 × AUC − 1
- Thresholds: GREEN ≥ 0.70, AMBER ≥ 0.60, RED < 0.60

### 2.2 Calibration

Compares predicted PD to observed default rate.

- Decile analysis: portfolio ranked into 10 bins by predicted PD
- Bias = Observed DR − Predicted PD
- Accuracy Ratio = Observed DR / Predicted PD

### 2.3 Stability (PSI)

Population Stability Index measures score distribution drift over time.
PSI = Σ (Actual% − Expected%) × ln(Actual% / Expected%)

text


- GREEN ≤ 0.10, AMBER ≤ 0.25, RED > 0.25

### 2.4 Override Analysis

Compares default rates for overridden vs non-overridden accounts.

## 3. LGD Validation

### 3.1 Accuracy Metrics

- **Bias**: Mean(Realized LGD − Predicted LGD)
- **MAE**: Mean Absolute Error
- **RMSE**: Root Mean Square Error
- **Correlation**: Pearson correlation

### 3.2 Recovery Horizon Backtest

Segments defaults by workout duration (0-12, 13-24, 25-36, 36+ months).

### 3.3 Downturn Stress Test

Applies recovery haircuts (10%, 20%, 30%) to test model resilience.

## 4. EAD/CCF Validation

### 4.1 CCF Backtest
Realized CCF = (EAD at Default − Drawn at Obs) / (Limit − Drawn at Obs)

text


Compares predicted CCF to realized CCF for revolving facilities.

## 5. Governance

### 5.1 Finding Severity

| Level | Description | Timeline |
|-------|-------------|----------|
| 1 - Critical | Material non-compliance | Immediate |
| 2 - High | Significant weakness | 3 months |
| 3 - Medium | Moderate weakness | 6 months |
| 4 - Low | Minor observation | Next review |
| 5 - Note | Best practice | Advisory |

### 5.2 RAG Status

- 🟢 **GREEN**: Within acceptable thresholds
- 🟡 **AMBER**: Approaching limits, monitoring required
- 🔴 **RED**: Outside tolerance, action required

## 6. References

- CRR (Regulation EU 575/2013), Articles 179, 181, 182
- EBA GL/2017/16 — Guidelines on PD estimation, LGD estimation
- EBA GL/2019/03 — Supervisory handbook on validation
- Basel Committee BCBS 128 — Validation of IRB approaches
