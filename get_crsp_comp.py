#!python
# -*- coding: utf-8 -*-
"""
This module creates .SAS files to download and merge Compustat.
It only keeps the variables specified.
It will only work out of the box if your filesystem looks like mine.

Usage:
    get_crsp_comp.py [options]

Options:
    -h, --help       Show this help
    -a, --annual     Create Annual FUNDA file
    -q, --quarter    Create Quarterly FUNDQ file
    -c, --all        Get all fields (SELECT *)
"""

import os
import datetime as dt
from docopt import docopt
import pandas as pd
from sas7bdat import SAS7BDAT as SASdb

SAS_ZERO = dt.datetime(1960,1,1)
MIN_DATE = dt.datetime(1900, 1, 1)
MAX_DATE = dt.datetime.today()
TD_DAY = pd.Timedelta(days=1)
TD_YEAR = pd.Timedelta(days=1) * 365

def sas_date_to_datetime(df_col):
    return pd.to_timedelta(df_col, unit='d') + SAS_ZERO

def ktoq(kfield, fundq_fields):
    kq_lookup = {'prcc_f': 'prccq', 'cshpri': 'cshprq', }
    for suffix in ('', 'q', 'y'):
        if kfield + suffix in fundq_fields:
            return kfield + suffix
    return kq_lookup.get(kfield, None)

WRDS_PATH = '/data/storage/wrds/comp/'

FIELDS = ('gvkey cik tic datadate fyear fyr fqtr rdq datafqtr datacqtr '
          'conm cusip sich at lt teq prcc_f cshpri txditc invt ppent pi ni ib '
          'sale re act lct csho xrd ajex oibdp oancf dvt dlc dltt pstk '
          'dp wcap xint gdwlia xi ').split()

SQL_STRING = """
LIBNAME comp "/data/storage/wrds/comp/";
LIBNAME data "~/Dropbox/Documents/School/_data/big/";

%INCLUDE "~/Dropbox/Documents/Programming/SAS/sas_macros/wrds/quarterize.sas";
%INCLUDE "~/Dropbox/Documents/Programming/SAS/sas_macros/wrds/ccm.sas";

PROC SQL;
    CREATE TABLE {table_out}(WHERE=(DATADATE GE '01JAN1990'd)) AS
    SELECT {fields},
        MIN(datadate) AS comp_start FORMAT YYMMDD10.
    FROM {table_from}
    WHERE INDFMT= 'INDL'
    AND DATAFMT='STD'
    AND POPSRC='D'
    AND CONSOL='C'
    GROUP BY gvkey
    {order_by};
QUIT;
{extras}
*ENDSAS;
"""

def get_fundaq(path_to_fund):
    """Read funda and fundq SAS databases to get all variable names."""
    with SASdb(os.path.join(path_to_fund, 'funda.sas7bdat')) as fh:
        for funda_fields in fh:
            break
    with SASdb(os.path.join(path_to_fund, 'fundq.sas7bdat')) as fh:
        for fundq_fields in fh:
            break
    return funda_fields, fundq_fields

def main(do_funda=True, do_fundq=True, get_star=False):
    """
    Create .SAS files in /tmp and run them to generate CSV dumps of
    funda and fundq.
    """
    funda_fields, fundq_fields = get_fundaq(WRDS_PATH)
    a_fields, q_fields, q_names = [], [], []
    for f in FIELDS:
        if f not in funda_fields:
            print('A:', f)
        else:
            a_fields.append(f)

        if ktoq(f, fundq_fields) not in fundq_fields:
            print('Q:', f, [_ for _ in fundq_fields if _.startswith(f)])
        else:
            q_fields.append(ktoq(f, fundq_fields))
            q_names.append(f)
    if get_star:
        a_fields = ["*", ]
        q_fields = ["*", ]

    a_sql = SQL_STRING.format(table_out='funda',
                          fields=','.join(a_fields),
                          table_from='comp.funda',
                          left_join='',
                          order_by='ORDER BY gvkey, datadate',
                          extras="""%CCM(db_in=funda,db_out=data.funda,
                              link_table=comp.ccmxpf_linktable);""")
    q_sql = SQL_STRING.format(table_out='fundq',
                      fields=',\n\t'.join(q_fields),
                      table_from='comp.fundq',
                      left_join='',
                      order_by='ORDER BY gvkey, datadate',
                      extras="""%QUARTERIZE(db_in=fundq,db_out=fundq2,
                                            IDVAR=fyr gvkey);
                                %CCM(db_in=fundq2,db_out=data.fundq,
                                     link_table=comp.ccmxpf_linktable);
                                DATA data.fundq;
                                  SET data.fundq;oancfq=oancfy_q;DROP oancfy_q;RUN;
                             """)
    with open('/tmp/funda.sas', 'w') as fh:
        fh.write(a_sql)
    with open('/tmp/fundq.sas', 'w') as fh:
        fh.write(q_sql)

    import subprocess
    if do_funda:
        print("Processing FUNDA!")
        (subprocess.check_output(['sas', '/tmp/funda.sas']))
        print("Done with FUNDA!")
    if do_fundq:
        print("Processing FUNDQ!")
        (subprocess.check_output(['sas', '/tmp/fundq.sas']))
        print("Done with FUNDQ!")


if __name__ == '__main__':
    _args = docopt(__doc__)
    do_funda=_args.get('--annual', False)
    do_fundq=_args.get('--quarter', False)
    get_star=_args.get('--all', False)
    if do_funda or do_fundq:
        main(do_funda=do_funda, do_fundq=do_fundq, get_star=get_star)
    else:
        print(__doc__)
