
/**
PROGRAM NAME:		1c. Creating non-bz episodes
	PRIMARY PROGRAMMER:	Marzan Khan

	LAST MODIFIED:		October 16, 2022

	GENERAL PURPOSE: Create medication episodes of non-BZ
	CREATES DATA SET/S: 
 
**/

libname target "P:\sfmob\mak\Data\target_master_9.19.2022";

libname crash "P:\sfmob\shared\RawDataFiles";

proc format ;
	value $anynullfmt 
		' ' = 'Null'
		other = 'Not null'
	;
run;

options mergenoby = error msglevel = i nofmterr;
******************************************************************************************************************************;
*Creating medication episodes from Part D event file;
******************************************************************************************************************************;
*Restricting to dispensings of nbz from Part D Medicare data for the NJ cohort; 
data medic_subset;
	set target.partd_20072018;

	if nonbenzo_hypnotics_ind="1. Yes" and year(hdfrom)<2018;
	drop opioids_ind -- muscle_relax_ind;
run;
*  3,057,069 dispensings of non-BZ from 2007 through 2017  out of dispensings of all drugs in NJ between 2007-2018,  306,299,123;

*Removing dulplicate observations with the same bene_id_18900, prescription drug , dispensing date and the days of supply, in that order;
proc sort data=medic_subset ;
	by bene_id_18900 hdl_gdname hdfrom hddays; 
run;

*Chosing the first observations of duplicates by bene_id_18900 prescription drug , dispensing date and the days of supply;
data first_dup;
	set medic_subset ;
	by bene_id_18900 hdl_gdname hdfrom hddays;
	if first.hddays;
run;
* 3,054,492 remaining, 2,577 duplicates removed;
*order in which variables are places in the by statement does not matter;

*deleting observations where the days of supply=0;
data medic_drug;
	set first_dup;
	if hddays=0 then delete;
run;
* 3,054,442 observations remaining, 50 observations with hddays=0 removed;

*Check that there are no more observations where hddays=0;
*proc print data=medic_drug;
*	where hddays=0;
*run;
*0 observatios were printed from the code above, confirm that no more observations with hddays=0 remain;

*Sort by id and dispensing date;
proc sort data=medic_drug;
	by bene_id_18900 hdfrom;
run;

*Creating medication duration start and end dates from the dispensing date and days of supply;
data medic_dates;
	set medic_drug; 

	*Assuming that the person starts the drug on the same day as the date of dispensing;
	start_fill_date = hdfrom;

	*Assuming that the person stops taking the medication on the last day of the supply;
	end_fill_date = (hdfrom + hddays-1);

	format start_fill_date date9. end_fill_date date9.;
run;

*Creating adjusted start and end dates of medication use, taking into account the days of supply;
data medic_dates2;
set medic_dates;
	by bene_id_18900;
	retain adj_st_fill_date adj_end_fill_date;
	format adj_st_fill_date date9. adj_end_fill_date date9.;

	*for the first dispensing ever in the data for a person, no need to adjust the supply end date or date of medication dispensing;
	if first.bene_id_18900 then do;
		adj_st_fill_date=start_fill_date;
		adj_end_fill_date=end_fill_date;
		flag=1;
		
	end;
	else do;

		*if the start of medication use is on or before the end of supply from the prior dispensing, then set the start of medication a day after the end of supply from he previous dispensing as the adjusted medication start date;
		*and the adjusted supply end date would be calculated as this new, adjusted medication start date+days of supply;
		*	MP NOTE: this is because the person presumably had some medication still to take when their next fill date happened -- and they could extend their medication.
				for example (from rows 5 & 6): adjusted start and end dates for row 5 are 10/19/2013 and 11/17/2013.
					row 6 start and end dates are 11/13/2013 and 12/12/2013. New start date becomes 11/18/2013 and new end date is 12/17/2013. They presumably didn't
						start their 30 day supply on 11/13 but rather on 11/18 when their previous pills ran out. ;
		if start_fill_date<=adj_end_fill_date then do;
			adj_st_fill_date=adj_end_fill_date+1;
			adj_end_fill_date=adj_end_fill_date+hddays;
			flag=2;
		end;

		*if the start of medication use occurs after the end of supply from the prior dispensing, then set the start of medication as the day of dispensing;
		*and the adjusted supply end date would calculated as the medication start date+days of supply;
		else if start_fill_date>adj_end_fill_date then do;
			adj_st_fill_date=start_fill_date;
			adj_end_fill_date=start_fill_date+hddays-1;
			flag=3;
		end;
	end;
