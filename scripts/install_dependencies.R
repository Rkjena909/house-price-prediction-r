packages <- c('caret', 'recipes', 'ggplot2', 'glmnet', 'ranger', 'gbm', 'kernlab', 'earth')
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly=TRUE)]
if (length(missing)) install.packages(missing, repos='https://cloud.r-project.org')

# Pin XGBoost to the API supported by this caret workflow.
if (!requireNamespace('xgboost',quietly=TRUE) || as.character(utils::packageVersion('xgboost')) != '1.7.8.1') install.packages('https://cran.r-project.org/src/contrib/Archive/xgboost/xgboost_1.7.8.1.tar.gz',repos=NULL,type='source')
