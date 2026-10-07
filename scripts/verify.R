suppressPackageStartupMessages(library(recipes))
source('R/preprocess.R')
raw <- read.csv('data/train.csv',stringsAsFactors=FALSE)
test <- read.csv('data/test.csv',stringsAsFactors=FALSE)
a <- engineer_features(raw[1:100,]); a$log_price <- log1p(raw$SalePrice[1:100])
stopifnot(!('Id' %in% names(a)),!('SalePrice' %in% names(a)),all(c('TotalSF','PropertyAge','YearsSinceRemodel','TotBathrooms') %in% names(a)))
stopifnot(isTRUE(all.equal(expm1(log1p(raw$SalePrice)),raw$SalePrice)))
# Preprocessing is fitted on analysis data only; novel holdout categories must bake.
p <- prep(make_recipe(a),training=a)
b <- engineer_features(test[1:20,]); b$Neighborhood[1] <- 'NEVER_SEEN_NEIGHBORHOOD'
baked <- bake(p,new_data=b)
stopifnot(nrow(baked)==20,all(vapply(baked,is.numeric,logical(1))),!anyNA(baked),all(is.finite(as.matrix(baked))))
z <- price_metrics(log1p(c(100,200,300)),log1p(c(100,200,300)))
stopifnot(z$RMSE_log==0,z$RMSE_dollars==0,z$MAE_dollars==0,z$R2_dollars==1)
if(file.exists('results/test_predictions.csv')) {
 out <- read.csv('results/test_predictions.csv')
 stopifnot(identical(names(out),c('Id','SalePrice')),nrow(out)==nrow(test),identical(out$Id,test$Id),all(is.finite(out$SalePrice)),all(out$SalePrice>0))
 manifest <- read.csv('results/split_manifest.csv')
 stopifnot(nrow(manifest)==nrow(raw),!anyDuplicated(manifest$Id),sum(manifest$split=='holdout')>0)
 cv <- read.csv('results/cv_metrics.csv'); hold <- read.csv('results/holdout_metrics.csv')
 stopifnot(!anyNA(cv),!anyNA(hold),setequal(cv$model,hold$model))
}
if(file.exists('results/cv_folds.rds')) {
 folds <- readRDS('results/cv_folds.rds')
 files <- list.files('results',pattern='^[A-Z].*_model[.]rds$',full.names=TRUE)
 for(path in files) {
  fit <- readRDS(path)
  stopifnot(identical(fit$control$index,folds))
  oof <- best_predictions(fit)
  stopifnot(nrow(oof)==nrow(fit$trainingData),!anyDuplicated(oof$rowIndex),all(is.finite(oof$pred)))
 }
 if(file.exists('results/holdout_predictions.csv')) {
  hp <- read.csv('results/holdout_predictions.csv')
  if(all(c('Ridge','Lasso') %in% names(hp))) stopifnot(!isTRUE(all.equal(hp$Ridge,hp$Lasso)))
 }
}
cat('PASS: feature transformations, price inversion, unseen categories, finite baked predictors, metrics, and available outputs\n')
