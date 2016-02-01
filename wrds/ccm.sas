     /* ********************************************************************************* */
     /* ******************** W R D S   R E S E A R C H   M A C R O S ******************** */
     /* ********************************************************************************* */
%PUT "  ********************************************************************************* ";
%PUT "   WRDS Macro: CCM                                                                  ";
%PUT "   Summary   : Use CRSP-Compustat Merged Table to Add Permno to Compustat Data      ";
     /*  Date      : October 20, 2010                                                     */
     /*  Author    : Luis Palacios and Rabih Moussawi, WRDS                               */
%PUT "  Variables : - INSET   : Input dataset: should have a gvkey and a date variable    ";
%PUT "              - DATEVAR : Date variable to be used in the linking                   ";
%PUT "              - LINKTYPE: List of Linktypes: LU LC LX LD LN LS NP NR NU             ";
%PUT "              - REMDUPS : Flag 0/1 to remove multiple secondary permno matches      ";
%PUT "              - OVERLAP : Date Condition Overlap, in years                          ";
%PUT "              - OUTSET  : Compustat-CRSP link table output dataset                  ";
%PUT "  ********************************************************************************* ";
 
%PUT %NRSTR(%%)CCM(INSET=,DATEVAR=DATADATE,OUTSET=CCM,LINKTYPE=LULC,REMDUPS=1,OVERLAP=0);
%MACRO CCM (INSET=,DATEVAR=DATADATE,OUTSET=CCM,LINKTYPE=LULC,REMDUPS=1,OVERLAP=0);
 
/* Check Validity of CCM Library Assignment */
%if (%sysfunc(libref(CCM))) %then %do; libname CCM ("/data/storage/wrds/crsp/"); %end;
%if (%sysfunc(libref(CCM))) %then %do; libname CCM ("/shared/wrds/crsp/storage/a_ccm/"); %end;
%put; %put ### START. ;
 
/* Convert the overlap distance into months */
%let overlap=%sysevalf(12*&overlap.);
 
options nonotes;
/* Make sure first that the input dataset has no duplicates by GVKEY-&DATEVAR */
proc sort data=&INSET out=_ccm0 nodupkey; by GVKEY &DATEVAR; run;
 
/* Add Permno to Compustat sample */
proc sql;
create table _ccm1 as
select distinct b.lpermno as permno, a.*, b.linkprim, b.linkdt
from _ccm0 as a, ccm.ccmxpf_linktable as b
where a.gvkey=b.gvkey and index("&linktype.",strip(b.linktype))>0
and (a.&datevar>= intnx("month",b.linkdt   ,-&overlap.,"b") or missing(b.linkdt)   )
and (a.&datevar<= intnx("month",b.linkenddt, &overlap.,"e") or missing(b.linkenddt));
quit;
  
/* cleaning compustat data for no relevant duplicates                       */
/* 1. eliminating overlapping matching : few cases where different gvkeys   */
/*   for same permno-date --- some of them are not 'primary' matches in ccm.*/
/*   use linkprim='p' for selecting just one gvkey-permno-date combination; */
proc sort data=_ccm1;
  by &datevar permno descending linkprim descending linkdt gvkey;
run;
 
/* it ties in the linkprim, then use most recent link or keep all */
data _ccm2;
set _ccm1;
by &datevar permno descending linkprim descending linkdt gvkey;
if first.permno;
%if &REMDUPS=0 %then %do; drop linkprim linkdt; %end;
run;
  
%if &REMDUPS=1 %then
 %do;
   proc sort data=_ccm2; by &datevar gvkey descending linkprim descending linkdt;
   data _ccm2;
   set _ccm2;
   by &datevar gvkey descending linkprim descending linkdt;
   if first.gvkey;
   drop linkprim linkdt;
   run;
   %put ## Removed Multiple PERMNO Matches per GVKEY ;
 %end;
 
/* Sanity Check -- No Duplicates -- and Save Output Dataset */
proc sort data=_ccm2 out=&OUTSET nodupkey; by gvkey &datevar permno; run;
%put ## &OUTSET Linked Table Created;
 
/* House Cleaning */
proc sql;
 drop table _ccm0, _ccm1, _ccm2;
quit;
 
%put ### DONE . ; %put ;
options notes;
%MEND CCM;
 
 
/* ********************************************************************************* */
/* *************  Material Copyright Wharton Research Data Services  *************** */
/* ****************************** All Rights Reserved ****************************** */
/* ********************************************************************************* */

