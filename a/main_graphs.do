/*************************************************/
/* binscatters of primary results (not in paper) */
/*************************************************/
global con_controls pop_per_school con_pop rural_pop_share rural_electric_share

/*********************************/
/* selection of criminal winners */
/*********************************/
use $mining/mining_con_adr, clear

/* set base value and pshock for adverse selection shock */
drop base_value pshock
gen base_value = base_value_wt_f2_m6
gen pshock = ps_wt_f2_m6

/* Column 1 - con_id_joint price shock, state*year fixed effects */
binscatter winner_any_crim pshock, control(base_value $con_controls) absorb(sygroup) xtitle("Price Shock") ytitle("Probability Criminal is Elected") savedata($tmp/bin_selection) replace
graphout bin_selection

/******************************************/
/* moral hazard: behavior while in office */
/******************************************/

use $mining/adr_ts2_mine_shocks, clear
binscatter ln_diff_net_assets  pshock if winner1 == 1, absorb(sygroup) control(base_value ln_net_assets1 $con_controls ) xtitle("Price Shock") ytitle("Log Asset Change") savedata($tmp/bin_mh_assets) replace
graphout bin_mh_assets

binscatter more_crime  pshock if winner1 == 1, absorb(sygroup) control(base_value ln_crim1 $con_controls ) xtitle("Price Shock") ytitle("Probability MLA Accumulates Additional Charges") savedata($tmp/bin_mh_crime) replace
graphout bin_mh_crime

