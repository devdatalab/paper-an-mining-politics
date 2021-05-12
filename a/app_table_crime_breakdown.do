/* open full affidavits dataset */
use $adr/affidavits_clean, clear

/* keep winners only */
keep if position == 1

/* set corruption and violent definitions */
egen crime_govt = rowmax(crime_corruption crime_publicservant crime_election)
gen crime_violent = crime_violent

/* define crime list for output table */
global crime_list num_crim any_crim crime_govt crime_violent crime_property crime_disorder crime_white_collar crime_libel

/* review summary stats */
sum $crime_list

/* keep only the vars we want */
keep $crime_list

label var crime_property  "Property Crime"
label var crime_disorder  "Civil Disorder"
label var crime_white_collar "White Collar Crime"
label var crime_libel    "Libel"
label var any_crim       "Any Charge"
label var crime_govt     "Corruption"
label var crime_violent  "Violent Crime"

/* export to a .tex file and kill the begin/end table */
sutex $crime_list, labels par nobs nocheck file($tmp/test.tex) replace
cat $tmp/test.tex
shell cat $tmp/test.tex | tail -n +3 | head -n -1 > $out/crime_breakdown.tex