run;

/*proc freq data=medic_dates2;*/
/*	tables adj_st_fill_date adj_end_fill_date;*/
/*	format adj_st_fill_date adj_end_fill_date year4. ;*/
/*run;*/
/**adjusted end fill date and adjusted start fill date exceed 2017;*/
/**/
/*proc print data=medic_dates2 (obs=200);*/
/*	var bene_id_18900 hdfrom hddays adj_st_fill_date adj_end_fill_date flag;*/
/*run;*/
/**/
/**Check how the dates were created eyeballing some observations;*/
proc print data=medic_dates2 (obs=200);
	var bene_id_18900 hdfrom hddays adj_st_fill_date adj_end_fill_date flag;
	where flag=2;
run;

proc print data=medic_dates2 (obs=200);
	var bene_id_18900 hdfrom hddays adj_st_fill_date adj_end_fill_date flag;
where bene_id_18900="jjjjjjU888UAgq8";
run;
/**/
/**Check how the dates were created eyeballing some observations;*/
/*proc print data=medic_dates2 (obs=50);*/
/*	var bene_id_18900 hdfrom hddays adj_st_fill_date adj_end_fill_date flag;*/
/*	where flag=3;*/
/*run;*/

proc sort data= medic_dates2;
	by bene_id_18900 adj_st_fill_date adj_end_fill_date;
run;

data medic_discont;
	set  medic_dates2;
	*Create a discontinue date of medicaion use as 30 days from the supply end date;
	*the discontinue date is the 30th day from the day after the supply end date;
	*No need to add 1 day more, as the code line below is inclusive of the day;
	discontinue_date_original=adj_end_fill_date+30;
	format discontinue_date_original date9.;
run;

*Check how the discontue date was created;
proc print data=medic_discont (obs=100);
	var bene_id_18900 hdfrom hddays adj_st_fill_date adj_end_fill_date discontinue_date_original;
run;

*proc freq data=medic_discont;
*	tables discontinue_date_original;
*	format discontinue_date_original year4. ;
*run;
*disontinue date also ecxceed 2017;

data medic_manipulation;	
	set  medic_discont;

	*Delete observations where the start of medication use exceeds 2017;
	if year(adj_st_fill_date)>2017 then delete;

	*If the year of the supply end date exceeds 2017, censor that value to 31dec2017;
	if year(adj_end_fill_date)>2017 then analytic_supply_enddt="31dec2017"d;
	else analytic_supply_enddt=adj_end_fill_date;

	*If the year of the discontinu date exceeds 2017, censor that value to 31dec2017;
	if year(discontinue_date_original)>2017 then analytic_discontinue_date="31dec2017"d;
	else analytic_discontinue_date=discontinue_date_original;

	format analytic_supply_enddt analytic_discontinue_date date9. ;
run;
* 3,054,442 to  3,042,796;

proc print data=medic_manipulation ;
where analytic_discontinue_date<analytic_supply_enddt;
run;
*No observations where the analytic_discontinue_date is less than analytic_supply_enddt;

proc print data=medic_manipulation ;
where analytic_discontinue_date=analytic_supply_enddt and analytic_discontinue_date~="31dec2017"d;
run;
*No obs where the analytic start date is equal to the analytic_supply_enddt but not "31dec2017"d;

data check;
	set medic_manipulation;
	where analytic_discontinue_date=analytic_supply_enddt;
run;
*20,032;

