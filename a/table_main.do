global con_controls pop_per_school con_pop rural_pop_share rural_electric_share

/***************************************/
/* TABLE 2: PRICE SHOCK ON CRIMINALITY */
/***************************************/

eststo clear
use $mining/mining_con_adr, clear

set_pshock, wt

/* Column 1 - con_id_joint price shock, state*year fixed effects */
eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup)
estadd ysumm
local ym1: di %04.2f `e(ymean)'

reg winner_any_crim pshock base_value $con_controls i.sygroup, cluster(sdgroup) 

/* calculate effect size */
sum pshock if e(sample), d
local effect: di (`r(p75)' - `r(p25)') * _b["pshock"]
sum winner_any_crim
di `effect' / `r(mean)'

/* Column 2 - district fixed effects -- takes out almost all x-section component */
eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
estadd ysumm
local ym2: di %04.2f `e(ymean)'

/* Column 3 - add con fixed effects -- same effect, slightly bigger standard error [sample size drops due to cons that appear only once] */
eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup con_group)
estadd ysumm
local ym3: di %04.2f `e(ymean)'

/* Column 4 -- Probit of column 1 */
probit winner_any_crim pshock base_value $con_controls i.sygroup , cluster(sdgroup)
eststo: margins, dydx(pshock) coeflegend post
estout

#delimit ;
local prefoot `""\hline State-Year F.E.      & Yes & Yes & Yes & Yes \\ "
                      " District F.E.        & No  & Yes & Yes & No  \\ "
                      " Constituency F.E.    & No  & No  & Yes & No  \\ " "\hline ""';
#delimit cr

label_mining_vars
label_pshocks
estout_default using $out/table_winner, prefoot(`prefoot') keep(pshock) order(pshock)
estmod_footer using $out/table_winner.tex, cstring("Mean Dep. Var. & `ym1' & `ym2' & `ym3' & `ym1' ")

/***************************************************/
/* TABLE 3: NO OTHER WINNER CHARACTERISTIC CHANGES */
/***************************************************/
eststo clear

/* open ECI candidates / mining shocks database */
use $mining/mining_eci_candidates, clear

/* keep one obs per election */
keep if index == 1

/* set up pshocks and cluster groups */
set_pshock, wt

/* Did congress win? */
foreach v in bjp inc {
  eststo: reghdfe `v' pshock  base_value $con_controls, cluster(sdgroup) absorb(sygroup sdgroup)
  estadd ysumm
  local ym_`v': di %04.2f `e(ymean)'
}

/* open ADR database */
use $mining/mining_con_adr, clear
set_pshock, wt

/* is winner more educated? */
eststo: reghdfe winner_hs_grad pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
estadd ysumm
local ym3: di %04.2f `e(ymean)'

/* is winner older? */
eststo: reghdfe winner_age pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
estadd ysumm
local ym4: di %4.1f `e(ymean)'

/* does winner have more net assets? */
eststo: reghdfe ln_winner_assets pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
sum ln_winner_assets if e(sample)
local ym5: di %4.1f `r(mean)'

#delimit ;
local prefoot `""\hline State-Year F.E.      & Yes & Yes & Yes & Yes & Yes \\ "
                      " District F.E.   & Yes  & Yes  & Yes & Yes  &  Yes \\ " "\hline ""';
#delimit cr
get_ecol_header_string

label_pshocks
estout_default using $out/table_ed_age,     prefoot(`prefoot') keep(pshock ) order(pshock ) 
estmod_header  using $out/table_ed_age.tex, cstring(" & BJP & INC & High School & Age & Log Net Assets")
estmod_footer  using $out/table_ed_age.tex, cstring("Mean Dep. Var. & `ym_bjp' & `ym_inc' & `ym3' & `ym4' & `ym5' ")
