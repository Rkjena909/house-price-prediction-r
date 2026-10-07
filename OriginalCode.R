# Run from the repository root: Rscript OriginalCode.R [--quick]
args <- commandArgs(trailingOnly=TRUE)
quick <- '--quick' %in% args
required <- c('caret', 'recipes', 'ggplot2', 'glmnet', 'ranger', 'gbm', 'kernlab', 'earth')
missing <- required[!vapply(required, requireNamespace, logical(1), quietly=TRUE)]
if (length(missing)) stop('Missing packages: ', paste(missing, collapse=', '), '. Run scripts/install_dependencies.R')
suppressPackageStartupMessages(library(caret))
suppressPackageStartupMessages(library(recipes))
suppressPackageStartupMessages(library(ggplot2))
source('R/preprocess.R')
dir.create('results', showWarnings=FALSE)
train_raw <- read.csv('data/train.csv', stringsAsFactors=FALSE)
test_raw <- read.csv('data/test.csv', stringsAsFactors=FALSE)
stopifnot(nrow(train_raw)==1460, nrow(test_raw)==1459,
  !anyNA(train_raw$SalePrice), all(train_raw$SalePrice>0), !anyDuplicated(train_raw$Id))
set.seed(2026)
analysis_rows <- as.integer(createDataPartition(log1p(train_raw$SalePrice), p=0.8, list=FALSE))
holdout_rows <- setdiff(seq_len(nrow(train_raw)), analysis_rows)
# The holdout retains all records. Remove known extreme training cases only.
outliers <- train_raw$GrLivArea > 4000 & train_raw$SalePrice < 200000
fit_rows <- analysis_rows[!outliers[analysis_rows]]
make_data <- function(rows, engineered=TRUE) {
  d <- engineer_features(train_raw[rows, ], engineered)
  d$log_price <- log1p(train_raw$SalePrice[rows]); d
}
analysis <- make_data(fit_rows)
holdout <- make_data(holdout_rows)
set.seed(2026)
folds <- createFolds(analysis$log_price, k=5, returnTrain=TRUE)
control <- trainControl(method='cv', number=5, index=folds,
  savePredictions='final', allowParallel=FALSE)
rec <- make_recipe(analysis)
# Save the split and fold membership so evaluation can be reproduced.
write.csv(data.frame(Id=train_raw$Id, split=ifelse(seq_len(nrow(train_raw)) %in% holdout_rows,
 'holdout', ifelse(seq_len(nrow(train_raw)) %in% fit_rows, 'analysis', 'excluded_training_outlier'))),
 'results/split_manifest.csv', row.names=FALSE)
saveRDS(folds, 'results/cv_folds.rds')
specs <- list(
 Linear=list(method='lm', tuneGrid=data.frame(intercept=TRUE)),
 Ridge=list(method='glmnet', tuneGrid=expand.grid(alpha=0, lambda=c(.001,.01,.1))),
 Lasso=list(method='glmnet', tuneGrid=expand.grid(alpha=1, lambda=c(.001,.01,.1))),
 ElasticNet=list(method='glmnet', tuneGrid=expand.grid(alpha=c(.25,.5,.75), lambda=c(.001,.01,.1))),
 RandomForest=list(method='ranger', tuneGrid=expand.grid(mtry=c(15,30), splitrule='variance', min.node.size=c(3,8)), num.trees=300, num.threads=2, importance='permutation'),
 GradientBoosting=list(method='gbm', tuneGrid=expand.grid(n.trees=c(100,300), interaction.depth=c(1,3), shrinkage=.05, n.minobsinnode=10), verbose=FALSE),
 SVM=list(method='svmRadial', tuneGrid=expand.grid(sigma=c(.001,.01), C=c(1,10))),
 KNN=list(method='knn', tuneGrid=data.frame(k=c(3,5,9,15))),
 MARS=list(method='earth', tuneGrid=expand.grid(degree=c(1,2), nprune=c(10,20,30))))
