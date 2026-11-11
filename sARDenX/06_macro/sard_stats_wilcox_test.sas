/*** HELP START ***//*

Purpose:
  Performs a two-sample Wilcoxon rank-sum test using PROC NPAR1WAY
  and returns ARD-style results aligned with cardx conventions.

  The macro additionally requests Hodges-Lehmann estimation of the
  location shift and its confidence interval.

Inputs:
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

Outputs:
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

Notes:
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
  %sard_stats_wilcox_test(
    data=ADSL,
    out=sard_stats_wilcox_test,
    class=TRT01PN,
    var=AGE,
    side=2,
    exact=N,
    correct=Y,
    alpha=0.05
  );

*//*** HELP END ***/

%macro sard_stats_wilcox_test(
  data        = ,
  out         = sard_stats_wilcox_test,
  class       = ,
  var         = ,
  side = 2,
  exact       = N,
  correct     = Y,
  alpha       = 0.05
);

%local _n_group _n1 _n2 _n_total _n_distinct
        _p_var _p_left_var _p_right_var alternative;

%if %sysevalf(%superq(data)=, boolean)
 or %sysevalf(%superq(class)=, boolean)
 or %sysevalf(%superq(var)=, boolean) %then %do;
  %put ERROR: DATA=, CLASS=, and VAR= are required.;
  %return;
%end;

%let exact=%upcase(&exact);
%let side=%upcase(&side);

%if &exact ne Y and &exact ne N %then %do;
  %put ERROR: EXACT= must be Y or N.;
  %return;
%end;

%if &side = 2 %then %let alternative = two.sided;
%else %if &side = L %then %let alternative = less;
%else %if &side = U or &side = R %then %let alternative = greater;
%else %do;
  %put ERROR: SIDE= must be 2, L, U, or R.;
  %return;
%end;

%if &side = 2 %then %do;
 %let alternative = two.sided;
%end;
%if &side =L %then %do;
 %let alternative = less;
%end;
%if &side =U or &side =R  %then %do;
 %let alternative = Greater;
%end;

/* cardx::ard_stats_wilcox_test() requires exactly two groups */
proc sql noprint;
  select count(distinct &class)
    into :_n_group trimmed
  from &data
  where not missing(&class)
    and not missing(&var);

  select count(*)
    into :_n1-:_n2
  from &data
  where not missing(&class)
    and not missing(&var)
  group by &class
  order by &class;

  select count(&var), count(distinct &var)
    into :_n_total trimmed, :_n_distinct trimmed
  from &data
  where not missing(&class)
    and not missing(&var);
quit;

%if &_n_group ne 2 %then %do;
  %put ERROR: CLASS=&class must contain exactly two non-missing levels.;
  %return;
%end;


/*
 * PROC NPAR1WAY output dataset gives stable numeric names:
 * P2_WIL / PL_WIL / PR_WIL, and XP2_WIL / XPL_WIL / XPR_WIL
 * when an exact test is requested.
 */
proc npar1way data=&data wilcoxon hl alpha=&alpha
  %if %upcase(&correct)=N %then correct=no;
;
  class &class;
  var &var;

  %if &exact=Y %then %do;
    exact wilcoxon hl;
  %end;
  
  output out=sard_wilcox_raw wilcoxon;
  ods output HodgesLehmann =sard_wilcox_hl;
run;



/*
 * PROC NPAR1WAY's _WIL_ is a rank-sum statistic for the smaller group.
 * To reproduce R/cardx W, calculate it from the rank sum of Group 1.
 */
proc sort data=&data(
  keep=&class &var
  where=(not missing(&class) and not missing(&var))
) out=sard_wilcox_input;
  by &class;
run;

proc rank data=sard_wilcox_input
          out=sard_wilcox_ranked
          ties=mean;
  var &var;
  ranks sard_wilcox_rank;
run;

proc summary data=sard_wilcox_ranked nway;
  class &class;
  var sard_wilcox_rank;
  output out=sard_wilcox_scores(drop=_type_ _freq_)
    n=sard_wilcox_n
    sum=sard_wilcox_rank_sum;
run;

proc sort data=sard_wilcox_scores;
  by &class;
run;

data sard_wilcox_w;
  set sard_wilcox_scores;
  by &class;

  if first.&class then do;
    statistic = sard_wilcox_rank_sum
              - sard_wilcox_n * (sard_wilcox_n + 1) / 2;
    output;
  end;

  keep statistic;
run;