proc freq data=check;
tables analytic_discontinue_date analytic_supply_enddt;
run;
*This proc freq confirmed that all the equal analytic_discontinue_date and analytic_supply_enddt were 31dec2017;

*Commenting out some sections below as they were checks I conducted;

*check to see that the year of analytic supply end date does not exceed 2017 anymore;
proc freq data= medic_manipulation;
	tables analytic_supply_enddt ;
	format analytic_supply_enddt year4. ;
run;
*no observations where the year of analytic supply end date exceeds 2017;

*check to see that the year of analytic discontinue date does not exceed 2017 anymore;
proc freq data= medic_manipulation;
	tables  analytic_discontinue_date;
	format analytic_discontinue_date year4. ;
run;
*no observations where the year of discontinue date exceeds 2017;

proc freq data= medic_manipulation;
	tables  adj_st_fill_date;
	where year(adj_st_fill_date)>2017;
run;
*Results in 0 obs or no output;
*All dispensings where the year of medication start date exceeded 2017 were removed;

*Performing some more checks to see the date manipulations were successful;
proc print data=medic_manipulation (obs=200);
	var bene_id_18900 adj_st_fill_date adj_end_fill_date analytic_supply_enddt discontinue_date_original analytic_discontinue_date;
	where year(adj_end_fill_date)>2017;
run;

proc freq data = medic_manipulation ;
	table adj_end_fill_date * analytic_supply_enddt / list missing;
	where adj_end_fill_date ne analytic_supply_enddt ;
	format adj_end_fill_date mmyys5. ;
run;

proc freq data = medic_manipulation ;
	table discontinue_date_original * analytic_discontinue_date / list missing;
	where discontinue_date_original ne analytic_discontinue_date ;
	format discontinue_date_original mmyys5. ;
run;
 
*	MP NOTE: you probably shouldn't comment this part out -- I glossed over it and then couldn't figure out what target.mediprs_episode
		is. If you want to make sure the data set isn't overwritten (by someone like me re-running things) either put in a comment warning
		not to run it or comment out the name of the data set. After all, there are lots of other instances of permanent data sets
		being created.  ;
*From the Medicare person level file at brown, keep bene_ids that are also in medic_manupulation and their date of death;
*Commenting the section below because the permanenent restricted person level file has already been created;
proc sql;
	create table target.mediprs_nbz as
	select hkdod as hkdod_plevel format=date9., bene_id_18900
	from claims.Hk100prs_bid
	where bene_id_18900 in (select bene_id_18900 from medic_manipulation)
	order by bene_id_18900;
	;
quit;
*229,544;

proc sort data=medic_manipulation;
	by bene_id_18900 adj_st_fill_date analytic_supply_enddt analytic_discontinue_date;
run;

data target.mediprs_use;
	merge  medic_manipulation (in=a) target.mediprs_nbz (in=b );
		by bene_id_18900;

		*Merge medic_manipulation and the Medicare person level file, keeping all records in the analytic medic manipulation dataset;
		if a;
		mediprs=b;
		partd=a;

run;

proc freq data=target.mediprs_use;
	tables mediprs partd;
run;

*records came from both the datasets;
******************************************************************************
mediprs Frequency Percent Cumulative Frequency Cumulative Percent 
1       3042796   100.00   3042796              100.00 

partd Frequency Percent Cumulative Frequency Cumulative Percent 
1     3042796   100.00   3042796              100.00 

******************************************************************************;
proc format ;
	value $anynullfmt 
		' ' = 'Null'
		other = 'Not null'
	;
run;

*All records came from both the datasets;

