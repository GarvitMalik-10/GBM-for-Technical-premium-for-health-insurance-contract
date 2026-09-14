source("00_config.R")

suppressPackageStartupMessages({
  library(gbm)
})

prep <- readRDS(file.path(OUTPUT_DIR, "prepared_data.rds"))
train <- prep$train
test <- prep$test
target <- prep$target
predictors <- prep$predictors

gbm_formula <- as.formula(
  paste(target, "~", paste(predictors, collapse = " + "))
)

message("Fitting GBM (Gamma distribution) with CV...")
set.seed(42)
gbm_gamma <- gbm(
  formula = gbm_formula,
  data = train,
  distribution = "gamma",
  n.trees = 3000,
  interaction.depth = 3,
  shrinkage = 0.01,
  n.minobsinnode = 100,
  bag.fraction = 0.7,
  cv.folds = 5,
  train.fraction = 1.0,
  verbose = FALSE
)

best_iter <- gbm.perf(gbm_gamma, method = "cv", plot.it = FALSE)

pred <- predict(gbm_gamma, newdata = test, n.trees = best_iter, type = "response")
actual <- test[[target]]

mae <- mean(abs(actual - pred), na.rm = TRUE)
rmse <- sqrt(mean((actual - pred)^2, na.rm = TRUE))

metrics <- data.frame(
  model = "gbm_gamma",
  best_trees = best_iter,
  MAE = mae,
  RMSE = rmse
)

write.csv(metrics, file.path(OUTPUT_DIR, "metrics_gbm_gamma.csv"), row.names = FALSE)
saveRDS(gbm_gamma, file.path(OUTPUT_DIR, "model_gbm_gamma.rds"))
saveRDS(data.frame(actual = actual, pred_gbm_gamma = pred), file.path(OUTPUT_DIR, "pred_gbm_gamma.rds"))

vi <- summary(gbm_gamma, n.trees = best_iter, plotit = FALSE)
write.csv(vi, file.path(OUTPUT_DIR, "gbm_variable_importance.csv"), row.names = FALSE)

message("GBM complete.")
print(metrics)
