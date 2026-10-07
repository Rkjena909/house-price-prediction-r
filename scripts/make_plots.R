suppressPackageStartupMessages(library(ggplot2))
cv_table <- read.csv('results/cv_metrics.csv',stringsAsFactors=FALSE)
output <- read.csv('results/holdout_predictions.csv')
winner <- cv_table$model[1]
style <- theme_minimal(base_size=12) + theme(plot.background=element_rect(fill='white',colour=NA),panel.grid.minor=element_blank(),text=element_text(colour='#111827'),plot.title=element_text(face='bold'))
save_plot <- function(name,p,width=8,height=5) ggsave(file.path('results',name),p,width=width,height=height,dpi=160,bg='white')
p <- ggplot(cv_table,aes(x=reorder(model,-RMSE_log),y=RMSE_log)) + geom_col(fill='#2563eb') + coord_flip() + labs(title='Five-fold cross-validation',subtitle='Pooled out-of-fold error; lower is better',x=NULL,y='RMSE on log1p(price)') + style
save_plot('model_comparison.png',p,9,6)
diagnostic <- data.frame(Id=output$Id,actual=output$actual,predicted=output[[winner]])
p <- ggplot(diagnostic,aes(actual,predicted)) + geom_point(alpha=.65,color='#2563eb') + geom_abline(slope=1,intercept=0,linetype=2) + scale_x_continuous(labels=scales::label_number(big.mark=',')) + scale_y_continuous(labels=scales::label_number(big.mark=',')) + labs(title=paste(winner,'— independent holdout'),subtitle=paste(nrow(diagnostic),'records; dashed line represents perfect predictions'),x='Actual sale price ($)',y='Predicted sale price ($)') + style
save_plot('actual_vs_predicted.png',p,8,6)
p <- ggplot(diagnostic,aes(predicted,actual-predicted)) + geom_point(alpha=.65,color='#7c3aed') + geom_hline(yintercept=0,linetype=2) + scale_x_continuous(labels=scales::label_number(big.mark=',')) + scale_y_continuous(labels=scales::label_number(big.mark=',')) + labs(title='Independent holdout residuals',x='Predicted sale price ($)',y='Actual minus predicted ($)') + style
save_plot('residuals.png',p,8,6)
raw <- read.csv('data/train.csv',stringsAsFactors=FALSE)
missingness <- data.frame(feature=names(raw),missing=colSums(is.na(raw)))
missingness <- head(missingness[order(-missingness$missing),],15)
p <- ggplot(missingness,aes(reorder(feature,missing),missing)) + geom_col(fill='#0d9488') + coord_flip() + labs(title='Missing values in original training data',x=NULL,y='Records') + style
save_plot('missing_values.png',p,8,6)
importance_model <- cv_table$model[cv_table$model!='WeightedEnsemble'][1]
fit <- readRDS(file.path('results',paste0(importance_model,'_model.rds')))
importance <- tryCatch(caret::varImp(fit,scale=TRUE)$importance,error=function(e)NULL)
if(!is.null(importance) && 'Overall' %in% names(importance)) {
 importance$feature <- rownames(importance)
 importance <- importance[order(-importance$Overall),c('feature','Overall')]
 write.csv(importance,'results/feature_importance.csv',row.names=FALSE)
 top <- head(importance,15)
 p <- ggplot(top,aes(reorder(feature,Overall),Overall)) + geom_col(fill='#db2777') + coord_flip() + labs(title=paste('Variable importance —',importance_model),subtitle='Predictive association, not causal evidence',x=NULL,y='Scaled importance') + style
 save_plot('feature_importance.png',p,9,6)
}
diagnostic$error_dollars <- diagnostic$actual-diagnostic$predicted
diagnostic <- diagnostic[order(-abs(diagnostic$error_dollars)),]
write.csv(head(diagnostic,10),'results/largest_holdout_errors.csv',row.names=FALSE)
cat('Five plots and error diagnostics generated\n')