data mediprs_use2;
	set target.mediprs_use;

	*if the date of death is before the adjusted dispensing date, then delete such records;
	if .<hkdod_plevel<adj_st_fill_date then delete;

	*if the date of death is on or before the supply end date then set the supply end date as the date of death, otherwise the supply end date remains unchanged ;
	if .<hkdod_plevel<=analytic_supply_enddt then alt_supply_enddt=hkdod_plevel;
	else if hkdod_plevel~=. and hkdod_plevel>analytic_supply_enddt then alt_supply_enddt=analytic_supply_enddt;
	else if hkdod_plevel=. then  alt_supply_enddt=analytic_supply_enddt;

	*if the date of death is on or before the discontinue date but greater than the adjusted supply end date, then set the discontinue date as the date of death;
	*otherwise if the date of death is less than the adjusted supply end date, then set the discontinue date as the adjusted supply end date;
	*otherwise if the date of death is after the discontinue date or missing, then dicontinue date remains unchanged;
	if hkdod_plevel~=. and alt_supply_enddt<hkdod_plevel<=analytic_discontinue_date then alt_discontinue_date=hkdod_plevel;
	else if hkdod_plevel~=. and hkdod_plevel<=analytic_supply_enddt then alt_discontinue_date=alt_supply_enddt;
	else if hkdod_plevel~=. and hkdod_plevel>analytic_discontinue_date then alt_discontinue_date=analytic_discontinue_date;
	else if hkdod_plevel=. then alt_discontinue_date=analytic_discontinue_date;

	*	MP NOTE: I think below you mean alt_discontinue_date. new_discontinue_date was uninitialized ;
	format alt_supply_enddt  alt_discontinue_date  date9.;
run;
* 3,038,105 (3,037,905 with .<hkdod_plevel<=adj_st_fill_date);
	
/*proc print data=mediprs_use2 (obs=10);*/
/*	var bene_id_18900 adj_st_fill_date analytic_supply_enddt alt_supply_enddt analytic_discontinue_date alt_discontinue_date hkdod_plevel;*/
/*	where .<hkdod_plevel<=analytic_supply_enddt;*/
/*run;*/
/**/
/*proc print data=mediprs_use2 (obs=10);*/
/*	var bene_id_18900 adj_st_fill_date analytic_supply_enddt alt_supply_enddt analytic_discontinue_date alt_discontinue_date hkdod_plevel;*/
/*	where hkdod_plevel=adj_st_fill_date;*/
/*run;*/
/**/
/*proc print data=mediprs_use2 (obs=10);*/
/*	var bene_id_18900 adj_st_fill_date analytic_supply_enddt alt_supply_enddt analytic_discontinue_date alt_discontinue_date hkdod_plevel;*/
/*	where hkdod_plevel~=. and alt_supply_enddt<hkdod_plevel<=analytic_discontinue_date;*/
/*run;*/

proc sort data=mediprs_use2;
	by bene_id_18900 adj_st_fill_date alt_supply_enddt alt_discontinue_date;
run;

*Creating lag of the final discontinue date by bene_id;
data medic_lag1;
	set mediprs_use2;

	by bene_id_18900;

	lag_alt_discontinue_date=lag(alt_discontinue_date);
	if first.bene_id_18900 then lag_alt_discontinue_date="31dec2006"d;

	format lag_alt_discontinue_date date9.;

run;

*Check how the lag of discontinue date was created;
proc print data=medic_lag1 (obs=220);
	var bene_id_18900 adj_st_fill_date alt_supply_enddt alt_discontinue_date lag_alt_discontinue_date;
run;

*Creating medication episodes where consecutive dispensings 30 days or less apart are considered to be part of the same medication episode;
*The discontinue date is 30 days from the end of the supply;	
data medic_episode;
	set medic_lag1;
	by bene_id_18900;
	if first.bene_id_18900 then episode=1;
	else if adj_st_fill_date<=lag_alt_discontinue_date then episode=episode;
	else if adj_st_fill_date>lag_alt_discontinue_date then episode+1;
run;

proc print data=medic_episode (obs=10);
	var bene_id_18900 adj_st_fill_date alt_supply_enddt alt_discontinue_date lag_alt_discontinue_date episode;
run;

*checking the distinct drugs present;
proc freq data=medic_episode;
	tables hdl_gdname;
run;
*3,038,105;

