/*****************************************/
/* DRAFT CANDIDATE TIME SERIES OUTCOMES  */
/*****************************************/
global con_controls pop_per_school con_pop rural_pop_share rural_electric_share

/********/
/* MAIN */
/********/
use $mining/adr_ts2_mine_shocks, clear

/**************/
/* asset regs */
/**************/
eststo clear

/* pshock -- winners only */
eststo: reghdfe ln_diff_net_assets base_value pshock ln_net_assets1 $con_controls if winner1 == 1, cluster(sdgroup) absorb(sygroup)
estadd ysumm
local ym1: di %04.2f `e(ymean)'

/* pshock -- winner vs losers */
eststo: reghdfe ln_diff_net_assets base_value pshock pshock_winner winner1 ln_net_assets1 $con_controls, cluster(sdgroup) absorb(sygroup)
estadd ysumm
local ym2: di %04.2f `e(ymean)'

/* pshock -- winners vs losers, interact with baseline violent crime */
gen pshock_violent = pshock * crime_violent1
gen winner_violent = winner1 * crime_violent1
gen pshock_winner_violent = pshock * winner1 * crime_violent1

label var pshock_violent "Price shock$_{+1,+5}$ * Violent"
label var winner_violent "Winner * Violent"
label var pshock_winner_violent "Price shock$_{+1,+5}$ * Winner * Violent"
label var crime_violent1 "Violent Crime"

/* winners vs losers * violence */
eststo: reghdfe ln_diff_net_assets base_value pshock pshock_violent pshock_winner winner_violent pshock_winner_violent winner1 crime_violent1 ln_net_assets1, cluster(sdgroup) absorb(sygroup)
estadd ysumm
local ym3: di %04.2f `e(ymean)'

/**************/
/* crime regs */
/**************/
eststo: reghdfe more_crime pshock base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)
estadd ysumm
local ym4: di %04.2f `e(ymean)'
eststo: reghdfe more_crime pshock pshock_winner winner1 base_value $con_controls ln_crim1, cluster(sdgroup) absorb(sygroup)
sum more_crime if e(sample)
local ym5: di %04.2f `r(mean)'

/* set up fixed effect row */
local prefoot `""\hline" "State-Year F.E. & Yes & Yes & Yes & Yes & Yes \\ " "\hline ""'
label_pshocks, m(m5)

/* write output file */
estout_default using $out/table_ts, prefoot(`prefoot') order(pshock pshock_winner pshock_violent pshock_winner_violent crime_violent1 winner1 winner_violent pshock_winner) 
estmod_col_div using $out/table_ts, col(3)
estmod_header  using $out/table_ts, cstring(" & \multicolumn{3}{c}{\underline{Change in Assets}} & \multicolumn{2}{|c}{\underline{Change in Crime}}")
estmod_footer  using $out/table_ts, cstring("Mean Dep. Var. & `ym1' & `ym2' & `ym3' & `ym4' & `ym5'")

