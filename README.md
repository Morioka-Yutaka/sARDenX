# sARDenX
sARDenX is an extension of sARDen, aiming to generate CDISC ARD (Analysis Results Data) from a wide range of SAS statistical analysis procedures.


<img width="360" height="360" alt="sARDenX_small" src="https://github.com/user-attachments/assets/dc81318f-e972-482e-bd6a-fa46423465b7" />


## `%sard_stats_t_test()` macro <a name="sardstatsttest-macro-2"></a> ######

### Purpose:  
  Performs a two-sample t-test using PROC TTEST and returns ARD-style results.  
  The macro outputs group means, confidence intervals, and test statistics  
  in a standardized long-format dataset.  

### Parameters:  
~~~text
  data      - Input dataset.
  class     - Grouping (classification) variable with two levels.
  var       - Numeric analysis variable.
  alpha     - Significance level for confidence intervals (default: 0.05).
  side      - Test type for PROC TTEST:
              2 = two-sided (default),
              L = one-sided lower-tail,
              U/R = one-sided upper-tail.
  h0        - Null hypothesis mean difference (default: 0).
  Welch     - Whether to use Welch/Satterthwaite method:
              Y = Welch t-test (default),
              N = Pooled-variance t-test.

Outputs:
  out       - Output dataset in ARD-style structure with:
              - estimate / conf.low / conf.high for each group mean
              - estimate1 / estimate2 for group-specific means
              - t statistic, degrees of freedom, p-value
              - method, alternative, conf.level, mu, var.equal, paired
~~~

### Notes:  
  - Assumes exactly two groups in &class.
  - One-sided direction depends on the ordering of CLASS levels in PROC TTEST.
  - Intermediate datasets are created in WORK and deleted at the end.

### Example:  
~~~sas
  %sard_stats_t_test(
    data=ADSL,
    out=sard_stats_t_test,
    class=TRT01PN,
    var=AGE,
    alpha=0.05,
    side=2,
    h0=0,
    Welch=Y
  );
~~~

<img width="1376" height="420" alt="image" src="https://github.com/user-attachments/assets/4b6384cb-17a8-42e8-92af-ce7a6b5f536f" />


---