proc sort data=medic_episode;
	by bene_id_18900 adj_st_fill_date alt_supply_enddt alt_discontinue_date;
run;

proc sql ;
create table medic3_int as
select  *, min(adj_st_fill_date) as min_index_date format=date9.,
	   max(alt_supply_enddt) as max_supply_enddt format=date9.,
	   max(alt_discontinue_date) as max_discontinue_date format=date9.,
	
	   case when hdl_gdname="zolpidem" then 1
	   else 0
	   end as zolpidem,

	   case when hdl_gdname="zaleplon" then 1
	   else 0
	   end as zaleplon,  

	   case when hdl_gdname="eszopiclone" then 1
	   else 0
	   end as eszopiclone

	   from medic_episode 
	   group by bene_id_18900, episode
	   order by bene_id_18900, episode, adj_st_fill_date, alt_supply_enddt, alt_discontinue_date
	; /* 3038105*/

create table medic3 as
	   select distinct bene_id_18900 , episode, min_index_date, max_supply_enddt, max_discontinue_date, hkdod_plevel, 

	   sum(zolpidem) as zolpidem_sum,

	   sum(zaleplon) as zaleplon_sum,

	   sum(eszopiclone) as eszopiclone_sum,
	   	
	   count(*) as disp_number

	   from medic3_int
	   group by bene_id_18900, episode
	;
quit;
*650,447;

/*proc print data=medic3_int (obs=10);*/
/*	var bene_id_18900 episode adj_st_fill_date alt_supply_enddt alt_discontinue_date;*/
/*	where hkdod_plevel=adj_st_fill_date;*/
/*run;*/
/**/
/*proc print data=medic3_int;*/
/*	where bene_id_18900 in ("jjjjjjU9AUy9xqg", "jjjjjjcc98y9g8q", "jjjjjjcj99y888q", "jjjjjjjU8xqAgUy");*/
/*	var bene_id_18900 episode adj_st_fill_date alt_supply_enddt alt_discontinue_date hkdod_plevel;*/
/*run;*/

proc sort data=medic3;
	by bene_id_18900 min_index_date max_supply_enddt max_discontinue_date;
run;
	
*Creating a lag of discontinue date for each episode for a person;
data target.nbz_episodes;
	set  medic3;
	by bene_id_18900;

	lag_discontinue_episode=lag(max_discontinue_date);
	if first.bene_id_18900 then lag_discontinue_episode="31dec2006"d; 

	format lag_discontinue_episode date9.;

/*	diff_days_episode=min_index_date-lag_discontinue_episodedt-1;*/

	label episode="Medication episode number, where an episode is defined by an index date/start date and discontinue date"
		  min_index_date="Start date of a medication episode"
		  max_supply_enddt="Last date of medication supply within an episode"
		  max_discontinue_date="Date when the medication is considered to be discontinued (removed biologically)"
		  lag_discontinue_episode="Discontinue date of the previous medicaton episode"
		  disp_number="Number of medication dispensings within an episode"
		  zolpidem_sum="Number of dispensings of zolpidem within a medication episode"
		  zaleplon_sum="Number of dispensings of zaleplon within a medication episode"
		  eszopiclone_sum="Number of dispensings of eszopiclone within a medication episode"
		  hkdod_plevel="Date of death from person level summary Medicare file"
/*		  diff_days_episode="Difference in days between consecutive medication episodes (1 subtracted from the result)"*/
;

run;
*650,447;
*Contains all the episodes of non-BZ NJ, 2007-2017;

proc print data= target.nbz_episodes;
	where bene_id_18900 in ("jjjjjjU9AUy9xqg", "jjjjjjcc98y9g8q", "jjjjjjcj99y888q", "jjjjjjjU8xqAgUy");
	var bene_id_18900 episode min_index_date max_supply_enddt max_discontinue_date  lag_discontinue_episode ;
run;

proc freq data=target.nbz_episodes;
	tables min_index_date;
	format min_index_date year4.;
run;
*650,447;

