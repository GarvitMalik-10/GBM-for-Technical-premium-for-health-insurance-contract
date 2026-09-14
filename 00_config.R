options(stringsAsFactors = FALSE)

# -------------------------------
# Project configuration
# -------------------------------

DATA_FILE <- "C:/Users/malik/NLI construct and evaluate a technical tariff plan/Dataset of health insurance portfolio/Dataset of health insurance portfolio.xlsx"
DATA_SHEET <- 1

OUTPUT_DIR <- "C:/Users/malik/NLI construct and evaluate a technical tariff plan/severity_modeling_r/output"

# Target and split settings
TARGET <- "cost_claims_year"
TRAIN_PERIODS <- c(2017, 2018)
TEST_PERIOD <- 2019

# ID / leakage columns to drop from model formulas
DROP_COLUMNS <- c(
  "ID", "ID_policy", "ID_insured",
  "date_effect_insured", "date_lapse_insured",
  "date_effect_policy", "date_lapse_policy"
)

# Candidate factor columns (will be converted if present)
FACTOR_COLUMNS <- c(
  "lapse", "type_policy", "type_policy_dg", "type_product",
  "reimbursement", "new_business", "distribution_channel", "gender",
  "C_H", "C_C"
)

# Columns to avoid using as predictors by default
EXCLUDE_FROM_PREDICTORS <- c("period", "year_effect_insured", "year_lapse_insured", "year_effect_policy", "year_lapse_policy")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
