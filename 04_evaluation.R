source("00_config.R")

suppressPackageStartupMessages({
  library(dplyr)
})

pred_glm <- readRDS(file.path(OUTPUT_DIR, "pred_gamma_glm.rds"))
pred_gbm <- readRDS(file.path(OUTPUT_DIR, "pred_gbm_gamma.rds"))

eval_df <- pred_glm %>%
  inner_join(pred_gbm, by = "actual")

mae <- function(y, p) mean(abs(y - p), na.rm = TRUE)
rmse <- function(y, p) sqrt(mean((y - p)^2, na.rm = TRUE))

results <- data.frame(
  model = c("gamma_glm", "gbm_gamma"),
  MAE = c(mae(eval_df$actual, eval_df$pred_gamma_glm), mae(eval_df$actual, eval_df$pred_gbm_gamma)),
  RMSE = c(rmse(eval_df$actual, eval_df$pred_gamma_glm), rmse(eval_df$actual, eval_df$pred_gbm_gamma))
)

# Calibration by prediction deciles (for both models)
calibration_table <- function(actual, pred, model_name, n_groups = 10) {
  tmp <- data.frame(actual = actual, pred = pred)
  tmp <- tmp %>% mutate(decile = ntile(pred, n_groups))
  tmp %>%
    group_by(decile) %>%
    summarise(
      n = n(),
      avg_actual = mean(actual, na.rm = TRUE),
      avg_pred = mean(pred, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(model = model_name) %>%
    select(model, everything())
}

cal_glm <- calibration_table(eval_df$actual, eval_df$pred_gamma_glm, "gamma_glm")
cal_gbm <- calibration_table(eval_df$actual, eval_df$pred_gbm_gamma, "gbm_gamma")
cal <- bind_rows(cal_glm, cal_gbm)

write.csv(results, file.path(OUTPUT_DIR, "model_comparison.csv"), row.names = FALSE)
write.csv(cal, file.path(OUTPUT_DIR, "calibration_by_decile.csv"), row.names = FALSE)

message("Evaluation complete.")
print(results)
