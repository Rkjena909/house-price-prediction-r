# Row-wise domain transformations only. Learned preprocessing belongs in recipes.
engineer_features <- function(raw, engineered = TRUE) {
  d <- raw
  d$Id <- NULL
  d$SalePrice <- NULL
  d$MSSubClass <- as.character(d$MSSubClass)
  d$MoSold <- as.character(d$MoSold)
  absent <- intersect(c('PoolQC', 'MiscFeature', 'Alley', 'Fence', 'FireplaceQu',
    'GarageCond', 'GarageFinish', 'GarageQual', 'GarageType', 'BsmtCond',
    'BsmtExposure', 'BsmtQual', 'BsmtFinType1', 'BsmtFinType2'), names(d))
  for (nm in absent) d[[nm]][is.na(d[[nm]])] <- 'None'
  quality <- c(None=0, Po=1, Fa=2, TA=3, Gd=4, Ex=5)
  maps <- list(ExterQual=quality, ExterCond=quality, BsmtQual=quality,
    BsmtCond=quality, HeatingQC=quality, KitchenQual=quality,
    FireplaceQu=quality, GarageQual=quality, GarageCond=quality, PoolQC=quality,
    BsmtExposure=c(None=0, No=1, Mn=2, Av=3, Gd=4),
    BsmtFinType1=c(None=0, Unf=1, LwQ=2, Rec=3, BLQ=4, ALQ=5, GLQ=6),
    BsmtFinType2=c(None=0, Unf=1, LwQ=2, Rec=3, BLQ=4, ALQ=5, GLQ=6),
    GarageFinish=c(None=0, Unf=1, RFn=2, Fin=3),
    Fence=c(None=0, MnWw=1, GdWo=2, MnPrv=3, GdPrv=4),
    Functional=c(Sal=0, Sev=1, Maj2=2, Maj1=3, Mod=4, Min2=5, Min1=6, Typ=7))
  for (nm in names(maps)) d[[nm]] <- unname(maps[[nm]][as.character(d[[nm]])])
  zero <- intersect(c('MasVnrArea', 'BsmtFullBath', 'BsmtHalfBath', 'BsmtFinSF1',
    'BsmtFinSF2', 'BsmtUnfSF', 'TotalBsmtSF', 'GarageCars', 'GarageArea'), names(d))
  for (nm in zero) d[[nm]][is.na(d[[nm]])] <- 0
  missing_year <- is.na(d$GarageYrBlt)
  d$GarageYrBlt[missing_year] <- d$YearBuilt[missing_year]
  # Known typographical year is capped by sale year, a per-row constraint.
  d$GarageYrBlt <- pmin(d$GarageYrBlt, d$YrSold)
  if (engineered) {
    d$TotalSF <- d$TotalBsmtSF + d$X1stFlrSF + d$X2ndFlrSF
    d$TotBathrooms <- d$FullBath + 0.5*d$HalfBath + d$BsmtFullBath + 0.5*d$BsmtHalfBath
    d$Remod <- as.integer(d$YearBuilt != d$YearRemodAdd)
    d$YearsSinceRemodel <- pmax(0, d$YrSold - d$YearRemodAdd)
    d$PropertyAge <- pmax(0, d$YrSold - d$YearBuilt)
    d$IsNew <- as.integer(d$YrSold == d$YearBuilt)
    d$TotalPorchSF <- d$OpenPorchSF + d$EnclosedPorch + d$X3SsnPorch + d$ScreenPorch
  }
  d
}

make_recipe <- function(d) {
  recipes::recipe(log_price ~ ., data=d) |>
    recipes::step_novel(recipes::all_nominal_predictors(), new_level='novel') |>
    recipes::step_unknown(recipes::all_nominal_predictors(), new_level='missing') |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_YeoJohnson(recipes::all_numeric_predictors(), num_unique=10) |>
    recipes::step_dummy(recipes::all_nominal_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())
}

price_metrics <- function(observed_log, predicted_log) {
  observed <- expm1(observed_log)
  predicted <- pmax(0, expm1(predicted_log))
  data.frame(RMSE_log=sqrt(mean((predicted_log-observed_log)^2)),
    MAE_log=mean(abs(predicted_log-observed_log)),
    RMSE_dollars=sqrt(mean((predicted-observed)^2)),
    MAE_dollars=mean(abs(predicted-observed)),
    R2_dollars=1-sum((predicted-observed)^2)/sum((observed-mean(observed))^2))
}

best_predictions <- function(fit) {
  p <- fit$pred
  for (nm in names(fit$bestTune)) p <- p[p[[nm]] == fit$bestTune[[nm]][1], , drop=FALSE]
  p[order(p$rowIndex), , drop=FALSE]
}
