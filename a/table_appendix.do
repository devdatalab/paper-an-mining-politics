global con_controls pop_per_school con_pop rural_pop_share rural_electric_share
global out ~/iec/output/mining

/************************************************************************/
/* program con_fe: Tables 3, 4, and 5 with constituency fixed effects   */
/************************************************************************/
cap prog drop con_fe
prog def con_fe

  /******************************************/
  /* TABLE 3-CON: CANDIDATE CHARACTERISTICS */
  /******************************************/
  eststo clear
  
  /* open ECI candidates / mining shocks database */
  use $mining/mining_eci_candidates, clear
  keep if index == 1
  set_pshock, wt
  regroup con_id_joint
  foreach v in bjp inc {
    eststo: reghdfe `v' pshock  base_value $con_controls, cluster(sdgroup) absorb(sygroup cgroup)
  }
  
  /* open ADR database */
  use $mining/mining_con_adr, clear
  set_pshock, wt
  regroup con_id_joint
  eststo: reghdfe winner_hs_grad pshock base_value   $con_controls, cluster(sdgroup) absorb(sygroup cgroup)
  eststo: reghdfe winner_age pshock base_value       $con_controls, cluster(sdgroup) absorb(sygroup cgroup)
  eststo: reghdfe ln_winner_net_assets pshock base_value $con_controls, cluster(sdgroup) absorb(sygroup cgroup)
  
  #delimit ;
  local prefoot `""\hline""';
  #delimit cr
  
  label_pshocks
  estout_default using $out/app_ed_age_con_fe,     prefoot(`prefoot') keep(pshock ) order(pshock ) 
  estmod_header  using $out/app_ed_age_con_fe.tex, cstring(" & BJP & INC & High School & Age & Log Net Assets")

  /****************************/
  /* TABLE 4-CON: CRIME TYPES */
  /****************************/

  // copy/pasted from $mcode/table_crime_type, added con_group f.e.
  use $mining/mining_con_adr, clear
  set_pshock, wt
  
  /* restrict to sample used for main specification, and confirm main spec works */
  areg winner_any_crim pshock base_value $con_controls, cluster(sdgroup) absorb(sygroup)
  keep if e(sample)
  
  drop if mi(winner_crime_violent_strong)
  foreach v in winner mean {
    egen `v'_crime_govt = rowmax(`v'_crime_corruption `v'_crime_publicservant `v'_crime_election)
  }
  foreach type in violent_strong govt {
    gen winner_crime_non_`type' = (winner_any_crim == 1) & (winner_crime_`type' == 0)
  }
  
  eststo clear
  
  /* column 1: violent crimes only */
  eststo: reghdfe winner_crime_violent_strong pshock $con_controls, cluster(sdgroup) absorb(sygroup con_group) 
  
  /* column 2: non-violent crimes only */
  eststo: reghdfe winner_crime_non_violent_strong pshock $con_controls, cluster(sdgroup) absorb(sygroup con_group)
  
  /* column 3: corruption crimes only */
  eststo: reghdfe winner_crime_govt pshock $con_controls, cluster(sdgroup) absorb(sygroup con_group) 
  
  /* column 4: non-corruption crimes only */
  eststo: reghdfe winner_crime_non_govt pshock $con_controls, cluster(sdgroup) absorb(sygroup con_group)
  
  /* write estimates to a file */
  global prefoot "\hline"
  
  label_mining_vars
  label_pshocks
  estout_default using $out/app_winner_violence_con_fe, prefoot($prefoot) keep(pshock ) order(pshock )
  estmod_header  using $out/app_winner_violence_con_fe.tex, cstring(" & \underline{Violent} & \underline{Non-violent} & \underline{Corruption} & \underline{Not Corruption}")

  /*************************************/
  /* TABLE 5: ELECTION COMPETITIVENESS */
  /*************************************/
  use $mining/mining_eci_candidates, clear
  keep if index == 1
  set_pshock, wt
  regroup con_id_joint
  
  eststo clear
  foreach v in incumbent turnout enop_vot {
    eststo: reghdfe `v' pshock  base_value $con_controls               , absorb(sygroup cgroup) cluster(sdgroup)
  }
  local prefoot "\hline"
  label_pshocks
  estout_default using $out/app_eci_con_fe, prefoot(`prefoot') keep(pshock ) order(pshock ) 
  estmod_header  using $out/app_eci_con_fe.tex, cstring(" & \underline{Incumbent} & \underline{Turnout} & \underline{ENOP}")
end
/** END program con_fe **************************************************/


/**********************************************************************************/
/* program mean_crim : Effect of price shock on mean candidate criminality       */
/**********************************************************************************/
cap prog drop mean_crim
prog def mean_crim
  eststo clear
  use $mining/mining_con_adr, clear

  set_pshock, wt
  
  /* label baseline vars */
  label var base_winner_any_crim "Criminal MLA (prev period)"
  label var base_mean_any_crim "Mean MLA Criminality (prev period)"

  /* Column 1 - con_id_joint price shock, state*year fixed effects */
  eststo: reghdfe mean_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup)
  store_depvar_mean ym1, format("%04.2f")

  /* Column 2 - district fixed effects */
  eststo: reghdfe mean_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean ym2, format("%04.2f")
  
  /* Column 3 - constituency fixed effects */
  eststo: reghdfe mean_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup con_group)
  store_depvar_mean ym3, format("%04.2f")
  
  /* repeat those three columns with runner up crime level */
  eststo: reghdfe runnerup_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup)
  store_depvar_mean ym4, format("%04.2f")
  eststo: reghdfe runnerup_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean ym5, format("%04.2f")
  eststo: reghdfe runnerup_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup con_group)
  store_depvar_mean ym6, format("%04.2f")
  
  #delimit ;
  local prefoot `""\hline State-Year F.E.     & Yes & Yes & Yes & Yes & Yes & Yes  \\ "
                        " District F.E.       & No  & Yes & No  & No  & Yes & No   \\ "
                        " Constituency F.E.   & No  & No  & Yes & No  & No  & Yes  \\ " "\hline ""';
  #delimit cr
  
  label_mining_vars
  label_pshocks
  estout_default using $out/mean_crim, prefoot(`prefoot') keep(pshock ) order(pshock )
  estmod_footer  using $out/mean_crim, cstring("Mean Dep. Var. & `ym1' & `ym2' & `ym3' & `ym4' & `ym5' & `ym6' ")
