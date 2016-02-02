%MACRO NWORDS (INVAR);
%local N W;
%let N = 0;
%let W = 1;
%do %while (%nrquote(%scan(&invar,&W,%str( ))) ^= %str());
  %let N = %eval(&N+1);
  %let W = %eval(&W+1);
%end;
&N
%MEND NWORDS;


%PUT " ********************************************************************************* ";
%PUT " WRDS Macro: QUARTERIZE                                                            ";
%PUT " Summary   : Quarterizes Compustat YTM Cash Flow Variables in FUNDQ Dataset        ";
%PUT " Variables : - db_in and db_out are input and output datasets                      ";
%PUT "             - FYEAR and FQTR: Fiscal Year and Fiscal Quarter identifiers          ";
%PUT "             - IDVAR: primary identifier when joined with fiscal year and quarter  ";
%PUT "             - VARS: YTM vars used to derive Quarterly vars (with _q suffixes)     ";
%PUT "                      (default is all Compustat YTM variables -- ending with 'y')  ";
%PUT " ********************************************************************************* ";
%PUT;
%PUT %NRSTR(%%)QUARTERIZE (db_in=comp.fundq, db_out=fundq_qtr, vars=, FYEAR=fyearq,;
%PUT .    FQTR=fqtr, IDVAR=datafmt indfmt popsrc consol fyr gvkey, debug=False)%NRSTR(;);

%MACRO QUARTERIZE (db_in=comp.fundq,db_out=fundq_qtr,VARS=,FYEAR=fyearq,FQTR=fqtr,IDVAR=datafmt indfmt popsrc consol fyr gvkey, debug=False);
/* Note: Quarterize only Cash Flow items in Compustat */
/*        I/S items in Compustat are quarterly numbers */
/*        GVKEY FYR Combination is necessary for unique identification of records */

%IF "&debug."!="True" %THEN %DO;
 OPTIONS nonotes;
%END;
/* Count the Number of Cash Flow Variables */
%let nvars = %NWORDS(&vars);

/* If no pre-specified variables then quarterize all potential YTM CF variables */
%if &nvars = 0
%then %do;
 /* Get Variable Names and Keep only Numerical YTM Variables (suffix 'y' in Compustat Quarterly) */
 proc contents data=&db_in. noprint out=_listvar (where=(type=1) keep=NAME TYPE VARNUM LABEL); run;
 proc sort data=_listvar; by varnum; run;
   data _listvar;
    set _listvar (drop=type);
    where strip(lowcase(name)) like '%y';
    name=strip(lowcase(name));
    name_q = cats(name,"_q");
    if strip(name) ne "gvkey"; /* Redundant if GVKEY is a character value */
   run;
 proc sql noprint;
   select distinct name into :vars separated by " " from _listvar;
   select distinct name_q into :vars_q separated by " " from _listvar;
   select distinct count(*) into :nvars separated by " " from _listvar;
   drop table _listvar; quit;
 quit;
 %end;
 %else %let vars_q = %sysfunc(tranwrd(&vars,%str( ),%str(_q )))_q;

%PUT ;
%PUT ### START. Quarterizing...;
%PUT ;
%PUT ## Number of Variables   : &nvars;
%PUT ## List of YTM CF Vars   : &vars;
%PUT ## List of Quarterly Vars: &vars_q;
%PUT ;

proc sort data=&db_in out=__qtrz nodupkey; by &idvar &fyear &fqtr ; run;

data &db_out;
set __qtrz;
by &idvar &fyear &fqtr;
array cfytd  {&nvars} &vars;
array cfqtr  {&nvars} &vars_q;
do i=1 to &nvars; cfqtr(i)=dif(cfytd(i)); end;
del = (dif(&fqtr) ne 1);
if first.&fyear then
do;
 del = (&fqtr ne 1);
 do j=1 to &nvars; cfqtr(j)=cfytd(j); end;
end;
if del=1 then
do;
 do k=1 to &nvars; cfqtr(k)=.; end;
end;
drop del i j k;
run;

/* House Cleaning */
%IF "&debug."!="True" %THEN %DO;
  PROC SQL;
    DROP TABLE __qtrz;
  QUIT;
  OPTIONS notes;
%END;

%PUT ### DONE . ; %PUT;

%MEND QUARTERIZE;

/* ********************************************************************************* */
/* *************  Material Copyright Wharton Research Data Services  *************** */
/* ****************************** All Rights Reserved ****************************** */
/* ********************************************************************************* */
