# Frequency-Severity Pricing Model for health insurance technical premium in Spain

**Authors:** Garvit Malik · Luisa Scaroni · Sofia Allosia

## Overview

The goal is to price health insurance risk using the classic actuarial decomposition:

```
Pure Premium = Expected Frequency × Expected Severity
```

- **Frequency** (`n_medical_services`): the number of medical services used under a policy in a year.
- **Severity** (`severity = cost_claims_year / n_medical_services`): the average cost per medical event, conditional on at least one claim.

We model each component separately with a linear (GLM) approach and a tree-based (GBM) approach, compare them out-of-sample, and combine the best pieces into risk-profile and portfolio-level pure premium estimates.

## Data

- `insuranceportfolio.xlsx` — the core portfolio: policy and insured details (age, gender, type of policy/product, premium, reimbursement, distribution channel), exposure and claims history for 2017–2019, and six anonymized geographic/climatic clusters (`C_C`, plus finer indices `C_H`, `C_GI`, `C_II`, `C_IE_*`, `C_GE_*`).
- `Centroid values of the climate clusters.xlsx` — external dataset with yearly average temperature, precipitation, wind, UV index and atmospheric pressure per climatic cluster, joined onto the portfolio by cluster and year.

Portfolio size: 228,711 policy-year records; 166,877 have a positive claim (used for severity modeling).

## Exploratory Data Analysis

Key findings that shaped the modeling choices:

- **Frequency is overdispersed.** Mean = 16.81, variance = 796.87 (variance ≫ mean), so a standard Poisson model understates uncertainty — a Negative Binomial or a Poisson-loss GBM is required.
- **Severity is heavily right-skewed** with severe large claims: mean 43.3, median 30.0, 99th percentile 258, but a maximum above 16,400. Fewer than 1% of events ("large claims") drive most of the financial risk. On a log scale the distribution is close to symmetric, motivating a Gamma GLM (log link) or a log-severity GBM.
- **Low multicollinearity** between covariates — each feature contributes largely independent information, apart from expected correlations among temporal/seniority variables and compositional geographic shares.
- **Product mix is highly imbalanced**: product 'S' accounts for ~150k of ~228k policies; product 'D' has almost no severe claims (near-zero pure premium), while 'I', 'P' and 'S' cluster around a 600–700 pure premium.
- **Age × gender interaction is non-linear.** Young/middle-aged women file more claims than men (maternity and preventive care), the curves cross around age 65–70, and older men file more claims than older women afterward (chronic and cardiovascular conditions).
- **Geography matters.** Climatic cluster C4 has a distinctly higher median severity and a wider spread than the other five clusters; claim frequency is highest in C2 and lowest in C4.
- **Climate variables mostly act as regional proxies.** Frequency correlates positively with mean temperature and (net of one outlier) atmospheric pressure — both markers of warm, low-altitude, urbanized, easy-to-reach areas. Precipitation shows a weak negative correlation that is confounded by region type rather than causal. UV index shows no meaningful relationship. Wind's apparent positive correlation is driven by a single leverage point (the Canary Islands, C2) and is spurious once removed.
- **Exposure is almost always a full year** (spike at `exposure_time = 1`), with a smaller share of partial-year policies from mid-year starts/cancellations.

A choropleth of Spain (built with `sf` / `mapSpain`) visualizes mean claim frequency by climatic cluster, heuristically mapped to Spanish administrative regions (some regions are missing due to `C_C` NAs).

## Frequency Modeling

**Target:** `n_medical_services`, with `offset(log(exposure_time))`.

We first prove the Poisson model is unsuitable: the deviance/df ratio is 24.2 and a formal overdispersion test rejects equidispersion (z = 12.13, p < 2.2e-16). We then compare a **geographic** covariate specification (`C_C` cluster) against a **climatic** one (temperature, pressure, wind) and find the geographic cluster consistently gives a lower AIC — it captures the risk better than the three raw weather sensors combined. All frequency models below therefore use `age + gender + type_product + C_C`.

| Model | Description | Test MAE | Test RMSE | Test Deviance |
|---|---|---|---|---|
| **Negative Binomial GLM** | `glm.nb`, offset for exposure, θ = 0.483 (dispersion ratio ≈ 1.11 — good fit) | **16.16** | **26.38** | **1,024,154** |
| **GBM (Poisson loss)** | 1,000 trees (best = 997 via 3-fold CV), shrinkage 0.01, depth 3 | 16.62 | 26.59 | 1,085,657 |

The Negative Binomial GLM wins on all three metrics and is well-calibrated by decile on the test set, so it is the **preferred frequency model**. Its coefficients show frequency rising with age, lower frequency for males (holding other factors fixed), and cluster C4 strongly reducing frequency while C2/C3/C6 increase it — consistent with the EDA. In the GBM, `age` dominates variable importance (83%), followed by `C_C` (9%) and `gender` (7%); its main advantage is capturing the non-linear age × gender maternity effect that the linear model flattens.

## Severity Modeling

**Target:** `severity = cost_claims_year / n_medical_services`, fit only on claim-positive records. We use a **time-based train/test split** (train = 2017–2018, test = 2019) as more realistic for deployment than a random split, on predictors `age, gender, type_policy, type_policy_dg, type_product, premium, reimbursement, new_business, distribution_channel, C_H, C_GI, C_C` (103,125 training / 53,448 test rows after cleaning).

| Model | Description | Test MAE | Test RMSE |
|---|---|---|---|
| Gamma GLM (log link) | Standard actuarial choice for positive, right-skewed severities | 28.41 | 59.62 |
| **GBM (log severity, Gaussian loss + smearing correction)** | 3,000 trees, shrinkage 0.01, depth 3, smearing factor 1.31 | **27.93** | **59.20** |

