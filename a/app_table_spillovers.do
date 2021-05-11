/***************************************************/
/* GOAL: distance matrix of con_id_joint centroids */
/***************************************************/

/* loop over 2007 and 2008 con ids */
foreach year in 2007 2008 {
  
  /* open con centroid coordinates  */
  use $tmp/con_joint_coords, clear
  
  if (`year' == 2008)   keep if strlen(con_id_joint) == 12
  if (`year' == 2007)   keep if strlen(con_id_joint) == 7
  
  /* create a unique value for each row */
  gen row = _n
  
  /* save the key and then drop con_id_joint to make this smaller */
  savesome row con_id_joint using $tmp/con_id_`year'_key, replace
  
  /* drop con_id_joint */
  drop con_id_joint
  
  /* loop over each con_id, and claculate teh distance to all the other ones */
  sum row
  local nrows = `r(N)'
  forval i = 1/`nrows' {
    if mod(`i', 100) == 0 di `i'
    qui {
      sum longitude if row == `i'
      local lon `r(mean)'
      
      sum latitude if row == `i'
      local lat `r(mean)'
      
      gen dist`i' = sqrt((longitude - `lon') ^ 2 + (latitude - `lat') ^ 2)
    }
  }

  /* for each constituency, generate a list constituencies with centroids within 25km */
  gen near_list = ""
  forval i = 1/`nrows' {
    replace near_list = near_list + " `i'" if dist`i' < 60/110 & dist`i' > 0.02
  }
  
  /* drop distances  */
  drop dist*
  
  /* split near-list to get row numbers of near constituencies in separate columns */
  split near_list, gen(row)
  destring row*, replace
  capdrop near_list latitude longitude row_number
  
  /* get con_id_joint back for the row variable */
  merge 1:1 row using $tmp/con_id_`year'_key, nogen assert(match) 
  drop row
  
  /* reshape long */
  reshape long row, j(row_number) i(con_id_joint)
  drop if mi(row)
  
  save $tmp/foo, replace
  
  /* rename left-side con_id_joint so we can get the other con_ids */
  ren con_id_joint con_id_joint_master
  
  /* get con_id_joints for each of the reshaped rows */
  merge m:1 row using $tmp/con_id_`year'_key, assert(using match)
  keep if _merge == 3
  drop _merge
  
  /* save the set con_ids with the set of matching con_ids */
  ren con_id_joint con_id_joint_near
  keep con_id_joint*
         
  save $tmp/con_id_close_`year', replace
}


/**************************/
/* adverse selection test */
/**************************/
/* append the 2007 and 2008 files to get back to one dataset */
use $tmp/con_id_close_2007, clear
append using $tmp/con_id_close_2008

/* check at most 35 close con_ids for each master */
drep con_id_joint_master

/* join by the ADR analysis dataset to get the main result once for each pair */
ren con_id_joint_master con_id_joint
joinby con_id_joint using $mining/mining_con_adr
ren con_id_joint con_id_joint_master

/* drop detritus */
keep year con_id_joint* winner_any_crim pshock base_value $con_controls sdgroup sygroup

/* now get winner_crim from the neighbor values */
/* use the years that we got from the analysis dataset */
ren con_id_joint_near con_id_joint
ren winner_any_crim crim_master
ren pshock pshock_master

merge m:1 con_id_joint year using $mining/mining_con_adr, keepusing(winner_any_crim pshock)
keep if _merge == 3

/* now collapse to one con_id_joint per year */
collapse (firstnm) crim_master pshock_master base_value $con_controls sdgroup sygroup (mean) pshock winner_any_crim, by(con_id_joint_master year)

/* store three columns from the main specification */
egen con_group = group(con_id_joint)
eststo clear
eststo: reghdfe winner_any_crim pshock pshock_master base_value $con_controls , cluster(sdgroup) absorb(sygroup)
store_depvar_mean y1, format("%04.2f")
eststo: reghdfe winner_any_crim pshock pshock_master base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup)
store_depvar_mean y2, format("%04.2f")
eststo: reghdfe winner_any_crim pshock pshock_master base_value $con_controls , cluster(sdgroup) absorb(sygroup sdgroup con_group)
store_depvar_mean y3, format("%04.2f")
probit winner_any_crim pshock pshock_master base_value $con_controls i.sygroup , cluster(sdgroup)
eststo: margins, dydx(pshock pshock_master) coeflegend post
sum winner_any_crim if e(sample)
local y4: di %04.2f (`r(mean)')

label var pshock "Price Shock"
label var pshock_master "Price Shock to Neighbors"
#delimit ;
local prefoot `""\hline State-Year F.E.      & Yes & Yes & Yes & Yes \\ "
                      " District F.E.        & No  & Yes & Yes & No  \\ "
                      " Constituency F.E.    & No  & No  & Yes & No  \\ " "\hline ""';
#delimit cr
estout_default using $out/app_spillovers, prefoot(`prefoot') keep(pshock pshock_master) order(pshock pshock_master)
estmod_footer  using $out/app_spillovers, cstring("Mean Dep. Var. & `y1' & `y2' & `y3' & `y4' ")

