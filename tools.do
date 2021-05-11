/**********************************************************************************/
/* program get_ecol_header_string : Returns a string "(1) (2) (3) ..." matching
the number of stored estimates.
*/
/***********************************************************************************/
cap prog drop get_ecol_header_string
prog def get_ecol_header_string, rclass
  {
    syntax

    /* get number of last estimate from ereturn */
    local s = substr("`e(_estimates_name)'", 4, .)
    local cstring = ""

    /* build string "(1) (2) (3) ..." */
    forval i = 1/`s' {
      local cstring = `" `cstring' "(`i')" "'
    }
    return local col_headers = `"`cstring'"'
  }
end
/* *********** END program get_ecol_header_string ***************************************** */


  /*********************************************************************************/
  /* program winsorize: replace variables outside of a range(min,max) with min,max */
  /*********************************************************************************/
  cap prog drop winsorize
  prog def winsorize
  {
    syntax anything,  [REPLace GENerate(name) centile]
  
    tokenize "`anything'"
  
    /* require generate or replace [sum of existence must equal 1] */
    if (!mi("`generate'") + !mi("`replace'") != 1) {
      display as error "winsorize: generate or replace must be specified, not both"
      exit 1
    }
  
    if ("`1'" == "" | "`2'" == "" | "`3'" == "" | "`4'" != "") {
      di "syntax: winsorize varname [minvalue] [maxvalue], [replace generate] [centile]"
      exit
    }
    if !mi("`replace'") {
      local generate = "`1'"
    }
    tempvar x
    gen `x' = `1'
  
  
    /* reset bounds to centiles if requested */
    if !mi("`centile'") {
  
      centile `x', c(`2')
      local 2 `r(c_1)'
  
      centile `x', c(`3')
      local 3 `r(c_1)'
    }
  
    di "replace `generate' = `2' if `1' < `2'  "
    replace `x' = `2' if `x' < `2'
    di "replace `generate' = `3' if `1' > `3' & !mi(`1')"
    replace `x' = `3' if `x' > `3' & !mi(`x')
  
    if !mi("`replace'") {
      replace `1' = `x'
    }
    else {
      generate `generate' = `x'
    }
  }
  end
  /* *********** END program winsorize ***************************************** */


/*****************************************************************************/
/* program store_depvar_mean : Store mean dependent variable after an estout */
/*****************************************************************************/
cap prog drop store_depvar_mean
prog def store_depvar_mean
  syntax anything, format(string)
  qui sum `e(depvar)' if e(sample)
  local x: di `format' (`r(mean)')
  tokenize `anything'
  c_local `1' `x'
end
/* *********** END program store_depvar_mean ***************************************** */


  /**********************************************************************************/
  /* program tag : Fast way to run egen tag(), using first letter of var for tag    */
  /**********************************************************************************/
  cap prog drop tag
  prog def tag
  {
    syntax anything [if]
  
    tokenize "`anything'"
  
    local x = ""
    while !mi("`1'") {
  
      if regexm("`1'", "pc[0-9][0-9][ru]?_") {
        local x = "`x'" + substr("`1'", strpos("`1'", "_") + 1, 1)
      }
      else {
        local x = "`x'" + substr("`1'", 1, 1)
      }
      mac shift
    }
  
    display `"RUNNING: egen `x'tag = tag(`anything') `if'"'
    egen `x'tag = tag(`anything') `if'
  }
  end
  /* *********** END program tag ***************************************** */


  /**********************************************************************************/
  /* program drep : report duplicates                                               */
  /**********************************************************************************/
  cap prog drop drep
  prog def drep
  {
    syntax [varlist] [if]
    duplicates report `varlist' `if'
  }
  end
  /* *********** END program drep ************************************************** */


/**********************************************************************************/
/* program estmod_header : add a header row to an estout set */
/***********************************************************************************/
cap prog drop estmod_header
prog def estmod_header
  syntax using/, cstring(string)
  
  /* add .tex suffix to using if not there */
  if !regexm("`using'", "\.tex$") local using `using'.tex
  
  shell python ~/ddl/tools/py/est_modify.py -c header -i `using' -o `using' --cstring "`cstring'"
