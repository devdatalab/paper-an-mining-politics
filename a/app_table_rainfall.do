use $mdata/rain_pc01, clear

/* use june rainfall */
drop *arrival*

/* get mean rainfall in each village */
egen rain_mean = rowmean(rain_june_*)
egen rain_sd = rowsd(rain_june_*)

/* drop zeros */
drop if rain_mean == 0

/* generate normalized rainfall */
forval y = 1981/2018 {
  gen rain_norm_`y' = (rain_june_`y' - rain_mean) / rain_sd
}

keep pc01_state_id pc01_district_id pc01_subdistrict_id pc01_village_id rain_norm_*

/* make the data long */
reshape long rain_norm_, j(year) i(pc01_state_id pc01_village_id)
ren rain_norm_ rain

save $tmp/rain_sd_long_village, replace

/* collapse to district level */
collapse (mean) rain, by(year pc01_state_id pc01_district_id)
save $tmp/rain_sd_long_district, replace

/* collapse to constituency level */
use $tmp/rain_sd_long_village, replace
merge m:1 pc01_state_id pc01_village_id using $keys/village_con_key_2007, keepusing(con_id) keep(match) nogen
collapse (mean) rain, by(year pc01_state_id con_id)
save $tmp/rain_sd_long_con_2007, replace

/* 2008 constituencies */
use $tmp/rain_sd_long_village, replace
merge m:1 pc01_state_id pc01_village_id using $keys/village_con_key_2008, keepusing(con_id08) keep(match) nogen
collapse (mean) rain, by(year pc01_state_id con_id08)
save $tmp/rain_sd_long_con_2008, replace

/* pool 2007 and 2008 constituencies for merging to ADR */
ren con_id08 con_id_joint
append using $tmp/rain_sd_long_con_2007
replace con_id_joint = con_id if mi(con_id_joint)

/* create lagged rain values, as this becomes hard once we have multiple candidates per con-year */
group con_id_joint
xtset cgroup year
forval y = 1/5 {
  gen rain_l`y' = L`y'.rain
}

/* create total rain in last five years */
egen rain_last5 = rowmean(rain_l1 rain_l2 rain_l3 rain_l4 rain_l5)

save $tmp/rain_sd_long_con, replace

global out ~/iec/output/mining

/********************************/
/* merge rainfall shocks to ADR */
/********************************/
use $adr/affidavits_ac, clear
drop if mi(con_id_joint)

keep con_id_joint year winner_any_crim

/* keep _m == 2 --> these are rainfall observations in non-election years */
merge 1:1 con_id_joint year using $tmp/rain_sd_long_con
drop if _merge == 1
drop _merge

/* create groups for fixed effects and clusters */
group pc01_state_id 
group pc01_state_id year

/* create good rainfall dummies */
gen good_rain = rain > 0.5 if !mi(rain)
gen bad_rain = rain < -0.69 if !mi(rain)

save $tmp/adr_selection_rain, replace
  
/****************************/
/* MORAL HAZARD REGRESSIONS */
/****************************/

/* open ADR candidate time series */
use $tmp/adr_ts, clear

/* merge to rainfall on year2, so L0.year is candidate at the end of term */
ren year2 year
ren con_id_joint con_id_joint1
ren con_id_joint2 con_id_joint
merge m:1 con_id_joint year using $tmp/rain_sd_long_con

/* keep if at least one year matched -- keep non-matches as these are rainfall years in non-election years */
drop if _merge == 1
bys con_id_joint: egen max_merge = max(_merge)
keep if max_merge == 3
drop max_merge

/* create f.e. vars */
group pc01_state_id
group pc01_state_id year

/* add up rainfall during electoral term */
egen rain_during_term = rowmean(rain_l4 rain_l3 rain_l2 rain_l1)

/* create rain-winner interaction */
gen winner_rain_during_term = winner1 * rain_during_term

/* save working dataset */
save $tmp/adr_moral_hazard_rain, replace

/***************/
/* REGRESSIONS */
/***************/

/* RAINFALL REGRESSIONS */

/* Adverse Selection Regressions */
use $tmp/adr_selection_rain, clear
eststo clear

eststo: reghdfe winner_any_crim rain_l1, cluster(cgroup) absorb(sygroup)
store_depvar_mean y1, format("%04.2f")
eststo: reghdfe winner_any_crim rain_last5, cluster(cgroup) absorb(sygroup)
store_depvar_mean y2, format("%04.2f")

/* Moral Hazard Regressions */
use $tmp/adr_moral_hazard_rain, clear

/* asset regs, cumulative rain during term */
eststo: reghdfe ln_diff_net_assets rain_during_term  if winner1 == 1, absorb(sygroup) cluster(cgroup)
store_depvar_mean y3, format("%04.2f")
eststo: reghdfe ln_diff_net_assets rain_during_term winner1 winner_rain_during_term , absorb(sygroup) cluster(cgroup)
store_depvar_mean y4, format("%04.2f")

/* crime regs, cumulative rain during term */
eststo: reghdfe more_crime rain_during_term if winner1 == 1, absorb(sygroup) cluster(cgroup)
store_depvar_mean y5, format("%04.2f")
eststo: reghdfe more_crime rain_during_term winner1 winner_rain_during_term, absorb(sygroup) cluster(cgroup)
store_depvar_mean y6, format("%04.2f")

/* label variables and estout */
label var rain_l1          "Precip. Year Before Election"
label var rain_last5       "Precip. 5 Years Before Election"
label var rain_during_term "Precip. During Electoral Term"
label var winner1 "Winner"
label var winner_rain "Precip. During Term * Winner"
local prefoot `""\hline" "State-Year F.E. & Yes & Yes & Yes & Yes & Yes & Yes \\ " "\hline ""'
estout_default using $out/app_precip, prefoot(`prefoot') 
estmod_header  using $out/app_precip, cstring(" & \multicolumn{2}{c}{\underline{Criminal Winner}} & \multicolumn{2}{c}{\underline{Change in Assets}} & \multicolumn{2}{c}{\underline{Change in Crime}}")
estmod_footer  using $out/app_precip, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' & `y5' & `y6' ")