data sard_wilcox_result;
  if _n_ = 1 then do;
    set sard_wilcox_w;
    set sard_wilcox_hl(
   %if &exact=Y %then %do;
     where=(Type="Exact")
   %end;
   keep=Shift LowerCL UpperCL Type

    );
  end;
  set sard_wilcox_raw;

  length
    stat_name
    stat_label
    fmt_fun
    context
    sas_raw_stat
    $200.
    stat 8.
  ;

  /*
   * cardx equivalent: statistic
   * R's wilcox.test() reports W, not PROC NPAR1WAY's _WIL_ rank sum.
   */
  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name   = "statistic";
  stat_label  = "X-squared Statistic";
  stat        = statistic;
  fmt_fun     = "1";
  sas_raw_stat = "_WIL_ converted to R/cardx W";
  output;

  /* cardx equivalent: p.value */
  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name  = "p.value";
  stat_label = "p-value";
  fmt_fun    = "1";
  %if &exact=Y %then %do;
    if "%upcase(&alternative)" = "TWO.SIDED" then stat = XP2_WIL;
    else if "%upcase(&alternative)" = "LESS" then stat = XPL_WIL;
    else if "%upcase(&alternative)" = "GREATER" then stat = XPR_WIL;
    sas_raw_stat = "Exact Wilcoxon p-value";
  %end;
  %else %do;
    if "%upcase(&alternative)" = "TWO.SIDED" then stat = P2_WIL;
    else if "%upcase(&alternative)" = "LESS" then stat = PL_WIL;
    else if "%upcase(&alternative)" = "GREATER" then stat = PR_WIL;
    sas_raw_stat = "Asymptotic Wilcoxon p-value";
  %end;
  output;

  /* cardx equivalent: method */
  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name  = "method";
  stat_label = "method";
  stat       = 1;
  %if %upcase(&correct)=Y %then %do;
    fmt_fun = "1:Wilcoxon rank sum test with continuity correction";
  %end;
  %else %do;
    fmt_fun = "1:Wilcoxon rank sum test";
  %end;
  output;

  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name  = "alternative";
  stat_label = "alternative";
  fmt_fun    = "1";
  stat = choosen(whichc("%upcase(&alternative)","TWO.SIDED", "LESS","GREATER"),2,3,4);
  fmt_fun = catx(":",stat,"&alternative");
  output;

  /* cardx equivalent: exact */call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name  = "exact";
  stat_label = "exact";

  %if &exact=Y %then %do;
    stat    = 1;
    fmt_fun = "1:TRUE";
  %end;
  %else %do;
    stat    = 0;
    fmt_fun = "0:FALSE";
  %end;
  output;

  /* Remaining cardx::wilcox.test metadata */
  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name="mu";
  stat_label="mu";
  stat=0;
  fmt_fun="1";
  output;

  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name="correct";
  stat_label="correct";
  if "%upcase(&correct)" = "Y" then do;
   stat=1;
   fmt_fun="1:TRUE";
  end;
  else do;
   stat=0; fmt_fun="0:FALSE";
  end;
  output;

  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name="estimate";
  stat_label="Median of the Difference";
  stat=Shift;
  fmt_fun="1";
  context ="Hodges-Lehmann estimation of the location shift";
  output;

  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name="conf.low";
  stat_label="CI Lower Bound";
  stat=LowerCL;
  fmt_fun="1";
  output;

  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name="conf.high";
  stat_label="CI Upper Bound";
  stat=UpperCL;
  fmt_fun="1";
  output;

  call missing(of stat_name stat_label stat fmt_fun context sas_raw_stat);
  stat_name="conf.level";
  stat_label="CI Confidence Level";
  stat=1-&alpha.;
  fmt_fun="1";
  output;

run;

data &out;
  length
    group1
    variable
    context
    stat_name
    stat_label
    $200.
    stat 8.
    fmt_fun
    Additional_Notes_in_SAS
    $200.
  ;

  set sard_wilcox_result(rename=(context=Additional_Notes_in_SAS));

  group1   = "%upcase(&class)";
  variable = "%upcase(&var)";
  context  = "stats_wilcox_test";

  keep group1--Additional_Notes_in_SAS;
run;

proc delete data=
  sard_wilcox_raw
  sard_wilcox_input
  sard_wilcox_ranked
  sard_wilcox_scores
  sard_wilcox_w
  sard_wilcox_hl
  sard_wilcox_result
;
run;

%mend sard_stats_wilcox_test;
