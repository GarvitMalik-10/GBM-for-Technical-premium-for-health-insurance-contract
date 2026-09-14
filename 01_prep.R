source("00_config.R")

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
})

message("Loading data from Excel...")
df <- read_excel(DATA_FILE, sheet = DATA_SHEET)
df <- as.data.frame(df)

if (!TARGET %in% names(df)) {
  stop(sprintf("Target column '%s' not found in dataset.", TARGET))
}

if (!"period" %in% names(df)) {
  stop("Column 'period' is required for time split but was not found.")
}

# Ensure period is numeric year
df$period <- as.integer(df$period)

# Convert configured categorical variables to factors when available
for (col_nm in intersect(FACTOR_COLUMNS, names(df))) {
  df[[col_nm]] <- as.factor(df[[col_nm]])
}

# Keep only claim-positive rows for severity modeling
df_sev <- df %>%
  filter(.data[[TARGET]] > 0)

if (nrow(df_sev) == 0) {
  stop("No rows with positive severity found after filtering.")
}

train <- df_sev %>% filter(period %in% TRAIN_PERIODS)
test <- df_sev %>% filter(period == TEST_PERIOD)

if (nrow(train) == 0 || nrow(test) == 0) {
  stop("Train/test split produced an empty set. Check period values in your data.")
}

# Build default predictor list
predictors <- setdiff(
  names(df_sev),
  unique(c(TARGET, DROP_COLUMNS, EXCLUDE_FROM_PREDICTORS))
)

# Remove predictors with all missing values
all_na_cols <- predictors[vapply(df_sev[predictors], function(x) all(is.na(x)), logical(1))]
predictors <- setdiff(predictors, all_na_cols)

prep <- list(
  train = train,
  test = test,
  target = TARGET,
  predictors = predictors
)

saveRDS(prep, file.path(OUTPUT_DIR, "prepared_data.rds"))

message("Preparation complete.")
message(sprintf("Rows - all: %s | severity>0: %s | train: %s | test: %s",
                nrow(df), nrow(df_sev), nrow(train), nrow(test)))
message(sprintf("Predictors selected: %s", length(predictors)))
