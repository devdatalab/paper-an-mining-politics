/******************************************************/
/* number of changed data points from ADR vs. Prakash */
/******************************************************/

/* compare key variable for us, which is any_crim */
use $adr/affidavits_clean, clear
keep if source == "prakash-eci"
ren any_crim new_any_crim
ren num_crim new_num_crim

merge 1:1 year ac_id adr_cand_id using $adr/adr_candidates_combined, keepusing(any_crim num_crim) keep(match) nogen

tab any_crim new_any_crim
di (26 + 109) / (3287 + 1309 + 26 + 109)

compare num_crim new_num_crim

/******************************/
/* count numbers for figure 1 */
/******************************/

/* final observation count */
use $mining/mining_con_adr, clear
reghdfe winner_any_crim pshock base_value $con_controls , cluster(sdgroup) absorb(sygroup)
keep if e(sample)
obs_check if year > 2007, tag(ac_id)

/* number of constituency ids */
use $keys/con_key_2008, clear
count

/* deposits in atlas */
use $mining/atlas/atlas_clean, clear
count

/* districts with mineral production */
use $mining/mine_prod_district, clear
collapse (sum) prod value empo_tot_emp, by(state district)
drop if prod == 0
count

/* constituencies with mineral deposits */
use $tmp/mine_deposits_con08, clear
count if num_deps > 0

/* get list of minerals for price data */
use $mining/mineral_prices_combined, clear
keep if !mi(global_price)  & global_price != 0
keep mineral
duplicates drop
save $tmp/mineral_list, replace

/* constituencies with mineral production */
use $mining/con_mine_shocks, clear
set_pshock, wt
keep if !mi(pshock) & !mi(con_id08)
distinct con_id08

/* and matched to affidavits */
duplicates drop con_id_joint, force
merge 1:m con_id_joint using $adr/affidavits_ac, keepusing(winner_any_crim)
keep if _merge == 3
duplicates drop con_id_joint, force


/* calculate average exchange rate from 2003 to 2017 */
use $mining/xrat, clear
sum xrat if inrange(year, 1990, 2017)
di 100000 * 51

/* define value cutoff */
global min_con_value 4520

cap log close
log using $tmp/mining_counts.txt, text replace