if (quick) specs <- specs[c('Ridge','Lasso','ElasticNet','GradientBoosting')]
if (!quick) {
 specs$XGBoost <- list(method='xgbTree', tuneGrid=expand.grid(nrounds=c(150,300),
  max_depth=c(2,4), eta=.05, gamma=0, colsample_bytree=.8, min_child_weight=1, subsample=.8), nthread=2)
}
fits <- list(); failures <- list(); cv <- list(); hold <- list(); pred <- list()
for (nm in names(specs)) {
 message('Training ', nm)
 set.seed(2026)
 started <- Sys.time()

 model_recipe <- if (nm=='Linear') recipes::step_lincomb(rec,recipes::all_numeric_predictors()) else rec
 fit <- tryCatch(do.call(caret::train, c(list(x=model_recipe, data=analysis, metric='RMSE', trControl=control), specs[[nm]])), error=function(e)e)
 if (inherits(fit, 'error')) { failures[[nm]] <- conditionMessage(fit); next }
 fits[[nm]] <- fit
 oof <- best_predictions(fit)
 cv[[nm]] <- cbind(model=nm, price_metrics(oof$obs, oof$pred))
 pred[[nm]] <- as.numeric(predict(fit, newdata=holdout))
 hold[[nm]] <- cbind(model=nm, price_metrics(holdout$log_price, pred[[nm]]))
 saveRDS(fit, file.path('results', paste0(nm, '_model.rds')))
 write.csv(fit$results, file.path('results', paste0(nm, '_tuning.csv')), row.names=FALSE)
 message(nm, ' finished in ', round(as.numeric(difftime(Sys.time(),started,units='secs'))), ' seconds')
}
if (!length(fits)) stop('No model trained successfully')
if (all(c('ElasticNet','GradientBoosting') %in% names(fits))) {
 a <- best_predictions(fits$ElasticNet); b <- best_predictions(fits$GradientBoosting)
 stopifnot(identical(a$rowIndex,b$rowIndex), identical(a$Resample,b$Resample))
 blend <- function(x,y) log1p(.6*pmax(0,expm1(x)) + .4*pmax(0,expm1(y)))
 cv$WeightedEnsemble <- cbind(model='WeightedEnsemble', price_metrics(a$obs,blend(a$pred,b$pred)))
 pred$WeightedEnsemble <- blend(pred$ElasticNet,pred$GradientBoosting)
 hold$WeightedEnsemble <- cbind(model='WeightedEnsemble', price_metrics(holdout$log_price,pred$WeightedEnsemble))
}
cv_table <- do.call(rbind,cv); cv_table <- cv_table[order(cv_table$RMSE_log), ]; rownames(cv_table)<-NULL
hold_table <- do.call(rbind,hold); rownames(hold_table)<-NULL
write.csv(cv_table,'results/cv_metrics.csv',row.names=FALSE)
write.csv(hold_table,'results/holdout_metrics.csv',row.names=FALSE)
# Choose by analysis-set CV only. Holdout scores do not decide the winner.
winner <- cv_table$model[1]
actual <- train_raw$SalePrice[holdout_rows]
output <- data.frame(Id=train_raw$Id[holdout_rows], actual=actual)
for (nm in names(pred)) output[[nm]] <- pmax(0,expm1(pred[[nm]]))
write.csv(output,'results/holdout_predictions.csv',row.names=FALSE)
# Paired ablation isolates added domain features for one fixed model and split.
if ('Ridge' %in% names(fits)) {
 plain <- make_data(fit_rows,FALSE); plain_holdout <- make_data(holdout_rows,FALSE)
 set.seed(2026)
 base_fit <- do.call(caret::train,c(list(x=make_recipe(plain),data=plain,metric='RMSE',trControl=control),specs$Ridge))
 base_oof <- best_predictions(base_fit)
 impact <- rbind(cbind(configuration='without_added_features', evaluation='CV',price_metrics(base_oof$obs,base_oof$pred)),
  cbind(configuration='with_added_features',evaluation='CV',cv$Ridge[, -1,drop=FALSE]),
  cbind(configuration='without_added_features',evaluation='holdout',price_metrics(plain_holdout$log_price,as.numeric(predict(base_fit,newdata=plain_holdout)))),
  cbind(configuration='with_added_features',evaluation='holdout',hold$Ridge[,-1,drop=FALSE]))
 write.csv(impact,'results/feature_engineering_impact.csv',row.names=FALSE)
}
# Refit the CV-selected configuration on all labeled, non-outlier records for test predictions.
full_rows <- which(!outliers)
full <- make_data(full_rows)
new_test <- engineer_features(test_raw)
refit <- function(nm) {
 s <- specs[[nm]]; s$tuneGrid <- fits[[nm]]$bestTune
 set.seed(2026)
 final_recipe <- make_recipe(full)
 if (nm=='Linear') final_recipe <- recipes::step_lincomb(final_recipe,recipes::all_numeric_predictors())
 do.call(caret::train,c(list(x=final_recipe,data=full,metric='RMSE',trControl=trainControl(method='none')),s))
}
if (winner=='WeightedEnsemble') {
 final_a <- refit('ElasticNet'); final_b <- refit('GradientBoosting')
 test_pred <- .6*pmax(0,expm1(predict(final_a,newdata=new_test))) + .4*pmax(0,expm1(predict(final_b,newdata=new_test)))
 saveRDS(list(ElasticNet=final_a,GradientBoosting=final_b,weights=c(.6,.4)),'results/final_model.rds')
} else {
 final <- refit(winner); test_pred <- pmax(0,expm1(predict(final,newdata=new_test)))
 saveRDS(final,'results/final_model.rds')
}
stopifnot(length(test_pred)==nrow(test_raw),all(is.finite(test_pred)),all(test_pred>0))
write.csv(data.frame(Id=test_raw$Id,SalePrice=as.numeric(test_pred)),'results/test_predictions.csv',row.names=FALSE)
source('scripts/make_plots.R')
writeLines(c(paste('Run completed:',Sys.time()),paste('Mode:',ifelse(quick,'quick','full')),paste('CV-selected model:',winner),
 paste('Analysis records:',nrow(analysis)),paste('Holdout records:',nrow(holdout)),paste('Removed analysis outliers:',length(analysis_rows)-length(fit_rows)),
 paste('Successful models:',paste(names(fits),collapse=', ')),paste('XGBoost installed:',requireNamespace('xgboost',quietly=TRUE)),
 'Test records are unlabeled: test_predictions.csv has no measured test score.'),'results/run_summary.txt')
writeLines(capture.output(sessionInfo()),'results/session_info.txt')
if (!length(failures) && file.exists('results/model_failures.txt')) unlink('results/model_failures.txt')
if (length(failures)) writeLines(paste(names(failures),unlist(failures),sep=': '),'results/model_failures.txt')
source('scripts/build_report.R')
print(cv_table); print(hold_table); message('Outputs saved under results/')