***********************************************************************************************************************************************************************;

data nbz_manip1;
	set target.nbz_episodes;

	*The start of washout is the 90th day before the episode start date;
	washout_start=min_index_date-90;

	washoutstart_startofmonth=intnx('month', washout_start, 0, "B");

	*Set washout end to th medication episode start date in order to remove the problem of someone losing coverage before the start of a prevalent or new use episode; 
	washout_end=min_index_date;

	washoutend_startofmonth=intnx('month', washout_end,0,"B");

	*Always need to add 1 to include the starting month as well;
	nummonths_enrollment=intck("month", washout_start, washout_end)+1;

	*Put a -1 at the end so that this difference in days variable is >0 only when there is at least a day in between the dats without medication;
	diff_days_episode=min_index_date-lag_discontinue_episode-1;

	format washoutstart_startofmonth washoutend_startofmonth  washout_end washout_start date9.;

	label washout_start="Start date of washout period"
	washout_end="End date of washout period"
	nummonths_enrollment="Minimum number of months of Medicare enrollment required during washout period"
	diff_days_episode="Difference in days between consecutive medication episodes (1 subtracted from the result)"
	washoutstart_startofmonth="Washout start set to the first of the month"
	washoutend_startofmonth="Washout end set to the first of the month "
	;
run;

*find the number of months of FFS coverage during washout;
proc sql;
	create table ffsdata_merge as 
	select a.bene_id_18900, a.min_index_date, a.washoutstart_startofmonth, a.washoutend_startofmonth, b.month_year, b.ffs
	from nbz_manip1 as a

	left join target.CONCATENATE_HKHMO as b
	on a.bene_id_18900=b.bene_id_18900 

	where a.washoutstart_startofmonth<=month_year<=a.washoutend_startofmonth
	order by bene_id_18900, min_index_date, month_year
;
/*  1838144*/
	create table months_ffs as 
	select distinct bene_id_18900, min_index_date,  sum(ffs) as ffs_sum
	from ffsdata_merge
	group by bene_id_18900, min_index_date
;
quit;
*465,249;

*find the number of months of Part A & B coverage during washout;
proc sql;
	create table partabdata_merge as 
	select a.bene_id_18900, a.min_index_date, a.washoutstart_startofmonth, a.washoutend_startofmonth, b.month_year, b.hkebi_ind
	from nbz_manip1 as a
	left join target.CONCATENATE_hkebi as b
	on a.bene_id_18900=b.bene_id_18900 
	where a.washoutstart_startofmonth<=b.month_year<=a.washoutend_startofmonth
	order by bene_id_18900, min_index_date, month_year
;
/*  1838144*/

	create table months_partab as 
	select distinct bene_id_18900, min_index_date,  sum(hkebi_ind) as partab_sum
	from partabdata_merge 
	group by bene_id_18900, min_index_date
;
quit;
/*  465,249*/


*find the number of months of Part D coverage during washout;
proc sql;
	create table partddata_merge as 
	select a.bene_id_18900, a.min_index_date, a.washoutstart_startofmonth, a.washoutend_startofmonth, b.month_year, b.ptd_contr
	from nbz_manip1 as a
	left join target.CONCATENATE_hkdcontr as b
	on a.bene_id_18900=b.bene_id_18900 
	where a.washoutstart_startofmonth<=b.month_year<=a.washoutend_startofmonth
	order by bene_id_18900, min_index_date, month_year
;
/* 1838144*/
	create table months_partd as 
	select distinct bene_id_18900, min_index_date,  sum(ptd_contr) as partd_sum
	from partddata_merge 
	group by bene_id_18900, min_index_date
;
quit;
/* 465,249 as opposed to 650,447 distinct person-episodes in total*/
/*The remaining person-episodes did not have any coverage months during washout, they were actually missing from the annual
file years corresponding to the washout month years. This is because only when month_year is missing, there will be no records created by the where statement  */

