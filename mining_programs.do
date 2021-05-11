/* set globals */
/* set globals for minerals to exclude from shocks and to flag locations */
/* excluding all minerals that are too low in value (under 1000 rs per deposit) or which are so unimportant that the goverment doesn't publish production values */
global exclude_minerals "limestone fire clay quartz glass/silica sand sulphur pyrite antimony cobalt mercury molybdenum potash titanium tungsten salt asbestos mica diamond"
global flag_minerals "coal lignite"
global minerals antimony apatite asbestos barite bauxite chromite clay coal cobalt copper diamond dolomite feldspar fireclay fluorite gold graphite gypsum hematite kyanite lead lignite limestone magnesite magnetite manganese mercury mica molybdenum nickel ochre phosphorite potash pyrite quartzglass salt sillimanite silver sulphur talc tin titanium tungsten vermiculite zinc
global clean_minerals         antimony apatite asbestos barite bauxite chromite coal cobalt copper dolomite feldspar  fluorite gold graphite gypsum hematite kyanite lead lignite magnesite magnetite manganese mercury mica molybdenum nickel ochre phosphorite potash pyrite sillimanite silver sulphur talc tin titanium tungsten vermiculite zinc
global clean_minerals_no_coal antimony apatite asbestos barite bauxite chromite      cobalt copper dolomite feldspar  fluorite gold graphite gypsum hematite kyanite lead         magnesite magnetite manganese mercury mica molybdenum nickel ochre phosphorite potash pyrite sillimanite silver sulphur talc tin titanium tungsten vermiculite zinc
global clean_minerals_no_out  antimony apatite asbestos barite bauxite chromite             copper dolomite feldspar  fluorite gold graphite gypsum hematite kyanite lead magnesite magnetite manganese         mica molybdenum nickel ochre phosphorite potash        sillimanite silver         talc tin titanium tungsten vermiculite zinc

/**********************************************************************************/
/* program label_pshocks : label pshocks, using m5 or m6                          */
/**********************************************************************************/
cap prog drop label_pshocks
prog def label_pshocks
{
  syntax, [m(string)]

  if "`m'" == "m5" {
    cap label var pshock "Price shock\$_{+1,+5}$"
    cap label var pshock_winner "Price shock\$_{+1,+5}$ * Winner"
    cap label var pshock_loser "Price shock\$_{+1,+5}$ * Loser"
    cap label var pshock_any_crim1 "Price shock\$_{+1,+5}$ * Criminal (Any)"
    cap label var pshock_crime_violent1 "Price shock\$_{+1,+5}$ * Criminal (Violent)"
    cap label var pshock_violent "Price shock\$_{+1,+5}$ * Violent"
    cap label var winner_violent "Winner * Violent"
    cap label var pshock_winner_violent "Price shock\$_{+1,+5}$ * Winner * Violent"
    cap label var crime_violent_strong1 "Violent Crime"
  }
  else {
    cap label var pshock "Price shock\$_{-6,-1}$"
    cap label var pshock1 "Price shock\$_{-6,-1}$ (2004-2008 only)"
    cap label var pshock2 "Price shock\$_{-6,-1}$ (2009-2013 only)"

    cap label var pshock_iron_ban  "Price shock\$_{-6,-1}$ * Iron Ban"
    cap label var pshock_post_2011 "Price shock\$_{-6,-1}$ * Post-2011"
    cap label var pshock_gkj       "Price shock\$_{-6,-1}$ * Ban States"
    cap label var pshock_bimaru    "Price shock\$_{-6,-1}$ * BIMARU"
  }

  /* pshock5 alwyas gets +1, +5 label */
  cap label var bimaru2 "BIMARU"
  cap label var pshock5 "Price shock\$_{+1,+5}$"
  cap label var pshock5_winner "Price shock\$_{+1,+5}$ * Winner"
  cap label var pshock5_bimaru "Price shock\$_{+1,+5}$ * BIMARU"
  cap label var pshock5_winner_bimaru "Price shock\$_{+1,+5}$ * Winner * BIMARU"
  cap label var winner_bimaru "Winner * BIMARU"
}
end
/* *********** END program label_pshocks ***************************************** */

