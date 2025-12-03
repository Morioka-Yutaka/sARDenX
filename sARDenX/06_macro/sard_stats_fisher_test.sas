/*** HELP START ***//*

Purpose:
  Performs Fisher's exact test for a 2x2 (or RxC) contingency table by
  aggregating counts and calling PROC FREQ with the FISHER option.
  The macro returns ARD-style p-value and method/alternative metadata.

Inputs:
  data      - Input dataset.
  classdata - Optional CLASSDATA= dataset for PROC SUMMARY (formats/order).
  group     - Row (grouping) variable for the contingency table.
  var       - Column (categorical) variable for the contingency table.
  side      - Alternative hypothesis:
              2 or B = two-sided (default),
              L      = one-sided (lower/left tail),
              U or R = one-sided (upper/right tail).

Outputs:
  out       - Output dataset in ARD-style structure with:
              - method (Fisher's Exact Test)
              - alternative (two.sided / less / greater)
              - p.value (exact Fisher p-value)

Notes:
  - The meaning of "less" and "greater" depends on the ordering of
    levels in &group and &var as used in TABLES &group * &var.
  - Missing values in &group or &var are excluded unless PROC SUMMARY
    is modified with MISSING.
  - Intermediate datasets are created in WORK and deleted at the end.

Example:
  %sard_stats_fisher_test(
    data=ADSL,
    out=sard_stats_fisher_test,
    group=TRT01PN,
    var=SEX,
    side=2
  );

*//*** HELP END ***/

%macro sard_stats_fisher_test(
  data = ,
  classdata = ,
  out =sard_stats_fisher_test,
  group = ,
  var = ,
  side = 2
);

proc summary data=&data. nway
%if %length(&classdata) ne 0 %then %do;
  classdata=&classdata.
%end;
;
class &group. &var.;
output out=sard_stats_fisher_test_1;
run;

ods output FishersExact=sard_stats_fisher_test_2;
proc freq data=sard_stats_fisher_test_1;
 tables &group. * &var. /fisher exact;
 weight _FREQ_ /zeros;
run;


data sard_stats_fisher_test_3;
length 
stat_name
stat_label $200.
stat 8.
fmt_fun
context
Additional_Notes_in_SAS
$200.
;
set sard_stats_fisher_test_2;
%if &side = 2 or %upcase(&side) = B %then %do; 
  where Name1 ="XP2_FISH";
%end;
%if  %upcase(&side) = L %then %do; 
  where Name1 ="XPL_FISH";
%end;
%if  %upcase(&side) = U or %upcase(&side) = R %then %do; 
  where Name1 ="XPR_FISH";
%end;

context ="stats_fisher_test";

/*method*/
if _N_ = 1 then do;
call missing(of stat_name stat_label stat  fmt_fun Additional_Notes_in_SAS);
  stat_name ="method";
  stat_label="method";
  stat=1;
  fmt_fun=catx(":",stat,"Fisher's Exact Test for Count Data");
  output;

end;
%if &side = 2 or %upcase(&side) = B %then %do; 
call missing(of stat_name stat_label stat  fmt_fun Additional_Notes_in_SAS);
  stat_name ="alternative";
  stat_label="alternative";
  stat=2;
  fmt_fun=catx(":",stat,"two.sided");
  output;
%end;
%if  %upcase(&side) = L %then %do; 
call missing(of stat_name stat_label stat  fmt_fun Additional_Notes_in_SAS);
  stat_name ="alternative";
  stat_label="alternative";
  stat=1;
  fmt_fun=catx(":",stat,"less");
  output;
%end;
%if  %upcase(&side) = U or %upcase(&side) = R %then %do; 
call missing(of stat_name stat_label stat  fmt_fun Additional_Notes_in_SAS);
  stat_name ="alternative";
  stat_label="alternative";
  stat=1;
  fmt_fun=catx(":",stat,"greater");
  output;
%end;

call missing(of stat_name stat_label stat  fmt_fun Additional_Notes_in_SAS);
  stat_name ="p.value";
  stat_label="p-value";
  stat=nValue1;
  fmt_fun=cats(1);
  output;


run;


data &out.;
length 
group1
variable
context
stat_name
stat_label
$200.
stat
8.
fmt_fun
Additional_Notes_in_SAS
$200.
;
set
sard_stats_fisher_test_3;
group1="%upcase(&group)";
variable="%upcase(&var)";
context="stats_fisher_test";
keep group1--Additional_Notes_in_SAS ;
run;

proc delete data =sard_stats_fisher_test_1;
run;
proc delete data =sard_stats_fisher_test_2;
run;
proc delete data =sard_stats_fisher_test_3;
run;


%mend;
