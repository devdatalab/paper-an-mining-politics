global con_controls pop_per_school con_pop rural_pop_share rural_electric_share

/*******************************/
/* MAIN REG: SELECTION CHANNEL */
/*******************************/
use $mining/mining_con_adr, clear
set_pshock, wt
global con_controls pop_per_school con_pop rural_pop_share rural_electric_share  mineral_herf

/* restrict to sample used for main specification, and confirm main spec works */
areg winner_any_crim pshock base_value $con_controls, cluster(sdgroup) absorb(sygroup)
keep if e(sample)

/* drop if crimes are unclassified */
drop if mi(winner_crime_violent_strong)

/* define government-related crime category */
foreach v in winner mean {
  egen `v'_crime_govt = rowmax(`v'_crime_corruption `v'_crime_publicservant `v'_crime_election)
}

/* create complement groups to each of these crime types */
foreach type in violent_strong govt {
  gen winner_crime_non_`type' = (winner_any_crim == 1) & (winner_crime_`type' == 0)
}

/******************/
/* VIOLENT CRIMES */
/******************/

/* get p-value for violent vs. nonviolent */
qui eststo on: reg winner_crime_violent_strong      pshock  $con_controls i.sygroup i.sdgroup
qui eststo off: reg winner_crime_non_violent_strong pshock  $con_controls i.sygroup i.sdgroup
suest on off, vce(cluster sdgroup)
di [on_mean]pshock ", " [off_mean]pshock 
test [on_mean]pshock = [off_mean]pshock
local violent_p: di %5.2f `r(p)'

/* get p-value for corruption vs. non-corruption */
qui eststo on:  reg winner_crime_govt      pshock  $con_controls i.sygroup i.sdgroup
qui eststo off: reg winner_crime_non_govt  pshock  $con_controls i.sygroup i.sdgroup
suest on off, vce(cluster sdgroup)
di [on_mean]pshock ", " [off_mean]pshock 
test [on_mean]pshock = [off_mean]pshock
local govt_p: di %5.2f `r(p)'

eststo clear

/* column 1: violent crimes only */
eststo: reghdfe winner_crime_violent_strong pshock $con_controls, cluster(sdgroup) absorb(sygroup sdgroup) 
store_depvar_mean y1, format("%04.2f")

/* column 2: non-violent crimes only */
eststo: reghdfe winner_crime_non_violent_strong pshock $con_controls, cluster(sdgroup) absorb(sygroup sdgroup)
store_depvar_mean y2, format("%04.2f")

/* column 3: corruption crimes only */
eststo: reghdfe winner_crime_govt pshock $con_controls, cluster(sdgroup) absorb(sygroup sdgroup) 
store_depvar_mean y3, format("%04.2f")

/* column 4: non-corruption crimes only */
eststo: reghdfe winner_crime_non_govt pshock $con_controls, cluster(sdgroup) absorb(sygroup sdgroup)
store_depvar_mean y4, format("%04.2f")

/* write estimates to a file */
global prefoot " \qquad \textit{p-value from difference} & & \textit{`violent_p'} & & \textit{`govt_p'}  \\"
global prefoot $prefoot "\hline State-Year F.E. & Yes & Yes & Yes & Yes \\ " 
global prefoot $prefoot "District F.E. & Yes & Yes & Yes & Yes \\ " "\hline "

label_mining_vars
label_pshocks
estout_default using $out/table_winner_violence, prefoot($prefoot) keep(pshock ) order(pshock )
estmod_header  using $out/table_winner_violence, cstring(" & \underline{Violent} & \underline{Non-violent} & \underline{Corruption} & \underline{Not Corruption}")
estmod_footer  using $out/table_winner_violence, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' ")