/**********************************************************************************/
/* program clean_mineral_names : Insert description here */
/***********************************************************************************/
cap prog drop clean_mineral_names
prog def clean_mineral_names
{
  /* drop iron ore variant */
  drop if mineral == "iron ore conc."

  /* clean descriptions */
  replace mineral = trim(subinstr(mineral, "conc.", "", .))
  replace mineral = trim(subinstr(mineral, "(", "", .))
  replace mineral = trim(subinstr(mineral, ")", "", .))
  replace mineral = trim(subinstr(mineral, "1", "", .))
  replace mineral = trim(subinstr(mineral, "2", "", .))
  replace mineral = trim(subinstr(mineral, "3", "", .))
  replace mineral = trim(subinstr(mineral, ".", "", .))
  replace mineral = trim(subinstr(mineral, " crude", "", .))

  /* drop processed or double counted minerals */
  drop if inlist(mineral, "gold primary", "gold by-product", "gold total")
  drop if inlist(mineral, "iron ore fines", "iron ore lumps", "all minerals", "fluorite graded", "fuel minerals")
  drop if inlist(mineral, "limekankar", "limeshell", "marl", "minor minerals@", "non-metallic minerals", "metallic minerals")
  
  /* consolidate mineral names */
  synonym_fix mineral, synfile($mcode/repl/mineral_matches.csv) replace
  
}
end
/* *********** END program clean_mineral_names ***************************************** */

/**********************************************************************************/
/* program set_pshock : Insert description here */
/***********************************************************************************/
cap prog drop set_pshock
prog def set_pshock
{
  syntax, [lg wt m(string)] 

  if !mi("`wt'") {
    local wt _wt
  }
  if !mi("`lg'") {
    local lg _lg
  }
  if mi("`m'") {
    local m m6
  }
  
  /* drop vars to be created */
  foreach v in base_value pshock_winner pshock_crim winner_crim pshock_winner_crim pshock_loser {
    cap drop `v'
  }
  
  /* define pshock and base_value */
  /* [preserving pshock value label] */
  cap gen pshock = .
  replace pshock     =    ps`lg'`wt'_glo_f2_`m'
  gen base_value = ln(value`lg'`wt'_f2)

  /* label vars */
  label var base_value  "Log Baseline Mineral Output"
  
  /* create winner and criminal interactions if in time series */
  cap confirm variable winner1
  if !_rc {
    gen pshock_winner = pshock * winner1
    gen pshock_loser = pshock * (1 - winner1)
    gen pshock_crim = pshock * any_crim1
    gen pshock_winner_crim = pshock * winner1 * any_crim1
    gen winner_crim = winner1 * any_crim1

    /* label non-pshock variables (so as not to mess with subscripts) */
    cap label var winner_crim  "Winner * Criminal"
    cap label var winner1  "Winner"
    cap label var any_crim1  "Criminal"
    cap label var ln_fisman_net_assets1 "Baseline Log Net Assets"
    cap label var ln_crim1 "Log Criminal Cases (Baseline)"
  }
}
end
/* *********** END program set_pshock ***************************************** */