end
/* *********** END program mean_crim ***************************************** */

/**************************************************************************/
/* program no_iron_coal_regs : Exclude iron, coal, and Naxalite areas     */
/**************************************************************************/
cap prog drop no_iron_coal_regs
prog def no_iron_coal_regs

  /* open ADR dataset */
  use $mining/mining_con_adr, clear

  /* get list of naxalite affected areas */
  merge m:1 pc01_state_id pc01_district_id using $tmp/pc01_naxalite_districts, keep(master match) nogen
  eststo clear
  
  /* price shocks not counting coal and/or iron */
  local c 1
  foreach v in ps_wt_glo_f2_m6_nc ps_wt_glo_f2_m6_ni ps_wt_glo_f2_m6_nic {
    replace pshock = `v'
    label_pshocks
    eststo: reghdfe winner_any_crim pshock base_value , cluster(sdgroup) absorb(sygroup)
    store_depvar_mean y`c', format("%04.2f")
    local c = `c' + 1
  }
  
  /* back to basic price shock */
  set_pshock, wt
  
  /* drop coal locations */
  eststo: reghdfe winner_any_crim pshock base_value if any_coal == 0,                 cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y4, format("%04.2f")
  eststo: reghdfe winner_any_crim pshock base_value if any_iron == 0,                 cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y5, format("%04.2f")
  eststo: reghdfe winner_any_crim pshock base_value if any_coal == 0 & any_iron == 0, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y6, format("%04.2f")
 
  // /* drop naxalite locations */
  gen sample = !inlist(pc01_state_name, "jharkhand", "chhattisgarh", "andhra pradesh", "orissa")
  eststo: reghdfe winner_any_crim pshock base_value if naxal_district_oliver != 1, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y7, format("%04.2f")
  eststo: reghdfe winner_any_crim pshock base_value if sample == 1, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y8, format("%04.2f")
  
  label_mining_vars
  label_pshocks
  #delimit ;
  local prefoot `" "\hline Price Shock   & No coal & No iron & No coal/iron & No coal & No iron & No coal/iron & All & All \\ "
                   "Constituency Sample  & All     &     All & All          & No coal & No iron & No coal/iron & No Naxalite States & No Naxalite Districts \\ "
                   "State-Year F.E. & Yes & Yes & Yes & Yes & Yes & Yes & Yes & Yes\\ " "\hline " "';
  #delimit cr
  
  estout_default using $out/app_no_iron_coal_regs, prefoot(`prefoot') keep(pshock ) order(pshock )
  estmod_footer  using $out/app_no_iron_coal_regs, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' & `y5' & `y6' & `y7' & `y8' ")

end
/* *********** END program no_iron_coal_regs ***************************************** */

/**********************************************************************************/
/* program alt_pshock_regs : Robustness to f0/f2, and m5->0 vs m6->m1, etc..      */
/**********************************************************************************/
cap prog drop alt_pshock_regs
prog def alt_pshock_regs

  /* open ADR dataset */
  use $mining/mining_con_adr, clear
  eststo clear
  set_pshock, wt
  
  /* f0, f1 */
  replace pshock = ps_wt_glo_f1_m6
  eststo: reghdfe winner_any_crim pshock base_value , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean y1, format("%04.2f")

  /* m5 */
  replace pshock = ps_wt_glo_f2_m5
  eststo: reghdfe winner_any_crim pshock base_value , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean y2, format("%04.2f")

  /* lowest (any) production cutoff */
  use $tmp/mining_con_adr_0001, clear
  set_pshock, wt
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean y3, format("%04.2f")

  /* low (1/2 x) production cutoff */
  use $tmp/mining_con_adr_2260, clear
  set_pshock, wt
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean y4, format("%04.2f")

  /* higher (2x) production cutoff */
  use $tmp/mining_con_adr_9040, clear
  set_pshock, wt
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean y5, format("%04.2f")

  /* main result, state clusters */
  use $mining/mining_con_adr, clear
  set_pshock, wt
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sgroup) absorb(sygroup sdgroup)
  store_depvar_mean y6, format("%04.2f")

  /*******************/
  /* placebo shocks  */
  /*******************/
  /* create dataset with dummy variable for any production in constituency at any time */
  use $mining/mine_prod_con, clear
  collapse (max) con_min_value con_min_value_lg con_min_emp, by(con_id_joint)
  drop if con_min_emp == 0 & con_min_value == 0
  assert !mi(con_min_value) & !mi(con_min_emp)
  save $tmp/producing_cons, replace
  
  /* open deposit only dataset */
  use $mining/mining_con_adr_deps_only, clear
  
  /* merge locations with production */
  merge m:1 con_id_joint using $tmp/producing_cons, keepusing(con_min_value)
  
  /* keep unmatched -- these are best guesses at zero production places */
  keep if _merge == 1
  keep if num_deps_wt_lg == 0
  save $tmp/placebo_spec, replace
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean y7, format("%04.2f")
  
  #delimit ;
  local prefoot `""\hline State-Year F.E.      & Yes & Yes & Yes & Yes & Yes & Yes & Yes \\ "
                  "       District-Year F.E.   & Yes & Yes & Yes & Yes & Yes & Yes & Yes \\ "
                        "\hline ""';
  #delimit cr

  label_mining_vars
  label_pshocks

  /* make label vague, since column 2 is -5 -> 0 */
  label var pshock "Price Shock"
  estout_default using $out/app_alt_pshock_regs, prefoot(`prefoot') order(pshock )
  estmod_header  using $out/app_alt_pshock_regs, cstring(" & Baseline   & Shock_{-5,0} & Prod above & Prod above & Prod above & State    & Placebo \\\\ &  1990-2003 &              &  0   &   USD 50k   &  USD 200k  & Clusters & Fixed Effects & ")
  estmod_footer  using $out/app_alt_pshock_regs, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' & `y5' & `y6' & `y7' ")
end
/* *********** END program alt_pshock_regs ***************************************** */

/**********************************************************************************/
/* program ts_no_movers : Show TS results robust when candidates don't move       */
/**********************************************************************************/
cap prog drop ts_no_movers
prog def ts_no_movers

  // /* calculate mean distance between villages and a constituency centroid */
  // use $keys/village_con_key_2008, clear
  // merge 1:1 pc01_state_id pc01_village_id using ~/iec/pc01/geo/village_coords_clean, nogen keep(match)
  // 
  // keep con_id lat lon pc01_state_id pc01_village_id 
  // 
  // /* calculcate centroid */
  // bys con_id: egen center_lat = mean(lat) 
  // bys con_id: egen center_lon = mean(lon) 
  // 
  // /* generate distance to centroid */
  // gen dist_to_center = sqrt((center_lat - lat) ^ 2 + (center_lon - lon) ^ 2)
  // 
  // /* convert to km */
  // replace dist_to_center = dist_to_center * 110
  // 
  // /* review */
  // sum dist_to_center, d
  // 
  // /* generate distribution of latitude / longitude width of constituencies */
  // bys con_id: egen min_lat = min(lat) 
  // bys con_id: egen max_lat = max(lat)
  // gen lat_width = (max_lat - min_lat) * 110
  // bys con_id: egen min_lon = min(lon) 
  // bys con_id: egen max_lon = max(lon) 
  // gen lon_width = (max_lon - min_lon) * 110
  // 
  // /* summarize */
  // egen diameter = rowmax(lon_width lat_width)
  // sum diameter, d
  // /* suggests mean diameter of a constituency is 46km */
  
  /*******************************************************************************/
  /* RUN MAIN SPEC IN MATCHED CANDIDATE SAMPLE (to control for distance effects) */
  /*******************************************************************************/

  use $tmp/adr_ts2_mine_shocks, clear

  /* set the price shock for year 2 (since we look at selection in year 2) */
  set_pshock, wt
  ren year1 year

  /* only examine winners -- this becomes con-level */
  keep if winner2 == 1
  
  /* define criminal winner as candidate is winner and a criminal */
  gen winner_any_crim2 = any_crim2 

  /* regroup */
  regroup pc01_state_id year
  regroup pc01_state_id pc01_district_id
  
  /* repeat main spec in this sample to show it holds */
  eststo clear
  
  /* note -- no district f.e. here, because no time series */
  eststo: reghdfe winner_any_crim2 pshock base_value, cluster(sygroup) absorb(sygroup)
  store_depvar_mean y1, format("%04.2f")

  /* repeat for sample of winners with distance < 10km, 20km */
  eststo: reghdfe winner_any_crim2 pshock base_value $con_controls if dist < 20, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y2, format("%04.2f")
  eststo: reghdfe winner_any_crim2 pshock base_value $con_controls if dist < 10, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y3, format("%04.2f")
  eststo: reghdfe winner_any_crim2 pshock base_value $con_controls if dist < 5, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y4, format("%04.2f")

  /* write output file */
  local prefoot `"  "\hline"  "State-Year F.E. & Yes & Yes & Yes & Yes \\ " "\hline "  "'
  label_pshocks
  estout_default using $out/app_winner_dist, prefoot(`prefoot') order(pshock) keep(pshock)
  estmod_header  using $out/app_winner_dist, cstring(" & All & Moved $<$ 20km & Moved $<$ 10km & Moved $<$ 5km")
  estmod_footer  using $out/app_winner_dist, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' ")
end
/* *********** END program ts_no_movers ***************************************** */

/**********************************************************************************/
/* program alt_crime_specs : different crime definitions for time series       */
/**********************************************************************************/
cap prog drop alt_crime_specs
prog def alt_crime_specs
  eststo clear
  
  /* show main table result also holds up with different crime definitions */
  use $mining/mining_con_adr, clear
  gen ln_winner_num_crim = ln(winner_num_crim + 1)

  /* create a separate pshock var so estout can label it correctly */
  label_pshocks, m(m6)
  ren pshock pshock_as
  d pshock_as
 
  /* adverse selection regressions */
  eststo: reghdfe winner_num_crim pshock_as base_value $con_controls , cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y1, format("%04.2f")
  eststo: reghdfe ln_winner_num_crim pshock_as base_value $con_controls , cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y2, format("%04.2f")
 
  use $tmp/adr_ts2_mine_shocks, clear

  /* calculate change in number of crimes and change in log number */
  gen diff_num_crimes = num_crim2 - num_crim1
  gen ln_diff_num_crimes = ln(num_crim2 + 1) - ln(num_crim1 + 1)
  
  /* moral hazard regressions */
  eststo: reghdfe diff_num_crimes pshock base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y3, format("%04.2f")
  eststo: reghdfe ln_diff_num_crimes pshock base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y4, format("%04.2f")
  
  /* set up linear combination content row */
  local prefoot `""\hline" "State-Year F.E. & Yes & Yes & Yes & Yes \\ " "\hline ""'

  /* create empty pshock so estout gets label right */
  gen pshock_as = 0
  label var pshock_as "Price shock\$_{-6,-1}$"
 
  /* write output file */
  label_pshocks, m(m5)
  estout_default using $out/app_crime_alt, prefoot(`prefoot') order(pshock_as pshock) keep(pshock_as pshock)
  estmod_header  using $out/app_crime_alt, cstring(" & \multicolumn{2}{c}{\underline{Adverse Selection}} & \multicolumn{2}{c}{\underline{Moral Hazard (Differences)}} \\\\  & Num Crime & Log Num Crime & Num Crime & Log Num Crime ")
  estmod_footer  using $out/app_crime_alt, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' ")
  cat $out/app_crime_alt.tex
end
/* *********** END program alt_crime_specs ***************************************** */

/**********************************************************************************/
/* program deposit_defs : Insert description here */
/***********************************************************************************/
cap prog drop deposit_defs
prog def deposit_defs
{
  
  eststo clear

  /* main spec: exact deposit location regs */
  use $mining/mining_con_adr, clear
  set_pshock,

  /* column 1 -- main spec w.state-year f.e. */
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y1, format("%04.2f")
  
  /* column 2 -- add district f.e. */
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean y2, format("%04.2f")

  /* column 3 -- add con f.e. */
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup con_group)
  store_depvar_mean y3, format("%04.2f")

  /* switch to deposits only dataset, same three columns */
  use $mining/mining_con_adr_deps_only, clear
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y4, format("%04.2f")
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
  store_depvar_mean y5, format("%04.2f")
  eststo: reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup con_group)
  store_depvar_mean y6, format("%04.2f")

  #delimit ;
  local prefoot `""\hline State-Year F.E. & Yes & Yes & Yes & Yes & Yes & Yes \\ "
                          "District   F.E.     & No  & Yes & No & No  & Yes & No \\ "
                          "Constituency   F.E. & No  & No  & Yes & No  & No  & Yes \\ "
                 "\hline ""';
  #delimit cr
  label_mining_vars
  label_pshocks
  estout_default using $out/main_deposit_defs, prefoot(`prefoot') keep(pshock) order(pshock)
  estmod_header  using $out/main_deposit_defs, cstring(" & \multicolumn{3}{c}{\underline{Exact Deposit Locations}} & \multicolumn{3}{c}{\underline{Deposits Only}}")
  estmod_footer  using $out/main_deposit_defs, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' & `y5' & `y6' ")

  }
end
/* *********** END program deposit_defs ***************************************** */

/**********************************************************************************/
/* program ts_robust : Time series robustness tables                              */
/**********************************************************************************/
cap prog drop ts_robust
prog def ts_robust
{
  /*****************/
  /* deposits only */
  /*****************/
  use $tmp/adr_ts2_mine_shocks, clear
  eststo clear
  set_pshock, m(m5)
  eststo: reghdfe ln_diff_net_assets pshock base_value ln_net_assets1 $con_controls if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  eststo: reghdfe more_crime pshock base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)

  /* f0 */
  replace pshock = ps_wt_glo_f0_m5
  eststo: reghdfe ln_diff_net_assets pshock base_value ln_net_assets1 $con_controls if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  eststo: reghdfe more_crime pshock base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)

  use $tmp/adr_ts2_mine_shocks_9040, clear
  regroup pc01_state_id pc01_district_id
  regroup pc01_state_id year1
  set_pshock, wt m(m5)
  eststo: reghdfe ln_diff_net_assets pshock base_value ln_net_assets1 $con_controls if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  eststo: reghdfe more_crime pshock base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)

  use $tmp/adr_ts2_mine_shocks_2260, clear
  regroup pc01_state_id pc01_district_id
  regroup pc01_state_id year1
  set_pshock, wt m(m5)
  eststo: reghdfe ln_diff_net_assets pshock base_value ln_net_assets1 $con_controls if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  eststo: reghdfe more_crime pshock base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  
  local prefoot `""\hline" "State-Year F.E. & Yes & Yes & Yes & Yes & Yes & Yes & Yes & Yes \\ " "\hline ""'
  label_pshocks, m(m5)
  estout_default using $out/app_ts_robust, prefoot(`prefoot') order(pshock) 
  estmod_header  using $out/app_ts_robust.tex, cstring(" & Assets & Crime & Assets & Crime & Assets & Crime & Assets & Crime")

}
end
/* *********** END program ts_robust ***************************************** */





/*************************************************************************/
/* program mh_lag_pshocks: Moral Hazard Tests with lagged price shocks   */
/*************************************************************************/
cap prog drop mh_lag_pshocks
prog def mh_lag_pshocks

  /* show results robust to controlling for earlier price shocks */
  use $tmp/adr_ts2_mine_shocks, clear
  
  /* get pshock for prior year */
  gen year = year1
  drop ps_wt*
  merge m:1 con_id_joint year using $mining/con_mine_shocks, keepusing(ps_wt_glo_f2_m5) keep(match) nogen
  gen pshock_lag = ps_wt_glo_f2_m5
  gen pshock_lag_winner = pshock_lag * winner1

  /* set up fixed effect row */
  local prefoot `""\hline" "State-Year F.E. & Yes & Yes & Yes & Yes & Yes \\ " "\hline ""'
  label_pshocks, m(m5)
  label var pshock_lag "Price shock\$_{-5,-1}$ (lagged)"
  label var pshock_lag_winner "Price shock\$_{-5,-1}$ (lagged) * Winner"
  
  /* assets */
  eststo clear
  eststo: reghdfe ln_diff_net_assets pshock pshock_lag base_value ln_net_assets1 $con_controls if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y1, format("%04.2f")
  eststo: reghdfe ln_diff_net_assets pshock pshock_winner pshock_lag_winner pshock_lag winner1 base_value ln_net_assets1 $con_controls, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y2, format("%04.2f")
  
  /* crimes */
  eststo: reghdfe more_crime pshock pshock_lag base_value $con_controls ln_crim1 if winner1 == 1, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y3, format("%04.2f")
  eststo: reghdfe more_crime pshock pshock_winner pshock_lag pshock_lag_winner winner1 base_value $con_controls ln_crim1, cluster(sdgroup) absorb(sygroup)
  store_depvar_mean y4, format("%04.2f")
  
  /* write output file */
  local prefoot `""\hline" "State-Year F.E. & Yes & Yes & Yes & Yes \\ " "\hline ""'
  estout_default using $out/app_ts_lag, prefoot(`prefoot') order(pshock pshock_winner winner1 pshock_lag pshock_lag_winner) 
  estmod_header  using $out/app_ts_lag, cstring(" & \multicolumn{2}{c}{\underline{Change in Assets}} & \multicolumn{2}{|c}{\underline{Change in Crime}}")
  estmod_footer  using $out/app_ts_lag, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' ")
end
/** END program mh_lag_pshocks*******************************************/


/*******************/
/* APPENDIX TABLES */
/*******************/

/* Table: different criminal definitions */
alt_crime_specs

/* Table: all main results with constituency fixed effects */
con_fe

/* Table: mean and runner-up candidate crime */
mean_crim

/* Table: Bartik shocks */
do $mcode/app_table_bartik

/* Table: Rainfall shocks */
do $mcode/app_table_rainfall

/* Table: Spatial spillovers */
do $mcode/app_table_spillovers

/* Table: alternate deposit definitions */
deposit_defs

/* Table: alternate price shock regressions */
alt_pshock_regs

/* Table: time series robustness to pshock definitions */
ts_robust

/* Table: iron / coal area exclusions */
no_iron_coal_regs

/* Table: no movers */
ts_no_movers

/* lagged pshocks on moral hazard regs */
mh_lag_pshocks

/* moral hazard attrition graph */
do $mcode/app_graph_mh_attrition

/* crime breakdown table */
do $mcode/app_table_crime_breakdown

