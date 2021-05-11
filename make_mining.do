clear

/* set the following globals:
$out: path for output files to be created
mdata: path to data [intermediate data files will be put here too] */

global out /scratch/pn/mining_test/out
global tmp /scratch/pn/mining_test/tmp
global mdata /scratch/pn/mining_test/dta
global mining /scratch/pn/mining_test/dta
global mcode .

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