end
/* *********** END program estmod_header ***************************************** */


/***********************************************************************************************/
/* program name_clean : standardize format of indian place names before merging                */
/***********************************************************************************************/
capture program drop name_clean
program def name_clean
  {
    syntax varname, [dropparens GENerate(name) replace]
    tokenize `varlist'
    local name = "`1'"

    if mi("`generate'") & mi("`replace'") {
      display as error "name_clean: generate or replace must be specified"
      exit 1
    }

    /* if no generate specified, make replacements to same variable */
    if mi("`generate'") {
      local name = "`1'"
    }

    /* if generate specified, copy the variable and then slowly change it */
    else {
      gen `generate' = `1'
      local name = "`generate'"
    }

    qui { 
      /* lowercase, trim, trim sequential spaces */
      replace `name' = trim(itrim(lower(`name')))
      
      /* parentheses should be spaced as follows: "word1 (word2)" */
      /* [ regex correctly treats second parenthesis with everything else in case it is missing ] */
      replace `name' = regexs(1) + " (" + regexs(2) if regexm(`name', "(.*[a-z])\( *(.*)")
      
      /* drop spaces before close parenthesis */
      replace `name' = subinstr(`name', " )", ")", .)
      
      /* name_clean removes ALL special characters including parentheses but leaves dashes only for -[0-9]*/
      /* parentheses are removed at the very end to facilitate dropparens and numbers changes */
      
      /* convert punctuation to spaces */
      /* we don't use regex here because we would need to loop to get all replacements made */
      replace `name' = subinstr(`name',"*"," ",.)
      replace `name' = subinstr(`name',"#"," ",.)
      replace `name' = subinstr(`name',"@"," ",.)
      replace `name' = subinstr(`name',"$"," ",.)
      replace `name' = subinstr(`name',"&"," ",.)
      replace `name' = subinstr(`name', "-", " ", .)
      replace `name' = subinstr(`name', ".", " ", .)
      replace `name' = subinstr(`name', "_", " ", .)
      replace `name' = subinstr(`name', "'", " ", .)
      replace `name' = subinstr(`name', ",", " ", .)
      replace `name' = subinstr(`name', ":", " ", .)
      replace `name' = subinstr(`name', ";", " ", .)
      replace `name' = subinstr(`name', "*", " ", .)
      replace `name' = subinstr(`name', "|", " ", .)
      replace `name' = subinstr(`name', "?", " ", .)
      replace `name' = subinstr(`name', "/", " ", .)
      replace `name' = subinstr(`name', "\", " ", .)
      replace `name' = subinstr(`name', `"""', " ", .)
        * `"""' this line to correct emacs syntax highlighting) '
      
      /* replace square and curly brackets with parentheses */
      replace `name' = subinstr(`name',"{","(",.)
      replace `name' = subinstr(`name',"}",")",.)
      replace `name' = subinstr(`name',"[","(",.)
      replace `name' = subinstr(`name',"]",")",.)
      replace `name' = subinstr(`name',"<","(",.)
      replace `name' = subinstr(`name',">",")",.)
      
      /* trim once now and again at the end */
      replace `name' = trim(itrim(`name'))
      
      /* punctuation has been removed, so roman numerals must be separated by spaces */
      
      /* to be replaced, roman numerals must be preceded by ward, pt, part, no or " " */
      
      /* roman numerals to digits when they appear at the end of a string */
      /* require a space in front of the ones that could be ambiguous (e.g. town ending in 'noi') */
      replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )i$", "1")
      replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )ii$", "2")
      replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )iii$", "3")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iv$", "4")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iiii$", "4")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?)v$", "5")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iiiii$", "5")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?| no ?| )vi$", "6")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )vii$", "7")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )viii$", "8")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )ix$", "9")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?| no ?| )x$", "10")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )xi$", "11")
      
      /* replace roman numerals in parentheses */
      replace `name' = subinstr(`name', "(i)",     "1", .)
      replace `name' = subinstr(`name', "(ii)",    "2", .)
      replace `name' = subinstr(`name', "(iii)",   "3", .)
      replace `name' = subinstr(`name', "(iv)",    "4", .)
      replace `name' = subinstr(`name', "(iiii)",  "4", .)
      replace `name' = subinstr(`name', "(v)",     "5", .)
      replace `name' = subinstr(`name', "(iiiii)", "5", .)
      
      /* prefix any digits with a dash, unless the number is right at the start */
      replace `name' = regexr(`name', "([0-9])", "-" + regexs(1)) if regexm(`name', "([0-9])") & mi(real(substr(`name', 1, 1)))
      
      /* but change numbers that are part of names to be written out */
      replace `name' = subinstr(`name', "-24", "twenty four", .)
      
      /* don't leave a space before a dash [the only dashes left were inserted by the # steps above] */
      replace `name' = subinstr(`name', " -", "-", .)
      
      /* standardize trailing instances of part/pt to " part" */
      replace `name' = regexr(`name', " pt$", " part")
      replace `name' = regexr(`name', " \(pt\)$", " part")
      replace `name' = regexr(`name', " \(part\)$", " part")
      
      /* take important words out of parentheses */
      replace `name' = subinstr(`name', "(urban)", "urban", .)
      replace `name' = subinstr(`name', "(rural)", "rural", .)
      replace `name' = subinstr(`name', "(east)", "east", .)
      replace `name' = subinstr(`name', "(west)", "west", .)
      replace `name' = subinstr(`name', "(north)", "north", .)
      replace `name' = subinstr(`name', "(south)", "south", .)
      
      /* drop anything in parentheses?  do it twice in case of multiple parentheses. */
      /* NOTE: this may result in excess matches. */
      if "`dropparens'" == "dropparens" {
        replace `name' = regexr(`name', "\([^)]*\)", "")
        replace `name' = regexr(`name', "\([^)]*\)", "")
        replace `name' = regexr(`name', "\([^)]*\)", "")
        replace `name' = regexr(`name', "\([^)]*\)", "")
      }
      
      /* drop the word "village" and "vill" */
      replace `name' = regexr(`name', " vill(age)?", "")
      
      /* after making all changes that rely on parentheses, remove parenthese characters */
      /* since names with parens are already formatted word1 (word2) replace as "" */
      replace `name' = subinstr(`name',"(","",.)
      replace `name' = subinstr(`name',")"," ",.)
      
      /* trim again */
      replace `name' = trim(itrim(`name'))
    }
  }
