global con_controls pop_per_school con_pop rural_pop_share rural_electric_share

/*******************************************************************************************************************/
/* program prep_f_test : Prepare joint ECI / ADR dataset for joint significance test of predicting forward pshock  */
/*******************************************************************************************************************/
cap prog drop prep_f_test
prog def prep_f_test
{
  /* merge to the main dataset with offset years */
  use $mining/con_mine_shocks, clear
  
  global offset 5
  replace year = year + $offset
  merge 1:1 con_id_joint year using $mdata/adr_mining_clean
  keep if _merge == 3
  drop _merge
  
  /* match the ECI data */
  merge 1:1 con_id_joint year using $mdata/eci_lags
  drop if _merge == 2
  drop _merge
  
  /* set fixed effects / clusters */
  group pc01_state_id
  group pc01_state_id pc01_district_id
  group pc01_state_id pc01_district_id year
  group pc01_state_id year 
  
  /* set fvsets */
  fvset base 2004 year
  fvset base 1 sgroup
  fvset base 1 sygroup
  
  /* set election number */
  cap drop election_number
  tag pc01_state_name year
  sort pc01_state_name year
  bys pc01_state_name: egen en_tmp = seq() if sytag
  bys pc01_state_name year: egen election_number = max(en_tmp)
  drop en_tmp
  
  /* set price shock to standard specification */
  set_pshock, wt
  
  /* define 1st and 2nd period price shocks */
  bys con_id_joint: egen pshock1 = max(pshock * (election_number == 1))
  bys con_id_joint: egen pshock2 = max(pshock * (election_number == 2))
  replace pshock1 = . if pshock1 == 0
  replace pshock2 = . if pshock2 == 0
  
  label var pshock1 "Price shock (t==1 only)"
  label var pshock2 "Price shock (t==2 only)"
  
  /* bring in control variables */
  merge m:1 con_id_joint using $mdata/con_id_joint_controls
  drop if _merge == 2
  drop _merge
  
  /* save analysis dataset */
  sort con_id_joint year
  
  label data "Constituency-year price shocks to local mineral industry, matched to ADR"
  save $tmp/adr_f_test, replace
}
end
/* *********** END program prep_f_test ***************************************** */

