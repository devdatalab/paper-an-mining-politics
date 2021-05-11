/* create unique 01->11 village and town keys */
use $keys/pc0111_town_key, clear
ddrop pc01_state_id pc01_district_id pc01_subdistrict_id pc01_town_id
ddrop pc11_state_id pc11_town_id
keep pc01_state_id pc01_district_id pc01_subdistrict_id pc01_town_id pc11_state_id pc11_town_id
save $tmp/town_key_unique, replace

use $keys/pcec/pc01r_pc11r_key, clear
ddrop pc01_state_id pc01_village_id 
ddrop pc11_state_id pc11_village_id
keep pc01_state_id pc01_district_id pc01_subdistrict_id pc01_village_id pc11_state_id pc11_village_id
save $tmp/village_key_unique, replace

/* prep short urban economic census */
use $ec_collapsed/ec_u_nic_supergroup, clear
keep pc11_state_id pc11_town_id ec90*emp ec98*emp ec05*emp ec13*emp

/* get 2001 town identifiers */
merge m:1 pc11_town_id pc11_state_id using $tmp/town_key_unique, keep(match) nogen
order *id

/* get 2007 and 2008 con ids */
merge 1:1 pc01_town_id pc01_state_id using $keys/town_con_key_2007, keepusing(con_id) keep(match) nogen
merge 1:1 pc01_town_id pc01_state_id using $keys/town_con_key_2008, keepusing(con_id08) keep(match) nogen

save $tmp/ec_towns, replace

/* prep short rural economic census */
use $ec_collapsed/ec_r_nic_supergroup, clear
keep pc11_state_id pc11_village_id ec90*emp ec98*emp ec05*emp ec13*emp

/* get 2001 village identifiers */
merge 1:1 pc11_village_id pc11_state_id using $tmp/village_key_unique, keep(match) nogen
order *id

/* get 2007 and 2008 con ids */
merge 1:1 pc01_village_id pc01_state_id using $keys/village_con_key_2007, keepusing(con_id) keep(match) nogen
merge 1:1 pc01_village_id pc01_state_id using $keys/village_con_key_2008, keepusing(con_id08) keep(match) nogen

save $tmp/ec_villages, replace

/* append towns in preparation for collapse to con-level */
append using $tmp/ec_towns
drop pc11*

save $tmp/vt, replace

/* collapse to con level */
collapse (sum) ec*, by(con_id)
save $tmp/ec_nic_con_2007, replace

/* collapse to con08 */
use $tmp/vt, clear
collapse (sum) ec*, by(con_id08)
save $tmp/ec_nic_con_2008, replace

