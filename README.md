# House Price Prediction with Regression Models in R

This project explores residential house-price prediction using structured property data. It combines data preprocessing, feature engineering, regression modeling, and weighted ensembling to compare predictive performance.

The focus is on reproducible model comparison and evaluating how well predictions generalize to unseen properties.

---

## Motivation

Residential sale prices depend on characteristics such as property size, construction quality, neighborhood, and remodeling history.

This project investigates how different regression approaches capture these relationships and whether engineered property features improve predictions.

---

## Dataset

| Dataset | Records | Description |
|---|---:|---|
| Training | 1,460 | Property characteristics and observed sale prices |
| Test | 1,459 | Property characteristics without sale-price labels |

The labeled data is partitioned into:

- **1,168 analysis records** for model training and cross-validation.
- **291 holdout records** for independent evaluation.
- **One analysis-set outlier excluded** using a predefined rule.

The holdout retains all its assigned records.

---

## Project Structure

| File or folder | Purpose |
|---|---|
| `OriginalCode.R` | Training, evaluation, ensemble construction, and prediction workflow |
| `R/preprocess.R` | Feature engineering and preprocessing functions |
| `scripts/` | Dependency installation, verification, plots, and report generation |
| `data/` | Training and test datasets |
| `results/` | Metrics, predictions, plots, and experiment report |
| `README.md` | Project overview and execution instructions |

---

## Experiments

### 1. Data Preprocessing

The workflow includes missing-value handling, ordinal encoding, dummy encoding for categorical predictors, Yeo–Johnson transformations, numerical scaling, zero-variance predictor removal, and log transformation of sale prices.

Learned preprocessing is fitted within each cross-validation training fold.

### 2. Feature Engineering

Engineered features include total square footage, bathroom count, porch area, property age, years since remodeling, remodeling status, and new-construction status.

### 3. Regression Model Comparison

Ten models are evaluated using shared five-fold cross-validation:

**Linear Regression, Ridge, Lasso, Elastic Net, Random Forest, Gradient Boosting, XGBoost, SVM, KNN, and MARS.**

### 4. Weighted Ensemble

A fixed ensemble combines **60% Elastic Net** and **40% Gradient Boosting** dollar predictions.

The final model is selected using cross-validation log-price RMSE.

---

## Results

The weighted ensemble achieved the lowest cross-validation log-price RMSE.

| Metric | Cross-validation | Independent holdout |
|---|---:|---:|
| Log-price RMSE | 0.1121 | 0.1392 |
| Mean absolute error in dollars | $13,814 | $14,634 |
| RMSE in dollars | $21,984 | $36,117 |
| R² on dollar prices | 0.9224 | 0.8039 |

![Cross-validation model comparison](results/model_comparison.png)

Additional visualizations show [actual versus predicted prices](results/actual_vs_predicted.png), [residuals](results/residuals.png), [missing values](results/missing_values.png), and [variable importance](results/feature_importance.png).

See the [experiment report](results/REPORT.md) for complete comparisons and the largest prediction errors.

---

## Key Findings

- The weighted ensemble performed best under the cross-validation selection criterion.
- Added features produced mixed results: Ridge's cross-validation RMSE improved slightly, while its holdout RMSE worsened slightly.
- Some unusual properties produced large prediction errors.
- Performance depends on the evaluation metric: XGBoost achieved a lower holdout log-price RMSE than the ensemble, while the ensemble achieved a lower holdout dollar MAE.

---

## What We Achieved

- Built and executed a reproducible R workflow covering preprocessing, feature engineering, training, evaluation, and prediction.
- Compared **10 regression models and one weighted ensemble** using shared five-fold cross-validation.
- Selected the ensemble through cross-validation and measured its performance on **291 independent holdout records**.
- Generated **1,459 test predictions**, comparison tables, and five visualizations.
- Measured the effect of engineered features and documented both benefits and limitations.

---

## Running the Project

Requires R 4.3 or newer. Run these commands from the repository root:

```bash
Rscript scripts/install_dependencies.R
Rscript scripts/verify.R
Rscript OriginalCode.R
Rscript scripts/verify.R
```

`Rscript OriginalCode.R --quick` runs the regularized models and Gradient Boosting for a smaller experiment. XGBoost is pinned to 1.7.8.1 for compatibility with this caret workflow; installing it from source requires a compiler toolchain (Rtools on Windows).

---

## Outputs

The project generates model comparison tables, holdout predictions, **1,459 test predictions**, five visualizations, and a detailed results report. Fitted models are generated locally when the workflow is run.

## Limitations and Future Work

The test dataset has no price labels, so no test accuracy is claimed. Results reflect one holdout split and a limited parameter search.

Future work could examine repeated validation, robust treatment of unusual properties, and alternative ensemble strategies.

---

## Conclusion

The weighted ensemble achieved the lowest cross-validation log-price RMSE of **0.1121**. On the independent holdout, it achieved a log-price RMSE of **0.1392** and a mean absolute error of **$14,634**.

The experiments showed that model rankings depend on the evaluation metric and that adding domain features does not automatically improve generalization. Large errors on unusual properties remain a limitation. The project delivers a reproducible benchmark workflow and documented predictions, with further work needed on robustness and repeated validation.
