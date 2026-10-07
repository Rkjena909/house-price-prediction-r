# Build a Markdown results report from actual saved model outputs.
cv <- read.csv('results/cv_metrics.csv',stringsAsFactors=FALSE)
hold <- read.csv('results/holdout_metrics.csv',stringsAsFactors=FALSE)
impact <- read.csv('results/feature_engineering_impact.csv',stringsAsFactors=FALSE)
winner <- cv$model[1]
chosen <- hold[hold$model==winner,]
markdown <- function(d,digits=4) {
 for(nm in names(d)) if(is.numeric(d[[nm]])) d[[nm]] <- format(round(d[[nm]],digits),trim=TRUE,scientific=FALSE)
 lines <- c(paste0('| ',paste(names(d),collapse=' | '),' |'),paste0('| ',paste(rep('---',ncol(d)),collapse=' | '),' |'))
 c(lines,apply(d,1,function(r)paste0('| ',paste(r,collapse=' | '),' |')))
}
cv_base <- impact$RMSE_log[impact$configuration=='without_added_features' & impact$evaluation=='CV']
cv_added <- impact$RMSE_log[impact$configuration=='with_added_features' & impact$evaluation=='CV']
hold_base <- impact$RMSE_log[impact$configuration=='without_added_features' & impact$evaluation=='holdout']
hold_added <- impact$RMSE_log[impact$configuration=='with_added_features' & impact$evaluation=='holdout']
manifest <- read.csv('results/split_manifest.csv')
report <- c('# Verified run results','',
 paste('CV-selected model:',winner),
 paste('Analysis records:',sum(manifest$split=='analysis')),
 paste('Holdout records:',sum(manifest$split=='holdout')),
 paste('Training outliers excluded:',sum(manifest$split=='excluded_training_outlier')),
 'Test prediction records: 1,459 (unlabeled).','',
 '## Cross-validation comparison','',
 'These are pooled out-of-fold metrics on the analysis set. Hyperparameter selection also uses those folds; CV scores are selection estimates, not an independent final assessment. Lower RMSE/MAE is better. R2_dollars is a coefficient of determination, not classification accuracy.','',markdown(cv),'',
 '![Cross-validation model comparison](model_comparison.png)','',
 '## Independent holdout','',
 paste0('The model selected by CV achieved log-price RMSE ',round(chosen$RMSE_log,4),
 ', dollar MAE $',format(round(chosen$MAE_dollars),big.mark=','),
 ', dollar RMSE $',format(round(chosen$RMSE_dollars),big.mark=','),
 ', and dollar R² ',round(chosen$R2_dollars,4),'.'),'',
 'The following table is diagnostic; the holdout scores were not used to choose the final model.','',markdown(hold),'',
 '![Actual versus predicted](actual_vs_predicted.png)','',
 '![Holdout residuals](residuals.png)','',
 '## Measured feature-engineering impact','',
 'The paired comparison uses Ridge, the same split, and identical fold assignments. The added group consists of total area, bathroom count, porch area, remodeling status, years since remodeling, property age, and new-construction status.','',markdown(impact),'',
 paste0('Adding these features changed log-price CV RMSE by ',round(100*(cv_added/cv_base-1),2),
 '% and log-price holdout RMSE by ',round(100*(hold_added/hold_base-1),2),
 '%. A negative change is an improvement; a positive change is a decline.'),'',
 'The observed effect is mixed. It does not establish a generalization improvement, and the default features were not changed after seeing holdout results.','',
 '## Prediction and output files','',
 '`test_predictions.csv` contains Id and SalePrice for all supplied test records, in original row order. It has no measured test-set accuracy because labels are unavailable. `holdout_predictions.csv` includes the observed prices and every evaluated model prediction. Fitted model objects and `session_info.txt` are included for reproducibility.','',
 '![Training-data missing values](missing_values.png)','',
 '## Limitations','',
 'This is one seeded split with a limited tuning grid. Rare property types and large residuals can influence dollar RMSE. No competition score, production performance, or confidence interval is claimed. The log-to-dollar conversion is not a bias correction for conditional mean prices.')
if(file.exists('results/largest_holdout_errors.csv')) {
 largest <- read.csv('results/largest_holdout_errors.csv')
 report <- c(report,'','## Largest holdout errors','',
  paste0('The largest error is on property Id ',largest$Id[1],': actual $',format(round(largest$actual[1]),big.mark=','),
   ' versus predicted $',format(round(largest$predicted[1]),big.mark=','),
   '. This record remains in the primary holdout evaluation; it was not removed to improve the reported score.'),'',markdown(head(largest,5),digits=0))
}
if(file.exists('results/feature_importance.png')) report <- c(report,'','## Variable importance','','This is model-specific predictive importance, not causal evidence.','','![Variable importance](feature_importance.png)')
writeLines(report,'results/REPORT.md')
cat('Results report generated\n')
