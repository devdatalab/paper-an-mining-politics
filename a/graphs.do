/***************************/
/* SUMMARY STATS of PSHOCK */
/***************************/

/* show price movement of each constituency over time */
use $tmp/cons_deposits_prices, clear

xtset cmgroup year

/* drop minerals with broken price numbers */
drop if mineral == "pyrite" 

/* get number deposits in each location */
bys con_id_joint year: egen num_deps_con = total(num_deps)

foreach i in 1 5 {
  sort cmgroup year
  gen ps`i' = global_price / L`i'.global_price
      
  /* multiply price shock by base value to create precollapse shock component */
  /* don't need lead/lag indices, because base value / num deposits is time-invariant */
  gen ps`i'_part = ps`i' * num_deps
      
  /* calculate total price shock part by adding up shocks across all minerals in a place */
  bys con_id_joint year: egen ps`i'_unscaled = total(ps`i'_part)
  replace ps`i'_unscaled = . if ps`i'_unscaled == 0
   
  /* rescale by number of deposits */
  gen ps`i'_final = ps`i'_unscaled / num_deps_con
}

keep con_id_joint year ps1_final ps5_final
duplicates drop

save $tmp/con_ps_year, replace

/* restrict to constituencies with value */
use $mining/con_mine_shocks.dta, clear
keep if value_wt_f2 > 0 & !mi(value_wt_f2)

keep if strlen(con_id_joint) == 12
keep con_id_joint
duplicates drop
save $tmp/mineral_con_ids, replace

use $tmp/con_ps_year, clear
merge m:1 con_id_joint using $tmp/mineral_con_ids, nogen keep(matched)
keep if year > 2000
codebook con_id_joint
group con_id_joint

save $tmp/foo, replace

/* limit to sample years */
keep if inrange(year, 2003, 2017)
histogram ps5_final if ps5 < 3, color(gs8) lcolor(black) width(.1) start(.4) xtitle("5-year Cumulative Price Shock") fraction
graphout ps5_summary, pdf


