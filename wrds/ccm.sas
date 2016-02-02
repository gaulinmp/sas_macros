%PUT " ********************************************************************************* ";
%PUT "  WRDS Macro: CCM                                                                  ";
%PUT "  Summary   : Use CRSP-Compustat Merged Table to Add Permno to Compustat Data      ";
%PUT "  Variables : - db_in   : Input dataset: should have a gvkey and a date variable   ";
%PUT "              - datevar : Date variable to be used in the linking                  ";
%PUT "              - LINKTYPE: List of Linktypes: LU LC LX LD LN LS NP NR NU            ";
%PUT "              - REMDUPS : Flag 0/1 to remove multiple secondary permno matches     ";
%PUT "              - OVERLAP : Date Condition Overlap, in years                         ";
%PUT "              - db_out  : Compustat-CRSP link table output dataset                 ";
%PUT " ********************************************************************************* ";
%PUT;
%PUT %NRSTR(%%)CCM(db_in=, db_out=, datevar=datadate, link_table=ccm.ccmxpf_linktable, ;
%PUT .    LINKTYPE=LULC,REMDUPS=1,OVERLAP=0, debug=False)%NRSTR(;);

%MACRO CCM(db_in=, db_out=, datevar=datadate, link_table=ccm.ccmxpf_linktable,
           LINKTYPE=LULC,REMDUPS=1,OVERLAP=0, debug=False);

%IF "&debug."!="True" %THEN %DO;
 OPTIONS nonotes;
%END;

/* Check Validity of inputs and link table */
%IF NOT(%sysfunc(exist(&db_in))) %THEN %DO;
  %PUT ERROR: No input database defined or &db_in does not exist. Please include db_in= argument.;
  %ABORT;
%END;
%IF "&db_out" = "" %THEN %DO;
  %PUT ERROR: No output database defined. Please include db_out= argument.;
  %ABORT;
%END;
%IF NOT(%SYSFUNC(EXIST(&link_table))) %THEN %DO;
  %IF (%SYSFUNC(LIBREF(ccm))) %THEN LIBNAME ccm "/data/storage/wrds/crsp/";
  %IF NOT(%sysfunc(exist(ccm.ccmxpf_linktable))) %THEN %ABORT;
  %LET link_table = ccm.ccmxpf_linktable;
  %PUT No link table provided. Using &link_table.;
%END;
%PUT; %PUT ### START. ;

/* Convert the overlap distance into months */
%LET overlap=%SYSEVALF(12*&overlap.);

*OPTIONS nonotes;
/* Make sure first that the input dataset has no duplicates by GVKEY-&datevar */
PROC SORT DATA=&db_in OUT=_ccm0 NODUPKEY;
  BY gvkey &datevar;
  RUN;

/* Add Permno to Compustat sample */
PROC SQL;
  CREATE TABLE _ccm1 AS
    SELECT DISTINCT b.lpermno AS permno, a.*, b.linkprim, b.linkdt
    from _ccm0 AS a
    LEFT JOIN &link_table. AS b
      ON a.gvkey = b.gvkey
      AND INDEX("&linktype.", STRIP(b.linktype)) > 0
      AND (a.&datevar >= INTNX("month", b.linkdt, -&overlap., "B")
           OR MISSING(b.linkdt))
      AND (a.&datevar <= INTNX("month", b.linkenddt, &overlap., "E")
           OR MISSING(b.linkenddt));
QUIT;

/* cleaning compustat data for no relevant duplicates                       */
/* 1. eliminating overlapping matching : few cases where different gvkeys   */
/*   for same permno-date --- some of them are not 'primary' matches in ccm.*/
/*   use linkprim='p' for selecting just one gvkey-permno-date combination; */
PROC SORT DATA=_ccm1;
  BY &datevar permno DESCENDING linkprim DESCENDING linkdt gvkey;
RUN;

/* it ties in the linkprim, then use most recent link or keep all */
DATA _ccm2;
  SET _ccm1;
  BY &datevar permno DESCENDING linkprim DESCENDING linkdt gvkey;
  IF FIRST.permno or MISSING(permno);
  %IF &remdups=0 %THEN %DO;
    DROP linkprim linkdt;
  %END;
RUN;

%IF &remdups=1 %THEN %DO;
  PROC SORT DATA=_ccm2;
    BY &datevar gvkey DESCENDING linkprim DESCENDING linkdt;
  RUN;QUIT;

  DATA _ccm2;
    SET _ccm2;
    BY &datevar gvkey DESCENDING linkprim DESCENDING linkdt;
    IF first.gvkey;
    DROP linkprim linkdt;
  RUN;
  %PUT ## Removed Multiple PERMNO Matches per GVKEY ;
%END;

/* Sanity Check -- No Duplicates -- and Save Output Dataset */
PROC SORT DATA=_ccm2 OUT=&db_out NODUPKEY;
  BY gvkey &datevar permno;
RUN;
%PUT;%PUT CREATED LINK TABLE: &db_out;%PUT;

/* House Cleaning */
%IF "&debug."!="True" %THEN %DO;
  PROC SQL;
   DROP TABLE _ccm0, _ccm1, _ccm2;
  QUIT;

  OPTIONS notes;
%END;

%MEND CCM;


/* ********************************************************************************* */
/* *************  Material Copyright Wharton Research Data Services  *************** */
/* ****************************** All Rights Reserved ****************************** */
/* ********************************************************************************* */