/**********************************************************************************/
/* program write_sum_line */
/***********************************************************************************/
cap prog drop write_sum_line
prog def write_sum_line
  syntax, v(varlist)  [reg(string) xvar(varlist) ]
  qui {
    /* get mean and semean */
    sum `v', d
    local N `r(N)'
    local mean `r(mean)'
    local sd = `r(sd)'

    /* run t-test */
    if !mi("`reg'") {
      `reg'
      local b _b["`xvar'"]
      local se _se["`xvar'"]
      test `xvar' = 0
      local p `r(p)'
      count_stars, p(`p')
      local stars `r(stars)'
  }
    
    /* get variable label */
    local varlabel: var label `v'
    
    /* set format type */
    if regexm("$dec_list", " `v' ") {
      local format "%6.2f"
    }
    else {
      local format "%6.0f"
    }
    noi di "`v' `mean'"
    local mean: di `format' (`mean')
    noi di "`v' `mean'"
    
    local sd: di `format' (`sd')
    if !mi("`reg'") {
      local b: di `format' (`b')
      local se: di `format' (`se')
    }
    /* store estimates in a file for tpl */
    local b `b'`stars'
    foreach o in mean sd b se {
      if mi("``o''") continue
      insert_into_file using $out/mining_stats.csv, key(`v'_`o') value("``o''") format(`format')
    }
    insert_into_file using $out/mining_stats.csv, key(`v'_N) value(`N') format(%10.0f)
  }
  cap noi di "`varlabel' & " `format' (`mean') " & " `format' (`sd') " & "  %10.0f (`N') " & " `format' (`b') "`stars' & " `format' (`se') "  \\" _n
end
/* *********** END program write_sum_line ***************************************** */

/**********************************************************************************/
/* program placebo_reg : Run a placebo regression with an analysis sample         */
/**********************************************************************************/
cap prog drop placebo_reg
prog def placebo_reg

  syntax varname
  tokenize `varlist'
  
  /* store mean, N for this outcome */
  qui sum `1', d
  local m `r(mean)'
  local n `r(N)'
  local sd `r(sd)'
  insert_into_file using $out/mining_stats.csv, key(`1'_mean) value(`m') format(%5.2f)
  insert_into_file using $out/mining_stats.csv, key(`1'_N) value(`n') format(%5.0f)

  /* store semean */
  insert_into_file using $out/mining_stats.csv, key(`1'_sd) value(`sd') format(%5.2f)
  
  /* run placebo regression and store beta, se */
  quireg `1' lag_pshock base_value $con_controls, cluster(sdgroup) absorb(sygroup) title(`1')
  local b  =  _b["lag_pshock"]
  local se = _se["lag_pshock"]
  qui test lag_pshock = 0
  count_stars, p(`r(p)')
  local stars `r(stars)'
  local b: di %5.2f `b'
  insert_into_file using $out/mining_stats.csv, key(`1'_b) value("`b'`stars'") 
  insert_into_file using $out/mining_stats.csv, key(`1'_se) value(`se') format(%5.2f)
end
/* *********** END program placebo_reg ***************************************** */


/********/
/* MAIN */
/********/
global sum_start \begin{tabular}{l r r r r r}\hline\hline Variable & Mean & S.E. Mean & N & Beta_{ps} & SE_{ps} \\ \hline
global sum_end \hline\end{tabular} 

/* list vars to display as decimals here */
global dec_list " rural_pop_share rural_electric_share ln_net_assets1 any_crim1 num_deps_wt winner_any_crim mean_any_crim winner_ed mean_ed enop_vot turnout inc margin8 "

/**************************/
/* constituency sum stats */
/**************************/
use $mining/mining_con_adr, clear

/* keep post-delim only */
gen l = strlen(con_id_joint)
keep if l == 12

/* keep 1 observation per constituency */
tag con_id_joint
keep if ctag

/* set variable labels */
label var num_deps_wt "Number deposits"
label var value_wt_f2 "Average annual mineral output (1000 USD)"

/* run outcome regression to get right sample */
areg winner_any_crim pshock $con_controls, cluster(sdygroup) absorb(sygroup)
keep if e(sample)

/* switch value_wt to USD using avg exchange rate of 45 rupees/dollars */
replace value_wt_f2 = value_wt_f2 / 45.2

/* loop over outcome vars of interest */
foreach v in num_deps_wt value_wt_f2 $con_controls {

  /* write the summary line */
  write_sum_line, v(`v') 

}

/*******************************/
/* run joint significance test */
/*******************************/
prep_f_test
use $tmp/adr_f_test, clear
qui areg pshock winner_any_crim mean_any_crim turnout inc enop_vot margin8, absorb(sygroup) cluster(sdygroup)
test winner_any_crim = mean_any_crim = turnout = inc = enop_vot = margin8 = 0
local p = `r(p)'

// file write fh " \qquad \textit{p-value from F test of joint significance: " %5.2f (`p') "} & & & & & \\"
insert_into_file using $out/mining_stats.csv, key(f_test) value(`p') format(%5.2f)

/***************************************/
/* candidate level sum stats (MH part) */
/***************************************/
use $tmp/adr_ts2_mine_shocks, clear

/* label vars of interest */
label var ln_net_assets1 "Log Net Assets (USD)"
label var net_assets1 "Net Assets (Rs. 1000)"
label var any_crim1 "Facing Criminal Charges"

foreach v in ln_net_assets1 any_crim1 {

  preserve

  /* get analysis sample */
  if "`v'" == "ln_net_assets1" reghdfe ln_diff_net_assets base_value pshock `v' $con_controls, cluster(sdgroup) absorb(sygroup)
  if "`v'" == "any_crim1" reghdfe more_crime base_value pshock `v' $con_controls, cluster(sdgroup) absorb(sygroup)
  keep if e(sample)

  /* write the summary line */
  regroup pc01_state_id year1
  regroup pc01_state_id pc01_district_id 
  write_sum_line, v(`v') reg("reghdfe `v' pshock $con_controls if winner1 == 1, cluster(sdgroup) absorb(sygroup)") xvar(pshock)
 
  /* restore full sample */
  restore
}

/******************************************************/
/* run placebo test on adverse selection outcome vars */
/******************************************************/
/* open adr-winner dataset */
use $mining/mining_con_adr, clear

/* get trailing pshock */
set_pshock, wt
replace year = year + 5
drop ps_wt_glo_f2_m6
merge 1:1 con_id_joint year using $mining/con_mine_shocks, keepusing(ps_wt_glo_f2_m6)
drop if _merge == 2
ren ps_wt_glo_f2_m6 lag_pshock

/* set dataset to main analysis sample */
reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup)
keep if e(sample)

/* define corruption-based crime */
egen winner_crime_govt = rowmax(winner_crime_corruption winner_crime_publicservant winner_crime_election)

/* shorten varnames for tpl file */
drop winner_assets
ren ln_winner_net_assets winner_assets
ren winner_crime_govt winner_corrupt
ren winner_crime_violent_strong winner_violent

/* loop over each outcome var */
foreach v in winner_any_crim mean_any_crim winner_hs_grad winner_age winner_assets winner_corrupt winner_violent {
  placebo_reg `v'
}

/*******************************/
/* repeat placebo test for ECI */
/*******************************/
use $mining/mining_eci_candidates, clear

/* keep winner and same sample as above */
keep if index == 1 & year > 2003
set_pshock, wt
replace year = year + 5
drop ps_wt_glo_f2_m6
merge 1:1 con_id_joint year using $mining/con_mine_shocks, keepusing(ps_wt_glo_f2_m6)
drop if _merge == 2
ren ps_wt_glo_f2_m6 lag_pshock

/* loop over each outcome var */
foreach v in incumbent turnout enop_vot bjp inc margin8 {
  placebo_reg `v'
}

/******************************************/
/* repeat placebo test for MH regressions */
/******************************************/

/* load time series data */
use $tmp/adr_ts2_mine_shocks, clear

/* get lagged price shocks */
ren year1 year
replace year = year - 5
drop ps_wt_glo_f2_m5
merge m:1 con_id_joint year using $mining/con_mine_shocks, keepusing(ps_wt_glo_f2_m5)
drop if _merge == 2
ren ps_wt_glo_f2_m5 lag_pshock

/* store data */
preserve

/* set asset time series sample */
reghdfe ln_diff_net_assets base_value pshock pshock_winner winner1 ln_net_assets1 $con_controls, cluster(sdgroup) absorb(sygroup)
keep if e(sample)

/* run placebo regression on asset change */
ren ln_diff_net_assets asset_diff
placebo_reg asset_diff

/* store first and second term assets */
forval i = 1/2 {
  qui sum ln_net_assets`i', d
  local m `r(mean)'
  local n `r(N)'
  local sd `r(sd)'
  insert_into_file using $out/mining_stats.csv, key(asset`i'_mean) value(`m') format(%5.2f)
  insert_into_file using $out/mining_stats.csv, key(asset`i'_N) value(`n') format(%5.0f)
  insert_into_file using $out/mining_stats.csv, key(asset`i'_sd) value(`sd') format(%5.0f)
}

/* set crime sample */
restore
reghdfe more_crime pshock pshock_winner winner1 base_value $con_controls ln_crim1, cluster(sdgroup) absorb(sygroup)
keep if e(sample)

/* run placebo reg on crime change */
placebo_reg more_crime

/* store first and second term crime */
forval i = 1/2 {
  qui sum num_crim`i', d
  local m `r(mean)'
  local n `r(N)'
  local sd `r(sd)'
  insert_into_file using $out/mining_stats.csv, key(crim`i'_mean) value(`m') format(%5.2f)
  insert_into_file using $out/mining_stats.csv, key(crim`i'_N) value(`n') format(%5.0f)
  insert_into_file using $out/mining_stats.csv, key(crim`i'_sd) value(`sd') format(%5.0f)
}

/***************************************/
/* use stata-tex to create latex table */
/***************************************/
table_from_tpl, t($mcode/tex/sum_stats.tpl.tex) r($out/mining_stats.csv) o($out/mining_sum_stats.tex)
