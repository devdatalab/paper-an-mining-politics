/******************************************************************/
/* show sensitivity of MH estimates to potential winner attrition */
/******************************************************************/

/* get sh_cand_id into the adverse selection mining database  */
use $elections/trivedi_candidates_clean.dta, clear
keep if position == 1
duplicates drop ac_id year, force
save $tmp/trivedi_winners, replace

use $mining/mining_con_adr, clear
merge 1:1 ac_id year using $tmp/trivedi_winners, keepusing(sh_cand_id) keep(master match)
save $tmp/mining_adr_ids, replace

/* create affidavits data unique on sh_cand_id */
preserve
use $adr/affidavits_clean.dta, clear
drop if mi(sh_cand_id)
save $tmp/adr_tmp, replace
restore

/* empty out estimates file */
cap erase $tmp/mh_attrition.csv
append_to_file using $tmp/mh_attrition.csv, s(b,se,p,n,outcome,threshold)

/* open MH analysis dataset */
use $tmp/adr_ts2_mine_shocks, clear

/* set to crime analysis sample */
reghdfe more_crime pshock base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)
keep if e(sample)

/* merge it on ac_id year to the main sample dataset */
ren year1 year
ren ac_id tmp
merge m:1 year con_id_joint using $tmp/mining_adr_ids, keepusing(pc01_state_name pc01_state_id winner_any_crim ac_id) gen(as_merge)
replace ac_id = tmp if mi(ac_id)
assert ac_id == tmp if !mi(ac_id) & !mi(tmp)

/* get the sh_cand_id (which doesn't exist in adverse selection sample) */
merge m:1 ac_id year using $tmp/trivedi_winners, keepusing(sh_cand_id) keep(master match) 

/* keep the set of states that appear in our main dataset */
bys pc01_state_name year: egen keep_sy = max(as_merge)
keep if keep_sy == 3
drop keep_sy

/* generate the share of people who ran again in each state */
gen ran_again = (as_merge == 3)
bys pc01_state_name year: egen mean_ran_again = mean(ran_again)
sum ran_again if as_merge != 1

/* check attrition on observables */
/* merge more candidate info from trivedi/adr data */
drop age
replace sh_cand_id = sh_cand_id1 if mi(sh_cand_id)

merge m:1 sh_cand_id using $elections/trivedi_candidates_clean, keepusing(age party) keep(master match) gen(el_merge)
ren age triv_age
gen bjp = party == "BJP"
gen inc = party == "INC"
gen female = sex == "F"

/* get more ADR data */
drop hs_grad* ed*
merge m:1 sh_cand_id using $tmp/adr_tmp, keepusing(age hs_grad ed major_crime any_crim num_crim assets liabilities net_assets) keep(master match) gen(adr_merge)

/* gen non-missing liabilities measure */
winsorize liabilities 1 2e8, replace
gen ln_liab = ln(liabilities)
replace ln_liab = 0 if mi(ln_liab)

winsorize assets 1 1e10, replace
winsorize net_assets 1 1e10, replace
gen ln_assets = ln(assets)
gen ln_net_assets = ln(net_assets)

regroup pc01_state_id year
regroup pc01_state_id
regroup year

eststo: reg ran_again hs_grad triv_age bjp inc major_crime num_crim ln_assets ln_net_assets any_crim female
eststo: probit ran_again hs_grad triv_age bjp inc major_crime num_crim ln_assets ln_net_assets any_crim female
eststo: reg ran_again age hs_grad ed triv_age enop sex party major_crime num_crim assets net_assets any_crim
eststo: reg ran_again num_crim1 ln_assets1 ln_liab
eststo: reg ran_again num_crim1 ln_assets1 ln_liab any_crim1 female
eststo: reg ran_again num_crim1 ln_assets1 ln_liab any_crim1 female bjp inc
estout_default using $tmp/mh_attrition_selection

/* restrict data to samples with smaller and smaller amounts of attrition */
foreach ra in 0 .1 .2 .3 .4 .5 .6 .7 {
  quireg more_crime pshock base_value $con_controls ln_crim1 if winner1 == 1 & mean_ran_again > `ra', cluster(sdgroup) absorb(sygroup)
  append_est_to_file using $tmp/mh_attrition.csv, s("asset,`ra'") b(pshock)
}

/************************************/
/* repeat analysis for asset change */
/************************************/
use $tmp/adr_ts2_mine_shocks, clear

/* keep winners crime dataset */
reghdfe ln_diff_net_assets base_value pshock ln_net_assets1 $con_controls if winner1 == 1, cluster(sdgroup) absorb(sygroup)
keep if e(sample)

/* merge it on con_id_joint year to the main table dataset */
ren year1 year
merge m:1 year con_id_joint using $mining/mining_con_adr, keepusing(pc01_state_name pc01_state_id winner_any_crim)

/* keep the set of states that appear in our main dataset */
bys pc01_state_name year: egen keep_sy = max(_merge)
keep if keep_sy == 3
drop keep_sy

tab year _merge

gen ran_again = (_merge == 3)
bys pc01_state_name year: egen mean_ran_again = mean(ran_again)
sum ran_again if _merge != 1

/* check attrition on observables */
reg ran_again num_crim1 ln_assets1 ln_net_assets1 any_crim1 num_deps 



/* run regs with different attrition cutoffs */
foreach ra in 0 .1 .2 .3 .4 .5 .6 .7 {
  quireg ln_diff_net_assets pshock base_value ln_net_assets1 $con_controls if winner1 == 1 & mean_ran_again > `ra', cluster(sdgroup) absorb(sygroup)
  append_est_to_file using $tmp/mh_attrition.csv, s("crime,`ra'") b(pshock)
}

import delimited using $tmp/mh_attrition.csv, clear varnames(1)

gen b_high = b + se * 2
gen b_low = b - se * 2

twoway ///
    (rcap b_high b_low threshold if outcome == "asset", lwidth(medthick)) ///
    (rcap b_high b_low threshold if outcome == "asset" & threshold == 0, lcolor(black) lwidth(medthick)) ///
    (scatter b threshold if outcome == "asset", color(black) mlabel(n) mlabsize(small) mlabcolor(black)) ///
    , ylabel(-.2(.1).4) legend(off) xtitle("Retention Threshold", size(medlarge)) ytitle("Moral Hazard Coefficient", size(medlarge)) yline(0, lcolor(black) lpattern("-"))
graphout mh_asset_robust, pdf

twoway ///
    (rcap b_high b_low threshold if outcome == "crime", lwidth(medthick)) ///
    (rcap b_high b_low threshold if outcome == "crime" & threshold == 0, lcolor(black) lwidth(medthick)) ///
    (scatter b threshold if outcome == "crime", color(black) mlabel(n) mlabsize(small) mlabcolor(black)) ///
    , ylabel(-.2(.1).4) legend(off) xtitle("Retention Threshold", size(medlarge)) ytitle("Moral Hazard Coefficient", size(medlarge)) yline(0, lcolor(black) lpattern("-"))
graphout mh_crime_robust, pdf