*Bring in all the coverage summary variables to the distinct episodes final dataset;
proc sql;
	create table episode_coverage as
	select a.*, b.ffs_sum, c.partab_sum, d.partd_sum

	from nbz_manip1 as a

	left join months_ffs as b
	on a.bene_id_18900=b.bene_id_18900 and a.min_index_date=b.min_index_date

	left join months_partab as c
	on a.bene_id_18900=c.bene_id_18900 and a.min_index_date=c.min_index_date

	left join months_partd as d
	on a.bene_id_18900=d.bene_id_18900 and a.min_index_date=d.min_index_date
	;
quit;
*650,447;

proc format;
	value episode
	1="Coverage and non-use period met/New-use episode"                   
    2="Coverage met, non-use period not met/Prevalent use episode"              
    3="Coverage not met, non-use period met/Ineligible episode"   
	4="Neither coverage nor non-use period met/Ineligible episode"    
	5="Non-use episode" 
;
run;

*This dataset contains the episodes categorized;
data target.nbz_episode_categories;
	set episode_coverage;

	array sum {3} ffs_sum partab_sum partd_sum;

	*Some episodes may have no enrollment information during washout, code those missing values as 0;
	do i=1 to 3;
	if sum{i}=. then sum{i}=0;
	end;

	if nummonths_enrollment=ffs_sum and nummonths_enrollment=partab_sum and nummonths_enrollment=partd_sum then coverage=1;
	else if nummonths_enrollment~=ffs_sum or nummonths_enrollment~=partab_sum or nummonths_enrollment~=partd_sum then coverage=0;


	if coverage=1 then do;
		if diff_days_episode>=90 then episode_cat=1;
		else if diff_days_episode<90 then episode_cat=2;
	end;

	if coverage=0 then do;
		if diff_days_episode>=90 then episode_cat=3;
		else if diff_days_episode<90 then episode_cat=4;
	end;

	drop i;
	format episode_cat episode.;

	label ffs_sum="Number of months of fee-for-service coverage during washout period"
		  partab_sum="Number of months of Parts A & B coverage during washout period"
		  partd_sum="Number of months of Part D coverage during washout period"
		  episode_cat="Medication episode category"
		  coverage="Indicator for the episode meeting Medicare coverage pior to and including the start date (1=Yes, 0=No)";

	
run;

ods listing;
proc freq data=target.nbz_episode_categories;
	tables episode_cat;
run;
*

------------------------------------------------------------------------------------------------------------------------------------
The SAS System                                                                                 00:12 Wednesday, October 19, 2022   1

The FREQ Procedure

                                          Medication episode category

                                                                                       Cumulative    Cumulative
                                               episode_cat    Frequency     Percent     Frequency      Percent
---------------------------------------------------------------------------------------------------------------
Coverage and non-use period met/New-use episode                 212211       32.63        212211        32.63
Coverage met, non-use period not met/Prevalent use episode      202432       31.12        414643        63.75
Coverage not met, non-use period met/Ineligible episode         145607       22.39        560250        86.13
Neither coverage nor non-use period met/Ineligible episode       90197       13.87        650447       100.00




------------------------------------------------------------------------------------------------------------------------------------

*
The SAS System                                                                                 14:14 Wednesday, October 12, 2022   1

The FREQ Procedure

                                          Medication episode category

                                                                                       Cumulative    Cumulative
                                               episode_cat    Frequency     Percent     Frequency      Percent
---------------------------------------------------------------------------------------------------------------
Coverage and non-use period met/New-use episode                 212227       32.63        212227        32.63
Coverage met, non-use period not met/Prevalent use episode      202446       31.12        414673        63.75
Coverage not met, non-use period met/Ineligible episode         145591       22.38        560264        86.14
Neither coverage nor non-use period met/Ineligible episode       90183       13.86        650447       100.00
;

***********************************************************************************************************************************************************************;

proc sql;
	create table check2 as 
	select distinct bene_id_18900, min_index_date
	from target.nbz_episode_categories
	;
quit;
*650,447;