/************************/
/* create bartik shocks */
/************************/
foreach con_year in 2007 2008 {
  use $tmp/ec_nic_con_`con_year', clear

  /*
  
  1. calculate national employment growth for each NIC in each period
  2. calculate predicted level growth in each NIC in each location
  3. collapse on predicted and actual levels in each location
  
  */
  
  ren ec*_n8708_*_emp ec*_emp_*
  
  /* fill in missing variables */
  forval i = 1/70 {
    foreach y in 90 98 05 13 {
      cap confirm variable ec`y'_emp_`i'
      if _rc {
        gen ec`y'_emp_`i' = 0
      }
    }
  }
    
  /* 1. CALCULATE NATIONAL EMPLOYMENT GROWTH FOR EACH NIC IN EACH PERIOD */
  /* calculate total employment in each NIC in each year (70 obs in each year) */
  forval i = 1/70 {
    foreach y in 90 98 05 13 {
      qui sum ec`y'_emp_`i'
      gen ec`y'_nat_emp_`i' = `r(mean)' * `r(N)'
    }
  
    /* calculate national growth in each industry */
    gen g9098_nat_`i' = ec98_nat_emp_`i' / ec90_nat_emp_`i'
    gen g9805_nat_`i' = ec05_nat_emp_`i' / ec98_nat_emp_`i'
    gen g0513_nat_`i' = ec13_nat_emp_`i' / ec05_nat_emp_`i'
  }
  
  /* 2. calculate predicted level growth in each NIC in each location */
  forval i = 1/70 {
    gen ec98_pred_`i' = ec90_emp_`i' * (g9098_nat_`i')
    gen ec05_pred_`i' = ec98_emp_`i' * (g9805_nat_`i')
    gen ec13_pred_`i' = ec05_emp_`i' * (g0513_nat_`i')
  }
  
  /* calculate total employment and predicted total employment in each location, across all sectors */
  egen ec90_emp = rowtotal(ec90_emp_*)
  egen ec98_emp = rowtotal(ec98_emp_*)
  egen ec05_emp = rowtotal(ec05_emp_*)
  egen ec13_emp = rowtotal(ec13_emp_*)
  
  egen ec98_pred_emp = rowtotal(ec98_pred_*)
  egen ec05_pred_emp = rowtotal(ec05_pred_*)
  egen ec13_pred_emp = rowtotal(ec13_pred_*)
  
  /* drop zero employment constituencies in any year */
  drop if ec98_emp == 0 | ec05_emp == 0 | ec13_emp == 0
  drop if ec05_emp < 1000 | ec13_emp < 1000 | ec98_emp < 1000
  
  /* calculate actual and predicted con-level growth */
  gen g9098 = ln(ec98_emp) - ln(ec90_emp)
  gen g9805 = ln(ec05_emp) - ln(ec98_emp)
  gen g0513 = ln(ec13_emp) - ln(ec05_emp)
  
  gen g_pred_9098 = ln(ec98_pred_emp) - ln(ec90_emp)
  gen g_pred_9805 = ln(ec05_pred_emp) - ln(ec98_emp)
  gen g_pred_0513 = ln(ec13_pred_emp) - ln(ec05_emp)
  
  binscatter g9098 g_pred_9098 if g_pred_9098 < .4, linetype(none)
  graphout bartik_9098

  binscatter g9805 g_pred_9805 if g_pred_9805 < .4, linetype(none)
  graphout bartik_9805
  
  binscatter g0513 g_pred_0513 if g_pred_0513 < .4, linetype(none)
  graphout bartik_0513
  
  reg g9098 g_pred_9098 if g_pred_9098 < .4
  reg g9805 g_pred_9805 if g_pred_9805 < .4
  reg g0513 g_pred_0513 if g_pred_0513 < .4

  keep con_id ec90_emp ec98_emp ec05_emp ec13_emp g9098 g9805 g0513 g_pred_*
  save $tmp/bartik_con_`con_year', replace
}

/* append  */
use $tmp/bartik_con_2007, clear
gen con_id_joint = con_id

append using $tmp/bartik_con_2008
replace con_id_joint = con_id08 if mi(con_id_joint)

save $tmp/bartik_con, replace

/**************************************/
/* PREPARE CRIMINAL SELECTION DATASET */
/**************************************/

/* open con_id and winner_crim from ADR */
use pc01_state_id con_id_joint year winner_any_crim using $adr/affidavits_ac, clear
drop if mi(con_id_joint)

/* bring in bartik shocks */
merge m:1 con_id_joint using $tmp/bartik_con, nogen keep(match)

/* create groups for fixed effects and clusters */
group pc01_state_id 
group pc01_state_id year
group con_id_joint

/* generate actual growth */
gen     growth = g9805 if inrange(year, 2004, 2006)
replace growth = g0513 if inrange(year, 2011, 2015)

/* generate predicted growth and match to election years */
gen pred_growth = g_pred_9805 if inrange(year, 2004, 2006)
replace pred_growth = g_pred_0513 if inrange(year, 2011, 2015)

save $tmp/adr_selection_bartik, replace

/********************************/
/* PREPARE MORAL HAZARD DATASET */
/********************************/

/* define these as growth from 2005-2013 on changes for candidates from 2005-09 to 2010-15 */

/* open ADR candidate time series */
use $tmp/adr_ts, clear

/* merge bartik data */
ren con_id_joint con_id_joint1
ren con_id_joint2 con_id_joint
merge m:1 con_id_joint using $tmp/bartik_con, nogen keep(match)

/* create f.e. vars */
group pc01_state_name year2
group con_id_joint

/* growth is 2005 to 2013 only. */
gen growth = g0513
gen pred_growth = g_pred_0513

/* sample is start years from 2005 to 2010 */
keep if inrange(year1, 2004, 2010)

/* put growth in a separate var so gets a different row from A/S regs */
gen term_growth = growth
gen pred_term_growth = pred_growth

/* create interaction terms */
gen term_growth_winner1 = term_growth * winner1
gen pred_term_growth_winner1 = pred_term_growth * winner1

/* save working dataset */
save $tmp/adr_moral_hazard_bartik, replace

/***************************/
/* CRIMINAL SELECTION REGS */
/***************************/
eststo clear
use $tmp/adr_selection_bartik, clear

/* first stage --> looks strong */
reghdfe growth pred_growth, cluster(cgroup) absorb(sygroup)

/* effect of growth and predicted growth on criminality */
eststo g1: reghdfe winner_any_crim growth, cluster(cgroup) absorb(sygroup)
store_depvar_mean g1, format("%04.2f")

eststo p1: reghdfe winner_any_crim pred_growth, cluster(cgroup) absorb(sygroup)
store_depvar_mean p1, format("%04.2f")

/*********************/
/* MORAL HAZARD REGS */
/*********************/
use $tmp/adr_moral_hazard_bartik, clear

/* ACTUAL GROWTH */
/* asset regs */
eststo g2: reghdfe ln_diff_net_assets term_growth  if winner1 == 1, absorb(sygroup) cluster(cgroup)
store_depvar_mean g2, format("%04.2f")
eststo g3: reghdfe ln_diff_net_assets term_growth winner1 term_growth_winner1, absorb(sygroup) cluster(cgroup)
store_depvar_mean g3, format("%04.2f")

/* crime regs */
eststo g4: reghdfe more_crime   term_growth if winner1 == 1, absorb(sygroup) cluster(cgroup)
store_depvar_mean g4, format("%04.2f")
eststo g5: reghdfe more_crime term_growth winner1 term_growth_winner1       , absorb(sygroup) cluster(cgroup)
store_depvar_mean g5, format("%04.2f")

/* BARTIK-PREDICTED GROWTH */
eststo p2: reghdfe ln_diff_net_assets pred_term_growth  if winner1 == 1, absorb(sygroup) cluster(cgroup)
store_depvar_mean p2, format("%04.2f")
eststo p3: reghdfe ln_diff_net_assets pred_term_growth winner1 pred_term_growth_winner1      , absorb(sygroup) cluster(cgroup)
store_depvar_mean p3, format("%04.2f")
eststo p4: reghdfe more_crime   pred_term_growth if winner1 == 1, absorb(sygroup) cluster(cgroup)
store_depvar_mean p4, format("%04.2f")
eststo p5: reghdfe more_crime pred_term_growth winner1 pred_term_growth_winner1       , absorb(sygroup) cluster(cgroup)
store_depvar_mean p5, format("%04.2f")

/* label variables */
label var growth "Pre-Election Growth"
label var pred_growth "Bartik Predicted Pre-Election Growth"
label var term_growth "Growth in Electoral Term"
label var pred_term_growth "Predicted Growth in Electoral Term"
label var term_growth_winner1 "Winner * Growth in Electoral Term"
label var pred_term_growth_winner1 "Winner * Predicted Growth in Electoral Term"
label var winner1 "Winner"

/* write estimates to tex files */
local prefoot `""\hline" "State-Year F.E. & Yes & Yes & Yes & Yes & Yes \\ " "\hline ""'

estout g1 g2 g3 g4 g5 using $out/app_ec_growth.tex, prefoot(`prefoot') $estout_params_np mlabel("(1)" "(2)" "(3)" "(4)" "(5)")
estmod_header         using $out/app_ec_growth, cstring(" & \underline{Crim Winner} & \multicolumn{2}{c}{\underline{Change in Assets}} & \multicolumn{2}{c}{\underline{Change in Crime}}")
estmod_footer  using $out/app_ec_growth, cstring("Mean Dep. Var. & `g1' & `g2' & `g3' & `g4' & `g5'  ")

estout p1 p2 p3 p4 p5 using $out/app_ec_growth_bartik.tex, prefoot(`prefoot') $estout_params_np mlabel("(1)" "(2)" "(3)" "(4)" "(5)")
estmod_header         using $out/app_ec_growth_bartik, cstring(" & \underline{Crim Winner} & \multicolumn{2}{c}{\underline{Change in Assets}} & \multicolumn{2}{c}{\underline{Change in Crime}}")
estmod_footer  using $out/app_ec_growth_bartik, cstring("Mean Dep. Var. & `p1' & `p2' & `p3' & `p4' & `p5' ")