end
/* *********** END program name_clean ***************************************** */


  /**********************************************************************************/
  /* program append_to_file : Append a passed in string to a file                   */
  /**********************************************************************************/
  cap prog drop append_to_file
  prog def append_to_file
  {
    syntax using/, String(string) [format(string) erase]
  
    tempname fh
    
    cap file close `fh'
  
    if !mi("`erase'") cap erase `using'
  
    file open `fh' using `using', write append
    file write `fh'  `"`string'"'  _n
    file close `fh'
  }
  end
  /* *********** END program append_to_file ***************************************** */


  /**********************************************************************************/
  /* program group : Fast way to use egen group()                  */
  /**********************************************************************************/
  cap prog drop regroup
  prog def regroup
    syntax anything [if]
    group `anything' `if', drop
  end
  
  cap prog drop group
  prog def group
  {
    syntax anything [if], [drop]
  
    tokenize "`anything'"
  
    local x = ""
    while !mi("`1'") {
  
      if regexm("`1'", "pc[0-9][0-9][ru]?_") {
        local x = "`x'" + substr("`1'", strpos("`1'", "_") + 1, 1)
      }
      else {
        local x = "`x'" + substr("`1'", 1, 1)
      }
      mac shift
    }
  
    if ~mi("`drop'") cap drop `x'group
  
    display `"RUNNING: egen int `x'group = group(`anything')" `if''
    egen int `x'group = group(`anything') `if'
  }
  end
  /* *********** END program group ***************************************** */


  /*********************************************************************************************************/
  /* program ddrop : drop any observations that are duplicated - not to be confused with "duplicates drop" */
  /*********************************************************************************************************/
  cap prog drop ddrop
  cap prog def ddrop
  {
    syntax varlist(min=1) [if]

    /* do nothing if no observations */
    if _N == 0 exit
    
    /* `0' contains the `if', so don't need to do anything special here */
    duplicates tag `0', gen(ddrop_dups)
    drop if ddrop_dups > 0 & !mi(ddrop_dups) 
    drop ddrop_dups
  }
end
/* *********** END program ddrop ***************************************** */


  /**********************************************************************************/
  /* program estout_default : Run default estout command with (1), (2), etc. column headers.
                              Generates a .tex and .html file. "using" should not have an extension.
  */
  /***********************************************************************************/
  cap prog drop estout_default
  prog def estout_default
  {
    syntax [anything] using/ , [KEEP(passthru) MLABEL(passthru) ORDER(passthru) TITLE(passthru) HTMLonly PREFOOT(passthru) EPARAMS(string)]
  
    /* if mlabel is not specified, generate it as "(1)" "(2)" */
    if mi(`"`mlabel'"') {
  
        /* run script to get right number of column headers that look like (1) (2) (3) etc. */
        get_ecol_header_string
  
        /* store in a macro since estout is rclass and blows away r(col_headers) */
        local mlabel `"mlabel(`r(col_headers)')"'
    }
  
    /* if keep not specified, set to the same as order */
    if mi("`keep'") & !mi("`order'") {
      local keep = subinstr("`order'", "order", "keep", .)
    }
  
    /* set eparams string if not specified */
  //   if mi(`"`eparams'"') {
  //     local eparams `"$estout_params"'
  //   }
  
    /* if prefoot() is specified, pull it out of estout_params */
    if !mi("`"prefoot"'") {
      local eparams = subinstr(`"$estout_params"', "prefoot(\hline)", `"`prefoot'"', .)
    }
  
  //  if !mi("`prefoot'") {
  //    local eparams = subinstr(`"`eparams'"', "prefoot(\hline)", `"`prefoot'"', .)
  // }
  //  di `"`eparams'"'
  
    /* output tex file */
    if mi("`htmlonly'") {
      di `" estout using "`using'.tex", `mlabel' `keep' `order' `title' `eparams' "'
      estout `anything' using "`using'.tex", `mlabel' `keep' `order' `title' `eparams'
    }
  
    /* output html file for easy reading */
    estout `anything' using "`using'.html", `mlabel' `keep' `order' `title' $estout_params_html
  }
  end
  