qui {

  local wt _wt
  local delim predelim

  /***********************************/
  /* Deposit-Constituency Matching   */
  /***********************************/
  noi disp_nice "Mineral Atlas"

  /* number of deposits in atlas */
  use $mining/atlas/atlas_clean, clear
  count
  local atlas_num_deps = `r(N)'
  noi di %55s "Number of deposits in mineral atlas: " %3.0f (`r(N)')

  /* open constituency-deposit dataset */
  use ~/iec/pworking/cons_deposits, clear

  /* tag predelim so don't double count constituencies */
  gen l = strlen(con_id_joint)
  gen predelim = (l == 7)
  
  noi disp_nice "Deposits and Constituencies"
  
  /* number of deposits */
  sum num_deps if `delim'
  local con_num_deps = `r(N)' * `r(mean)'
  noi di %55s "***Number of deposits matched to cons: " %3.0f (`con_num_deps')

  /* UNWEIGHTED */
  noi di _n "UNWEIGHTED"
  
  /* number of con-ids with a deposit */
  obs_check if num_deps > 0 & `delim', tag(con_id_joint)
  local cons_dep = r(N)
  local deps_per_con = `con_num_deps' / `cons_dep'
  noi di %55s "Number of predelim con-id-joints with deposits (2 periods): " %3.0f (r(N)) ", or " %5.2f (`deps_per_con') " deposits per mineral constituency"

  /* number of mineral-con-id pairs (in between above #s because may have two small limestone deposits in one place)  */
  obs_check if num_deps > 0, tag(con_id_joint mineral)
  noi di %55s "Number of con-mineral pairs: " %3.0f (r(N))
  
  obs_check if num_deps > 0, tag(con_id_joint mineral deposit_size)
  noi di %55s "Number of con-mineral-size pairs: " %3.0f (r(N))

  /* number of con_ids */
  gen con_id = substr(con_id_joint, 1, 7)
  obs_check if num_deps > 0, tag(con_id)
  noi di %55s "Number of con-ids with deposits: " %3.0f (r(N))
  
  /* WEIGHTED */
  noi di _n "WEIGHTED"
  
  obs_check if num_deps_w > 0 & `delim', tag(con_id_joint)
  noi di %55s "***Number of cons near deposits: " %3.0f (r(N))
  
  obs_check if num_deps_w > 0 & `delim', tag(con_id_joint mineral)
  noi di %55s "Number of con-mineral_wt pairs: " %3.0f (r(N))
  
  obs_check if num_deps_w > 0 & `delim', tag(con_id_joint mineral deposit_size)
  noi di %55s "Number of con-mineral_wt-size pairs: " %3.0f (r(N))

  /***********************************/
  /* Constituencies              */
  /***********************************/
  noi disp_nice "Deposit-Production and Constituencies (mine_prod_con.dta)"

  /* open con-district match */
  use $tmp/smi_con, clear

  /* tag predelim so don't double count constituencies */
  gen l = strlen(con_id_joint)
  gen predelim = (l == 7)
  
  obs_check if `delim', tag(con_id_joint)
  noi di %55s "Number of cons in con_prod file (unmatched to deposits): " %3.0f (r(N))  
  
  /* open con-production after deposit-production match */
  use $mining/mine_prod_con, clear

  /* collapse to places with value in any year */
  collapse (mean) num_deps* con_min*, by(mineral con_id_joint)

  /* tag predelim so don't double count constituencies */
  gen l = strlen(con_id_joint)
  gen predelim = (l == 7)

  /* UNWEIGHTED */
  if mi("`wt'") {
    noi di _n "UNWEIGHTED"
  }
  else {
    noi di _n "WEIGHTED"
  }
  noi di "----------"
  noi di "MEAN PRODUCTION, ALL YEARS"

  assert !mi(num_deps`wt')
  assert !mi(con_min_value`wt')

  obs_check if num_deps`wt' != 0 & `delim', tag(con_id_joint)
  noi di %55s "Number of cons with deposits: " %3.0f (r(N))  
  
  sum num_deps`wt' if con_min_value`wt' > 0 & `delim'
  local prod_num_deps = `r(N)' * `r(mean)'
  noi di %55s "***Number of deposits with production: " %3.0f (`prod_num_deps')

  /* calculate total constituency production */
  bys con_id_joint: egen total_con_min_value_wt = total(con_min_value_wt)
  sum num_deps`wt' if con_min_value`wt' > 0 & `delim' & total_con_min_value_wt > 4520 & !mi(total_con_min_value_wt)
  local prod_num_deps_value = `r(N)' * `r(mean)'
  noi di %55s "***Number of deposits with production > $min_con_value: " %3.0f (`prod_num_deps_value')

  /* number of cons with productive deposits */
  obs_check if num_deps`wt' > 0 & con_min_value`wt' > 0 & `delim', tag(con_id_joint)
  local cons_prod = r(N)
  noi di %55s "Number of con-ids with producing deposits: " %3.0f (r(N))
  
  /* number of con-mineral pairs */
  count if num_deps`wt' > 0 & !mi(num_deps`wt') & `delim'
  noi di %55s "Number of con-mineral pairs: " %3.0f (r(N))

  /* size distribution of max con value */
  noi di "Distribution of mineral value across constituency-minerals:  (commented out)"
  // noi sum con_min_value`wt' if num_deps`wt' > 0 & !mi(num_deps`wt'), d

  noi di _n "WITH PRODUCTION BETWEEN 1990-2004 (mine_prod_con)"

  /* just keep 2004 */
  use $mining/mine_prod_con, clear
  assert !mi(num_deps`wt')
  assert !mi(con_min_value`wt')

  /* tag predelim so don't double count constituencies */
  gen l = strlen(con_id_joint)
  gen predelim = (l == 7)

  obs_check if num_deps`wt' > 0 & `delim', tag(con_id_joint)
  noi di %55s "Cons with deposits: " %3.0f (r(N))
  
  obs_check if num_deps`wt' > 0 & `delim' & con_min_value`wt' > 0, tag(con_id_joint)
  noi di %55s "Cons with producing deposits: " %3.0f (r(N))
  
  obs_check if num_deps`wt' > 0 & `delim' & con_min_value`wt' > 0 & inrange(year, 1981, 2014), tag(con_id_joint)
  local con_prod_f0 `r(N)'
  noi di %55s "Cons with producing deposits (f0: 1981-2014): " %3.0f (r(N))
  
  obs_check if num_deps`wt' > 0 & `delim' & con_min_value`wt' > 0 & inrange(year, 1981, 2004), tag(con_id_joint)
  noi di %55s "Cons with producing deposits (f1: 1981-2004): " %3.0f (r(N))

  obs_check if num_deps`wt' > 0 & `delim' & con_min_value`wt' > 0 & inrange(year, 1990, 2004), tag(con_id_joint)
  local con_prod_f2 `r(N)'
  noi di %55s "***Cons with producing deposits (f2: 1990-2004): " %3.0f (r(N))

  bys con_id_joint year: egen total_con_min_value_wt = total(con_min_value_wt)
  obs_check if num_deps`wt' > 0 & `delim' & con_min_value`wt' > 0 & total_con_min_value_wt > 4520 & !mi(total_con_min_value_wt) & inrange(year, 1990, 2004), tag(con_id_joint)
  local con_prod_f2 `r(N)'
  noi di %55s "***Cons with producing deposits value > 4520 (f2: 1990-2004): " %3.0f (r(N))

  obs_check if num_deps`wt' > 0 & `delim' & con_min_value`wt' > 0 & inrange(year, 2004, 2004), tag(con_id_joint)
  noi di %55s "Cons with producing deposits (2004 only): " %3.0f (r(N))

  
  noi disp_nice "PRICE SHOCK DATA (PRECOLLAPSE)"
  use $tmp/con_deposit_price_shocks, clear
  count
  local N = r(N)
  obs_check, tag(con_id_joint mineral)
  local cm = r(N)
  obs_check, tag(year)
  local years = r(N)
  obs_check, tag(con_id_joint)
  local cons = r(N)
  noi di "`years' years, `cm' con-mineral pairs, " %5.0f (`years'*`cm') " potential observations."
  noi di "`N' actual observations"
  
  noi disp_nice "CON LEVEL PRICE SHOCK DATA"
  use $mining/con_mine_shocks, clear
  assert !mi(value`wt')
  
  /* tag predelim so don't double count constituencies */
  gen l = strlen(con_id_joint)
  gen predelim = (l == 7)

  obs_check if num_deps`wt' > 0 & `delim', tag(con_id_joint)
  noi di %55s "Number of cons with deposits: " %3.0f (`r(N)')

  /* number with value */
  obs_check if num_deps`wt' > 0 & value`wt' > 0 & `delim', tag(con_id_joint)
  noi di %55s "Number of cons with deposit + value: " %3.0f (`r(N)')

  /* number with price backward looking price shock */
  obs_check if num_deps`wt' > 0 & value`wt' > 0 & !mi(ps_wt_glo_f0_m6) & `delim', tag(con_id_joint)
  noi di %55s "Number of cons with pshock (f0): " %3.0f (`r(N)')

  obs_check if num_deps`wt' > 0 & value`wt' > 0 & !mi(ps_wt_glo_f1_m6) & `delim', tag(con_id_joint)
  noi di %55s "Number of cons with pshock (f1): " %3.0f (`r(N)')

  obs_check if num_deps`wt' > 0 & value`wt' > 0 & !mi(ps_wt_glo_f2_m6) & `delim', tag(con_id_joint)
  noi di %55s "***Number of cons with pshock (f2): " %3.0f (`r(N)')

  /* count constituencies with positive value in 2004 ---> baseline m5 when year == 2009 */
  keep if year == 2009

  obs_check if base_value`wt'_glo_f0_m6 > 0 & !mi(base_value_glo_f0_m6) & `delim', tag(con_id_joint)
  local cons_ps_2009_f0_pre `r(N)'
  obs_check if base_value`wt'_glo_f0_m6 > 0 & !mi(base_value_glo_f0_m6) & !`delim', tag(con_id_joint)
  local cons_ps_2009_f0_post `r(N)'

  obs_check if base_value`wt'_glo_f2_m6 > 0 & !mi(base_value_glo_f2_m6) & `delim', tag(con_id_joint)
  local cons_ps_2009_f2_pre `r(N)'
  obs_check if base_value`wt'_glo_f2_m6 > 0 & !mi(base_value_glo_f2_m6) & !`delim', tag(con_id_joint)
  local cons_ps_2009_f2_post `r(N)'

  noi di %55s "Num cons (pre, post) with 2004-2009 price shock (f0): " %3.0f (`cons_ps_2009_f0_pre')  %5.0f (`cons_ps_2009_f0_post')
  noi di %55s "Num cons (pre, post) with 2004-2009 price shock (f2): " %3.0f (`cons_ps_2009_f2_post') %5.0f (`cons_ps_2009_f2_post')

  /*****************************************************/
  /* Reload data to look at pooled ADR years 2004-2013 */
  /*****************************************************/
  use $mining/con_mine_shocks, clear
  keep if inrange(year, 2004, .)

  obs_check if base_value_glo_f0_m6 > 0 & !mi(base_value_glo_f0_m6), tag(con_id_joint)
  noi di %55s "Num cons with any post-2004 price shock (f0): " %3.0f (`r(N)')
  
  obs_check if base_value_glo_f2_m6 > 0 & !mi(base_value_glo_f2_m6), tag(con_id_joint)
  local cons_ps_f2 = `r(N)'
  noi di %55s "Num cons with any post-2004 price shock (f2): " %3.0f (`r(N)')

  /*****************************************************/
  /* Reload data to look at number cons with ps in any year */
  /*****************************************************/
  use $mining/con_mine_shocks, clear

  obs_check if base_value_glo_f0_m6 > 0 & !mi(base_value_glo_f0_m6), tag(con_id_joint)
  noi di %55s "Num cons with any price shock (f0): " %3.0f (`r(N)')
  
  obs_check if base_value_glo_f2_m6 > 0 & !mi(base_value_glo_f2_m6), tag(con_id_joint)
  noi di %55s "Num cons with any post-2004 price shock (f2): " %3.0f (`r(N)')
  
  /********************/
  /* ADR-matched data */
  /********************/
  noi disp_nice "ADR (winner crime is never missing)"
  use $mining/mining_con_adr, clear
  assert !mi(winner_any_crim)
  
  obs_check, tag(con_id_joint)
  local cons = r(N)
  
  obs_check, tag(year)
  local years = r(N)

  count
  di "`years' years, `cons' cons, `r(N)' obs"

  obs_check if !mi(ps`wt'_glo_f2_m6) & num_deps`wt' > 0
  noi di %55s "Obs with 5-year price shock : " %3.0f (`r(N)')
  local ps_adr_winner = r(N)

  /*************/
  /* SUMMARIZE */
  /*************/
  noi disp_nice "SUMMARY"
  noi di %55s "deposits: "  %3.0f (`atlas_num_deps')
  noi di %55s "deposits matched to cons: "  %3.0f (`con_num_deps')
  noi di %55s "cons with deposits: " %3.0f (`cons_dep') " (multiple deposits in one con)"
  noi di %55s "cons with producing deposits (f0): " %3.0f (`con_prod_f0')
  noi di %55s "cons with producing deposits (f2): " %3.0f (`con_prod_f2')
  noi di %55s "cons with 2004- f2 price shock: " %3.0f (`cons_ps_f2')
  noi di %55s "obs with price shock and ADR winner: " %3.0f (`ps_adr_winner')
}

cap log close