The GBM is marginally better on both metrics and is the **preferred severity model**, though the Gamma GLM remains a strong, interpretable benchmark whose calibration is close on all but the top decile (where it underestimates the most severe claims). In the Gamma GLM, severity rises sharply with premium and reimbursement, and cluster C4 has a strongly positive coefficient — again matching the EDA. In the GBM, geographic variables dominate variable importance: `C_C` (47%) and `C_GI` (33%) together explain most of the severity variation, far ahead of `premium` (7%) or `age` (3%).

## Risk Profiles and Pure Premium

Three synthetic policyholder profiles (exposure standardized to 1) were priced with the best frequency model (Negative Binomial) and best severity model (GBM), alongside the weaker pair (Poisson-loss GBM frequency / Gamma GLM severity) for comparison:

| Profile | Freq (NB) | Freq (GBM) | Severity (GBM) | Severity (Gamma) | Pure Premium (best) | Pure Premium (worst) |
|---|---|---|---|---|---|---|
| Low Risk (Age 30, F, C4) | 8.71 | 11.57 | 80.20 | 84.51 | 698.36 | 977.70 |
| Medium Risk (Age 45, M, C1) | 13.22 | 10.63 | 47.59 | 45.93 | 629.28 | 488.08 |
| High Risk (Age 75, M, C2) | 32.86 | 35.87 | 40.63 | 43.10 | 1,335.07 | 1,545.87 |

### Portfolio validation: Actual vs. Expected (2019, out-of-sample)

Aggregating predicted losses (predicted frequency × predicted severity) by geographic cluster and comparing to the observed 2019 losses:

| Cluster | Observed | GLM prediction | GBM prediction | GLM/Observed | GBM/Observed |
|---|---|---|---|---|---|
| C1 | 4,701,304 | 5,244,974 | 5,015,256 | 1.12 | 1.07 |
| C2 | 1,154,656 | 1,793,260 | 1,687,559 | 1.55 | 1.46 |
| C3 | 18,623,471 | 23,001,233 | 23,404,922 | 1.24 | 1.26 |
| C4 | 5,169,748 | 6,518,437 | 6,215,604 | 1.26 | 1.20 |
| C5 | 1,222,700 | 1,559,998 | 1,492,948 | 1.28 | 1.22 |
| C6 | 10,996,538 | 13,686,630 | 12,841,032 | 1.24 | 1.17 |

Both frameworks systematically overestimate 2019 losses (ratios from 1.07 to 1.55), consistent with a macro-environmental shift between the 2017–2018 training years and 2019 that a random split would have masked — evidence that the time-based validation choice mattered. The GBM combination lands closer to 1.00 in almost every cluster, suggesting better out-of-sample generalization at the portfolio level than the GLM combination, even though the two frameworks were close on individual-record metrics.

## Key Conclusions

- **Frequency** follows the expected linear ordering under the Negative Binomial (low 8.71 < medium 13.22 < high 32.86), but the GBM's non-linear age × gender interaction actually ranks the "low risk" young-female profile *above* the "medium risk" profile (11.57 vs. 10.63) — a maternity/preventive-care effect a linear model cannot see.
- **Severity moves inversely to frequency.** The low-risk profile costs more per event (€80–85) than the high-risk senior (€41–43): young policyholders claim rarely but for expensive events (surgery, maternity, emergencies), while seniors claim often but for comparatively cheap routine or chronic care.
- **Pure premium is dominated by frequency for the elderly**: the high-risk profile is the most expensive to insure overall (€1,335–1,546), despite its lower per-event severity.
- **A priori risk labels can mislead.** The "low risk" profile ends up with a *higher* pure premium than "medium risk" once frequency and severity are combined — a reminder that naive age/gender-based segmentation should be checked against the fitted models rather than assumed.

## Limitations

- Climatic clusters are mapped to Spanish administrative regions heuristically (a geographic approximation, not an exact boundary match); regions with missing `C_C` are excluded from the map.
- A non-trivial share of records had missing geographic indices (`IICIMUN`, `C_GI`, `C_C`) that were dropped before modeling.

## Repository Structure

```
severity_modeling_r/
├── 00_config.R                    # paths, packages, global settings
├── 01_prep.R                      # data loading, cleaning, severity filter, train/test split
├── 02_gamma_glm.R                 # Gamma GLM (log link) severity model
├── 03_gbm_gamma.R                 # GBM on log(severity) with smearing correction
├── 04_evaluation.R                # MAE / RMSE / calibration-by-decile evaluation
├── run_severity_pipeline.R        # single-file runner: prep → GLM → GBM → evaluation → outputs
├── run_severity_pipeline.Rmd      # R Markdown version of the pipeline
├── README_modeling_steps.md       # step-by-step documentation of the severity pipeline
├── output/                        # prepared_data.rds, fitted models, model_comparison.csv, calibration_by_decile.csv
└── presentation_assets/           # figures/assets used in the project pitch deck
```

## How to Run

Single-file run (recommended):

```r
source("run_severity_pipeline.R")
```

This performs data preparation, Gamma GLM training, log-severity GBM training, evaluation, and writes all outputs to `output/`.

Modular run:

```r
source("01_prep.R")
source("02_gamma_glm.R")
source("03_gbm_gamma.R")
source("04_evaluation.R")
```

**Required R packages:** `tidyverse`, `skimr`, `readxl`, `corrplot`, `psych`, `gbm`, `MASS`, `AER`, `sf`, `mapSpain`, `dplyr`, `ggplot2`, `knitr`, `kableExtra`.
