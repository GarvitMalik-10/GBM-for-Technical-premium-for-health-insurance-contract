source("00_config.R")

suppressPackageStartupMessages({
  library(dplyr)
})

prep <- readRDS(file.path(OUTPUT_DIR, "prepared_data.rds"))
train <- prep$train
test <- prep$test
target <- prep$target
predictors <- prep$predictors

glm_formula <- as.formula(
  paste(target, "~", paste(predictors, collapse = " + "))
)

message("Fitting Gamma GLM with log link...")
gamma_glm <- glm(
  formula = glm_formula,
  data = train,
  family = Gamma(link = "log")
)

pred <- predict(gamma_glm, newdata = test, type = "response")
actual <- test[[target]]

mae <- mean(abs(actual - pred), na.rm = TRUE)
rmse <- sqrt(mean((actual - pred)^2, na.rm = TRUE))

metrics <- data.frame(
  model = "gamma_glm",
  MAE = mae,
  RMSE = rmse
)

write.csv(metrics, file.path(OUTPUT_DIR, "metrics_gamma_glm.csv"), row.names = FALSE)
saveRDS(gamma_glm, file.path(OUTPUT_DIR, "model_gamma_glm.rds"))
saveRDS(data.frame(actual = actual, pred_gamma_glm = pred), file.path(OUTPUT_DIR, "pred_gamma_glm.rds"))

message("Gamma GLM complete.")
print(metrics)
