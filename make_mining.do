clear
ssc install reghdfe
ssc install ftools
ssc install estout

/* set the following globals:
$out: path for output files to be created
$tmp: a temp folder
$mdata and $mining: path to data (the same path for both of these) */

global out
global tmp /scratch/pn/mining_test/tmp
global mdata /scratch/pn/mining_test/dta
global mining /scratch/pn/mining_test/dta
global mcode .
global PYTHONPATH ./stata-tex

if mi("$out") | mi("$tmp") | mi("$mdata") | mi("$mcode") {
  display as error "Globals 'out', 'tmp', and 'mdata' must be set for this to run."
  error 1
}

/* load Stata programs */
qui do tools.do
qui do masala-merge/masala_merge
qui do stata-tex/stata-tex
qui do mining_programs.do

/* add ado folder to adopath */
adopath + ado

cap log close
log using $out/mining.log, text replace

/***********************/
/* generate all tables */
/***********************/
do $mcode/a/table_sumstats
do $mcode/a/table_main
do $mcode/a/table_crime_type
do $mcode/a/table_ts
do $mcode/a/table_eci

cap log close
