# IRB Credit Model Validation Toolkit

## 🎯 Live Dashboard

[View Interactive Results](https://irb-validation-toolkit.onrender.com/)

## Overview
A SAS-based validation toolkit for IRB credit risk models covering 
PD, LGD, and EAD/CCF. Aligned to CRR Articles 179/181/182 and 
EBA GL/2017/16.


## Key Results

| Metric | Value | Status |
|--------|-------|--------|
| Overall AUC | 0.6176 | AMBER |
| Gini | 0.2352 | AMBER |
| Calibration Bias | 0.39% | GREEN |
| LGD Bias | 3.42% | GREEN |
| EAD Ratio | 1.013 | GREEN |
| Default Rate | 2.11% | — |
| Findings | 5 | 3 RED, 1 AMBER |


## Validation Modules

### A. PD Validation
- **Discrimination**: AUC/Gini overall and by segment
- **Calibration**: Predicted vs Observed default rates by decile
- **Stability**: PSI (Population Stability Index) for score drift
- **Overrides**: Impact analysis of manual PD adjustments

### B. LGD Validation
- Predicted vs Realized LGD accuracy (overall + segment)
- Backtest by recovery horizon
- Downturn stress testing (10%/20%/30% recovery haircuts)

### C. EAD/CCF Validation
- CCF backtest: predicted vs realized drawdown
- EAD accuracy metrics

### D. Governance
- Automated findings log with RAG status and severity
- Excel report generation (8 output files)

## Tech Stack

| Component | Technology |
|-----------|------------|
| Core Analysis | SAS (PROC LOGISTIC, PROC SQL, PROC RANK) |
| Dashboard | Python (Dash / Plotly) |
| Reports | Excel (PROC EXPORT XLSX) |
| Version Control | Git / GitHub |

## Quick Start

### SAS Execution
```sas
/* Update path in config/validation_config.sas, then: */
%INCLUDE "main/run_full_validation.sas";
```

### Python Dashboard
```bash
cd python_dashboard
pip install -r requirements.txt
python app.py
# Open http://localhost:8050
```

## Output Files

| # | File | Contents |
|---|------|----------|
| 1 | `01_PD_Discrimination.xlsx` | AUC / Gini results |
| 2 | `02_PD_Calibration.xlsx` | Decile calibration |
| 3 | `03_LGD_Validation.xlsx` | LGD accuracy + stress test |
| 4 | `04_Validation_Findings.xlsx` | Findings log |
| 5 | `05_PSI_Stability.xlsx` | Score drift analysis |
| 6 | `06_EAD_CCF_Validation.xlsx` | CCF backtest |
| 7 | `07_Override_Analysis.xlsx` | Override impact |

## Regulatory Alignment

- **CRR Article 179** — PD estimation requirements
- **CRR Article 181** — LGD estimation requirements
- **CRR Article 182** — CCF/EAD estimation requirements
- **EBA GL/2017/16** — Guidelines on PD/LGD estimation
- **EBA GL/2019/03** — Supervisory handbook on validation

## Project Structure

```
irb_validation_toolkit/
├── config/                    # Configuration & thresholds
├── macros/                    # Reusable SAS macro library
│   ├── 00_utility_macros.sas  # Core utilities (AUC, PSI, findings)
│   ├── 01_data_quality.sas    # DQ checks
│   ├── 02_pd_validation.sas   # PD discrimination + calibration
│   ├── 03_lgd_validation.sas  # LGD accuracy + stress test
│   ├── 04_ead_ccf_validation.sas  # CCF backtest
│   └── 05_reporting.sas       # Excel export
├── main/                      # Execution scripts
│   ├── run_full_validation.sas
│   ├── run_module_standalone.sas
│   └── generate_sample_data.sas
├── python_dashboard/          # Interactive visualization
├── sql/                       # Data prep queries
└── documentation/             # Methodology guide
```