/* *********** END program estout_default ***************************************** */


/**********************************************************************************/
/* program estmod_footer : add a footer row to an estout set */
/***********************************************************************************/
cap prog drop estmod_footer
prog def estmod_footer
  syntax using/, cstring(string)
  
  /* add .tex suffix to using if not there */
  if !regexm("`using'", "\.tex$") local using `using'.tex
  
  shell python ~/ddl/tools/py/est_modify.py -c footer -i `using' -o `using' --cstring "`cstring'"
end
/* *********** END program estmod_footer ***************************************** */



cap pr drop graphout
pr def graphout
  syntax anything, [pdf]
  tokenize `anything'
  graph export $out/`1'.pdf
end


  /**********************************************************************************************/
  /* program quireg : display a name, beta coefficient and p value from a regression in one line */
  /***********************************************************************************************/
  cap prog drop quireg
  prog def quireg, rclass
  {
    syntax varlist(fv ts) [pweight aweight] [if], [cluster(varlist) title(string) vce(passthru) noconstant s(real 40) absorb(varlist) disponly robust]
    tokenize `varlist'
    local depvar = "`1'"
    local xvar = subinstr("`2'", ",", "", .)
  
    if "`cluster'" != "" {
      local cluster_string = "cluster(`cluster')"
    }
  
    if mi("`disponly'") {
      if mi("`absorb'") {
        cap qui reg `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' `constant' robust
        if _rc == 1 {
          di "User pressed break."
        }
        else if _rc {
          display "`title': Reg failed"
          exit
        }
      }
      else {
        /* if absorb has a space (i.e. more than one var), use reghdfe */
        if strpos("`absorb'", " ") {
          cap qui reghdfe `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' absorb(`absorb') `constant' 
        }
        else {
          cap qui areg `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' absorb(`absorb') `constant' robust
        }
        if _rc == 1 {
          di "User pressed break."
        }
        else if _rc {
          display "`title': Reg failed"
          exit
        }
      }
    }
    local n = `e(N)'
    local b = _b[`xvar']
    local se = _se[`xvar']
  
    quietly test `xvar' = 0
    local star = ""
    if r(p) < 0.10 {
      local star = "*"
    }
    if r(p) < 0.05 {
      local star = "**"
    }
    if r(p) < 0.01 {
      local star = "***"
    }
    di %`s's "`title' `xvar': " %10.5f `b' " (" %10.5f `se' ")  (p=" %5.2f r(p) ") (n=" %6.0f `n' ")`star'"
    return local b = `b'
    return local se = `se'
    return local n = `n'
    return local p = r(p)
  }
  end
  /* *********** END program quireg **********************************************************************************************/


  /**********************************************************************************/
  /* program disp_nice : Insert a nice title in stata window */
  /***********************************************************************************/
  cap prog drop disp_nice
  prog def disp_nice
  {
    di _n "+--------------------------------------------------------------------------------------" _n `"| `1'"' _n  "+--------------------------------------------------------------------------------------"
  }
  end
  /* *********** END program disp_nice ***************************************** */


  /**********************************************************************************/
  /* program append_est_to_file : Appends a regression estimate to a csv file       */
  /**********************************************************************************/
  cap prog drop append_est_to_file
  prog def append_est_to_file
  {
    syntax using/, b(string) Suffix(string)
  
    /* get number of observations */
    qui count if e(sample)
    local n = r(N)
  
    /* get b and se from estimate */
    local beta = _b["`b'"]
    local se   = _se["`b'"]
  
    /* get p value */
    qui test `b' = 0
    local p = `r(p)'
    if "`p'" == "." {
      local p = 1
      local beta = 0
      local se = 0
    }
    append_to_file using `using', s("`beta',`se',`p',`n',`suffix'")
  }
  end
  /* *********** END program append_est_to_file ***************************************** */


/**********************************************************************************/
/* program estmod_col_div : put in a column divider */
/***********************************************************************************/
cap prog drop estmod_col_div
prog def estmod_col_div
  {
    syntax using/, COLumn(integer)

    /* add .tex suffix to using if not there */
    if !regexm("`using'", "\.tex$") local using `using'.tex

    shell python ~/ddl/tools/py/est_modify.py -c col_div -i `using' -o `using' --column "`column'"
  }
end
/* *********** END program estmod_col_div ***************************************** */


  /***********************************************************************************/
  /* program obs_check : - Assert we have at least X obs in some subgroup            */
  /*                     - Count and return number of observations, with tagging     */
  /***********************************************************************************/
  cap prog drop obs_check
  prog def obs_check, rclass
  {
    syntax [if/], [n(integer 0) tag(varlist) unique(varlist)]

    /* set `if' variable to 1 if not specified */
    if mi(`"`if'"') {
      local if 1
    }

    /* tag observations if requested */
    cap drop __obs_check_tag
    if !mi("`tag'") {
      egen __obs_check_tag = tag(`tag') if `if'
    }
    else {
      gen __obs_check_tag = 1
    }

    /* count only obs unique on varlist if requested */
    cap drop __unique
    if !mi("`unique'") {
      bys `unique': gen __unique = _N == 1
    }
    else {
      gen __unique = 1
    }

    count if __obs_check_tag & __unique & `if'
    local count = r(N)

    if !mi("`n'") {
      assert `count' >= `n'
    }
    capdrop __obs_check_tag __unique
    return local N = `count'
  }
  end
  /* *********** END program obs_check ***************************************** */


  /**********************************************************************************/
  /* program capdrop : Drop a bunch of variables without errors if they don't exist */
  /**********************************************************************************/
  cap prog drop capdrop
  prog def capdrop
  {
    syntax anything
    foreach v in `anything' {
      cap drop `v'
    }
  }
  end
  /* *********** END program capdrop ***************************************** */


