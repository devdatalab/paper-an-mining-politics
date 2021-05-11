global con_controls pop_per_school con_pop rural_pop_share rural_electric_share mineral_herf

/* open ECI candidates / mining shocks database */
use $mining/mining_eci_candidates, clear

/* keep one obs per election */
keep if index == 1

/* set up pshocks and cluster groups */
set_pshock, wt

/* outcome table 1: full sample */
eststo clear
foreach v in incumbent turnout enop_vot {
  eststo: reghdfe `v' pshock  base_value $con_controls               , absorb(sygroup sdgroup) cluster(sdgroup)
  sum `v' if e(sample)
  local ym_`v'1: di %04.2f `r(mean)'

  eststo: reghdfe `v' pshock  base_value $con_controls if year > 2003, absorb(sygroup sdgroup) cluster(sdgroup)
  sum `v' if e(sample)
  local ym_`v'2: di %04.2f `r(mean)'
}
local prefoot `""\hline State-Year F.E. & Yes & Yes & Yes & Yes & Yes & Yes \\ " "District F.E. & Yes & Yes & Yes & Yes & Yes & Yes \\ "  "Years & All & Post-2003 & All & Post-2003 & All & Post-2003 \\ " "\hline ""'
label_pshocks
estout_default using $out/table_eci, prefoot(`prefoot') keep(pshock ) order(pshock ) 

/* put in a column divider and split header */
estmod_header  using $out/table_eci, cstring(" & \multicolumn{2}{c}{\underline{Incumbent}} & \multicolumn{2}{|c}{\underline{Turnout}} & \multicolumn{2}{|c}{\underline{ENOP}}")
estmod_footer  using $out/table_eci, cstring("Mean Dep. Var. & `ym_incumbent1' & `ym_incumbent2' & `ym_turnout1' & `ym_turnout2' & `ym_enop_vot1' & `ym_enop_vot2'")
shell sed -i 's/\*{6}{c}/cc|cc|cc/g' $out/table_eci.tex

cat $out/table_eci.tex
