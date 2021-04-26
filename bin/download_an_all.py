"""
Copyright (C) 2021 by Forschungszentrum Juelich GmbH
Author(s): May Baer
"""

import sys
import argparse
from threading import Thread
import os.path
# To run this example, you need a CDSAPI key
import cdsapi

parser = argparse.ArgumentParser()
parser.add_argument("date", help="The date in YYYY-MM-DD format")
parser.add_argument("time", help="The time in HH:MM:SS format")
args = parser.parse_args()

c_ml = cdsapi.Client()
c_pv = cdsapi.Client()
c_tl = cdsapi.Client()
c_sfc = cdsapi.Client()

request = {
        'class': 'od',
        'time': args.time,
        'date': args.date,
        'expver': '1',
        'stream': 'oper',
        'type': 'an',
        "area": "0/0/-80/360",
        "grid": "1.0/1.0",
    }


def ml():
    c_ml.retrieve('reanalysis-era5-complete', dict(request, **{
        'levelist': "1/to/137",
        'levtype': 'ml',
        'param': [129.128, 130.128, 131.128, 132.128, 133.128, 135.128, 152.128, 155.128, 203.128, 246.128, 247.128, 248.128],
    }), f'grib/{args.date}T{args.time}.an.ml.grib')

def pv():
    c_pv.retrieve('reanalysis-era5-complete', dict(request, **{
        'levelist': '2000',
        'levtype': 'pv',
        'param': '3/54/131/132/133/203',
    }), f'grib/{args.date}T{args.time}.an.pv.grib')

def tl():
    c_tl.retrieve('reanalysis-era5-complete', dict(request, **{
        'levelist': [330, 350, 370, 395, 430],
        'levtype': 'pt',
        'param': '54/60/131/132/133/155/203',
    }), f'grib/{args.date}T{args.time}.an.tl.grib')

def sfc():
    c_sfc.retrieve('reanalysis-era5-complete', dict(request, **{
        'levtype': 'sfc',
        'param': ["151.128", "165.128", "166.128", "186.128", "187.128", "188.128"],
    }), f'grib/{args.date}T{args.time}.an.sfc.grib')

threads = []
for levtype in [["ml", ml], ["pv", pv], ["tl", tl], ["sfc", sfc]]:
    if not os.path.isfile(f'grib/{args.date}T{args.time}.an.{levtype[0]}.grib'):
        threads.append(Thread(target=levtype[1]))

for thread in threads:
    thread.start()

for thread in threads:
    thread.join()