/**********************************************************************************/
/* program collapse_deposits : Insert description here */
/***********************************************************************************/
cap prog drop collapse_deposits
prog def collapse_deposits
{
  syntax, LOC_id(varlist)

  /* collaspe to constituencies, weighting by distance */
  /* generate sum of all distances */
  bys gsi_deposit_id: egen sum_dist = sum(dist)

  /* unscaled weight is total distance over this distance.
     - two equally distant places, will have weight_part = 2, 3 will all have 3.
     - one places twice as close (0.66 vs 0.33) will have 1.5 and 3.  */
  gen weight_part = sum_dist / dist

  /* rescale so weights sum to 1 for each deposit */
  bys gsi_deposit_id: egen weight_sum = sum(weight_part)
  gen weight = weight_part / weight_sum
  drop weight_part weight_sum sum_dist

  /* verify weights sum to 1 */
  bys gsi_deposit_id: egen weight_sum = sum(weight)
  assert round(weight_sum, 0.001) == 1
  
  /* created weighted deposit measure */
  ren weight deposit_weighted

  /* create a binary measure that puts deposit only in nearest constituency */
  bys gsi_deposit_id: egen min_dist = min(dist)
  gen deposit = 1 if min_dist == dist

  /* confirm only one constituency (observation) per deposit */
  bys gsi_deposit_id: egen con_count = count(dist) if deposit == 1
  assert con_count == 1 if deposit == 1
  drop con_count min_dist
  
  /* collapse dataset to count of number of deposits in/near a constituency, by deposit size and mineral */
  collapse (sum) num_deps=deposit num_deps_weighted=deposit_weighted, by(mineral `loc_id' deposit_size)
}
end
/* *********** END program collapse_deposits ***************************************** */



/***********************************************************************************/
/* program get_pshocks : assigns mean price shocks to locations based on proximity */
/***********************************************************************************/
cap prog drop get_pshocks
prog def get_pshocks
{
  syntax using/, Loc_id(varlist) EXclude(string) Flag(string)

  // drop minerals that we don't to include in shocks
  drop if regexm("`exclude'", mineral)

  // use something like $tmp/towns_deposits, which has town | dep_size | dist | mineral
  joinby mineral using `using'

  // generate price shocks, weighted by deposit size, for collapse
  foreach pshock of varlist pshock* plevel* {

    /* assign pshock weights for this row, based on this deposit size */
    gen `pshock'1 = 1
    gen `pshock'2 = .2 * (deposit_size == 3) + 1 * (deposit_size == 2) + 2 * (deposit_size == 1)
    gen `pshock'3 = 1 if deposit_size == 1 | deposit_size == 2

    /* multiply pshock by pshock weight */
    forval i = 1/3 {
      replace `pshock'`i' = `pshock'`i' * `pshock'
    }    

    /* drop unweighted pshock */
    drop `pshock'
  }

  gen num_big_deposits = num_deposits * (deposit_size == 2 | deposit_size == 1)
  
  /* flag constituencies that have deposits of flag minerals */
  gen flag = 0
  gen flag_big = 0
  replace flag = num_deposits if regexm("`flag'", mineral)
  replace flag_big = num_big_deposits if regexm("`flag'", mineral)
  
  /* collapse price shocks, numbers of deposits and numbers of flagged deposits */
  collapse (sum) pshock* plevel* num_deposits num_big_deposits flag flag_big, by(`loc_id' dist year)

  /* reshape distance to wide */
  ren dist_cat dist
  tostring dist, replace
  replace dist = "_" + dist
  reshape wide pshock* plevel* num_deposits num_big_deposits flag flag_big, i(`loc_id' year) j(dist) string

  foreach v of varlist pshock* {
    label var `v' "pshock_[period]_[weight]_[distance]"
  }
  foreach v of varlist plevel* {
    label var `v' "plevel_[period]_[weight]_[distance]"
  }

  /* replace missing num_deposit vars with zeros */
  forval i = 1/4 {
    replace num_deposits_`i' = 0 if mi(num_deposits_`i')
    replace num_big_deposits_`i' = 0 if mi(num_big_deposits_`i')
  }

  renpfix pshock ps
  renpfix plevel pl
}
end
/* *********** END program get_pshock ***************************************** */

/*******************************************/
/* DEFINE PROGRAM integrate_price          */
/*******************************************/
cap prog drop integrate_price
prog def integrate_price
{
  syntax , Start(integer) End(integer) base_start(integer) base_end(integer) Gen(name)
  
  /* verify years are 4-digit */
  if length("`start'") != 4 | length("`end'") != 4 {
    di as error "Error: start and end years must be 4 digits"
    exit 111
  }
  foreach v in base_mean tmp_price period_mean non_missing_prices non_missing_prices_tmp {
    cap drop `v'
  }
  /* name integrated growth variable */
  local g_var `gen'

  /* define length of base period */
  local base_length = `base_end' - `base_start'
  local period_length = `end' - `start'
  
  /* define baseline price as mean of three years before start */
  local pre_start = `base_start'
  local pre_end = `base_end' - 1

  /* define period start and end vars */
  local period_start = `start'
  local period_end = `end' - 1
  
  /* get mean price in base period */
  bys mineral: egen tmp_price = mean(unitvaluet) if inrange(year, `pre_start', `pre_end')
  bys mineral: egen base_mean = max(tmp_price)
  drop tmp_price

  /* get mean price in period */
  bys mineral: egen tmp_price = mean(unitvaluet) if inrange(year, `period_start', `period_end')
  bys mineral: egen period_mean = max(tmp_price)
  drop tmp_price

  /* generate growth variable */
  gen `g_var' = period_mean / base_mean - 1

  /* drop if more than 20% of base observations are missing */
  bys mineral: egen non_missing_prices_tmp = count(unitvaluet) if inrange(year, `pre_start', `pre_end')
  bys mineral: egen non_missing_prices = max(non_missing_prices_tmp)
  drop non_missing_prices_tmp
  replace `g_var' = . if non_missing_prices / `base_length'  < .79
  drop non_missing_prices
  
  /* drop if more than 20% of period observations are missing */
  bys mineral: egen non_missing_prices_tmp = count(unitvaluet) if inrange(year, `period_start', `period_end')
  bys mineral: egen non_missing_prices = max(non_missing_prices_tmp)
  drop non_missing_prices_tmp
  replace `g_var' = . if non_missing_prices / `period_length'  < .79
  drop non_missing_prices
}
end
/* END PROGRAM integrate_price */
/* ***************************** */

/**********************************************************************************/
/* program draw_mining_maps : Insert description here */
/***********************************************************************************/
cap prog drop draw_mining_map
prog def draw_mining_map
{
  syntax, mapname(string)
  preserve
  
  /* limit number of observations */
  count
  while (`r(N)' > 60,000) {
    keep if uniform() < 0.1
    count
  }
  
  if "`mapname'" == "distmap1" {
    twoway (scatter latitude longitude if num_deposits_1 > 0 & !mi(num_deposits_1), msize(vtiny) color(red)) (scatter latitude longitude if num_deposits_1 == 0, color(black) msize(vtiny))
  }
  if "`mapname'" == "distmap2" {
    twoway (scatter latitude longitude if num_deposits_2 > 0 & !mi(num_deposits_2), msize(vtiny) color(red)) (scatter latitude longitude if num_deposits_2 == 0, color(black) msize(vtiny))
  }
  if "`mapname'" == "distmap3" {
    twoway (scatter latitude longitude if num_deposits_3 > 0 & !mi(num_deposits_3), msize(vtiny) color(red)) (scatter latitude longitude if num_deposits_3 == 0, color(black) msize(vtiny))
  }
  if "`mapname'" == "distmap4" {
    twoway (scatter latitude longitude if num_deposits_4 > 0 & !mi(num_deposits_4), msize(vtiny) color(red)) (scatter latitude longitude if num_deposits_4 == 0, color(black) msize(vtiny))
  }
  restore
}
end
/* *********** END program draw_mining_maps ***************************************** */

/**********************************************************************************/
/* program gen_ps_means : Divide ps and pl by number of deposits */
/***********************************************************************************/
cap prog drop gen_ps_means
prog def gen_ps_means
{
  /* turn price shocks/levels into means */
  foreach weight in 1 2 3 {
    foreach t in 5 6 7 8 9 10 {
      foreach dist in 1 2 3 4 12 123 1234 {
        gen psm_`t'_`weight'_`dist' = ps_`t'_`weight'_`dist' / num_deposits_`dist'
        gen plm_`t'_`weight'_`dist' = pl_`t'_`weight'_`dist' / num_deposits_`dist'
      }
    }
  }
}
end
/* *********** END program convert_ps_means ***************************************** */


/**********************************************************************************/
/* program label_mining_vars : Insert description here */
/***********************************************************************************/
cap prog drop label_mining_vars
prog def label_mining_vars
{
  cap label var pshock "Price shock$subscript"
  cap label var vshock "Value shock"
  cap label var winner_any_crim "Criminal winner"
  cap label var mean_any_crim "Share criminal candidates"
  cap label var ln_pr4_value_wt_glo_f0_m6 "Log Mineral value"

  cap label var base_value "Log Base Mineral Output"
  cap label var ln_fisman_net_assets1 "Log Net Assets (baseline)"
}
end
/* *********** END program label_mining_vars ***************************************** */
