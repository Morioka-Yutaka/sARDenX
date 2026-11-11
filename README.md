# sARDenX
sARDenX is an extension of sARDen, aiming to generate CDISC ARD (Analysis Results Data) from a wide range of SAS statistical analysis procedures.


<img width="360" height="360" alt="sARDenX_small" src="https://github.com/user-attachments/assets/dc81318f-e972-482e-bd6a-fa46423465b7" />

## Test Data
We use ADSL and ADAE created as test data with the “sas_faker” package (https://github.com/Morioka-Yutaka/sas_faker),   
but you can freely substitute typical ADSL/ADAE datasets instead, so feel free to adapt that part as you like.
~~~sas
%loadPackage(sas_faker)
%sas_faker(
n_groups=3, 
n_per_group=50,
output_lib=WORK,
seed =123456,
create_dm = N,
create_ae = N,
create_sv =  N,
create_vs = N,
create_adsl = Y,
create_adae = Y,
create_advs = N
);
~~~~
[ADSL]  
<img width="767" height="176" alt="image" src="https://github.com/user-attachments/assets/af49ad5f-15c6-4156-ba91-ee336cb86317" />  
[ADAE]  
<img width="758" height="235" alt="image" src="https://github.com/user-attachments/assets/1a0beab0-c842-4124-ac21-2fa284a642a8" />  

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

### Usage Example:  
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

## `%sard_stats_fisher_test()` macro <a name="sardstatsfishertest-macro-1"></a> ######

### Purpose:
  Performs Fisher's exact test for a 2x2 (or RxC) contingency table by  
  aggregating counts and calling PROC FREQ with the FISHER option.  
  The macro returns ARD-style p-value and method/alternative metadata.  

### Inputs:  
~~~text
  data      - Input dataset.
  classdata - Optional CLASSDATA= dataset for PROC SUMMARY (formats/order).
  group     - Row (grouping) variable for the contingency table.
  var       - Column (categorical) variable for the contingency table.
  side      - Alternative hypothesis:
              2 or B = two-sided (default),
              L      = one-sided (lower/left tail),
              U or R = one-sided (upper/right tail).
~~~

### Outputs:
  out       - Output dataset in ARD-style structure with:
              - method (Fisher's Exact Test)
              - alternative (two.sided / less / greater)
              - p.value (exact Fisher p-value)

### Notes:
  - The meaning of "less" and "greater" depends on the ordering of
    levels in &group and &var as used in TABLES &group * &var.
  - Missing values in &group or &var are excluded unless PROC SUMMARY
    is modified with MISSING.
  - Intermediate datasets are created in WORK and deleted at the end.

### Usage Example:
~~~sas
  %sard_stats_fisher_test(
    data=ADSL,
    out=sard_stats_fisher_test,
    group=TRT01PN,
    var=SEX,
    side=2
  );
~~~

<img width="1506" height="154" alt="image" src="https://github.com/user-attachments/assets/23da4f9a-f27e-4c37-bbc6-4b2a20ef269a" />


---

## `%sard_stats_wilcox_test()` macro <a name="sardstatswilcoxtest-macro-3"></a> ######

### Purpose:
  Performs a two-sample Wilcoxon rank-sum test using PROC NPAR1WAY
  and returns ARD-style results aligned with cardx conventions.

  The macro additionally requests Hodges-Lehmann estimation of the
  location shift and its confidence interval.

### Inputs:
~~~text
  data      - Input dataset.
  out       - Output ARD-style dataset.
                Default: sard_stats_wilcox_test
  class     - Grouping variable. Must contain exactly two non-missing levels.
  var       - Numeric analysis variable.
  side      - Alternative hypothesis:
                2   = two-sided (default)
                L   = one-sided lower-tail
                U/R = one-sided upper-tail
  exact     - Whether to calculate exact Wilcoxon p-values and exact
                Hodges-Lehmann confidence limits:
                Y = exact inference
                N = asymptotic inference (default)
  correct   - Whether to use the continuity correction for asymptotic
                Wilcoxon p-values:
                Y = use correction (default)
                N = do not use correction
  alpha     - Significance level for Hodges-Lehmann confidence limits.
                Default: 0.05, corresponding to a 95% confidence interval.
~~~
### Outputs:
~~~text
  out       - Long-format ARD-style dataset containing:
                statistic    - Wilcoxon W statistic, calculated from the
                               rank sum of the first sorted CLASS level
                p.value      - Wilcoxon p-value
                method       - Test method
                alternative  - Alternative hypothesis
                exact        - Whether exact inference was requested
                mu           - Null location shift (0)
                correct      - Continuity-correction indicator
                estimate     - Hodges-Lehmann location-shift estimate
                conf.low     - Lower confidence limit for the location shift
                conf.high    - Upper confidence limit for the location shift
                conf.level   - Confidence level
~~~
### Notes:
  - Missing CLASS and VAR values are excluded from the analysis.
  - The macro requires exactly two non-missing CLASS levels.
  - The returned statistic is converted to the R/cardx-style W statistic:
      W = rank-sum(Group 1) - n1 * (n1 + 1) / 2
    where Group 1 is the first sorted level of CLASS.
  - PROC NPAR1WAY's Hodges-Lehmann estimate and one-sided p-values follow
    SAS CLASS-level and reference-group conventions. Their direction is not
    internally reversed to mimic R factor-level conventions.
  - When EXACT=Y, the macro requests exact Wilcoxon p-values and exact
    Hodges-Lehmann confidence limits via:
      EXACT WILCOXON HL;
  - Intermediate WORK datasets are deleted at completion.

Example:
~~~sas
%sard_stats_wilcox_test(
  data        = adsl,
  out         = sard_wilcox_test,
  class       = SEX,
  var         = AGE,
  side = 2,
  exact       = N,
  correct     = Y,
  alpha       = 0.05
);
~~~

<img width="1334" height="364" alt="image" src="https://github.com/user-attachments/assets/917848dd-6b36-47fc-b405-ed266864d51b" />


---

# version history<br>
0.1.1(11November2026): Add Wilcoxon rank-sum test <br>
0.1.0(03December2025): Initial version<br>

## What is SAS Packages?

The package is built on top of **SAS Packages Framework(SPF)** developed by Bartosz Jablonski.

For more information about the framework, see [SAS Packages Framework](https://github.com/yabwon/SAS_PACKAGES).

You can also find more SAS Packages (SASPacs) in the [SAS Packages Archive(SASPAC)](https://github.com/SASPAC).

## How to use SAS Packages? (quick start)

### 1. Set-up SAS Packages Framework

First, create a directory for your packages and assign a `packages` fileref to it.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~sas
filename packages "\path\to\your\packages";
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Secondly, enable the SAS Packages Framework.
(If you don't have SAS Packages Framework installed, follow the instruction in 
[SPF documentation](https://github.com/yabwon/SAS_PACKAGES/tree/main/SPF/Documentation) 
to install SAS Packages Framework.)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~sas
%include packages(SPFinit.sas)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


### 2. Install SAS package

Install SAS package you want to use with the SPF's `%installPackage()` macro.

- For packages located in **SAS Packages Archive(SASPAC)** run:
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~sas
  %installPackage(packageName)
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- For packages located in **PharmaForest** run:
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~sas
  %installPackage(packageName, mirror=PharmaForest)
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- For packages located at some network location run:
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~sas
  %installPackage(packageName, sourcePath=https://some/internet/location/for/packages)
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  (e.g. `%installPackage(ABC, sourcePath=https://github.com/SomeRepo/ABC/raw/main/)`)


### 3. Load SAS package

Load SAS package you want to use with the SPF's `%loadPackage()` macro.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~sas
%loadPackage(packageName)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


### Enjoy!
<img width="1512" height="152" alt="image" src="https://github.com/user-attachments/assets/f1c707b2-c592-4c47-8445-565acd2914e9" />



---
