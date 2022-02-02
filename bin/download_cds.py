"""
Copyright (C) 2021 by Forschungszentrum Juelich GmbH
Author(s): May Baer
"""

from threading import Thread
import os.path
# To run this example, you need a CDSAPI key
import cdsapi

c_ml = cdsapi.Client()
c_pv = cdsapi.Client()
c_tl = cdsapi.Client()
c_sfc = cdsapi.Client()

date = os.environ["DATE"]
time = os.environ["TIME"]

request = {
        'class': 'od',
        'time': time,
        'date': date,
        'expver': '1',
        'stream': 'oper',
        'type': 'an',
        "area": os.environ["AREA"],
        "grid": os.environ["GRID"],
    }


def ml():
    c_ml.retrieve('reanalysis-era5-complete', dict(request, **{
        'levelist': os.environ["MODEL_LEVELS"],
        'levtype': 'ml',
        'param': os.environ["MODEL_PARAMETERS"],
    }), f'grib/{date}T{time}.an.ml.grib')


def ml2():
    c_ml.retrieve('reanalysis-era5-complete', dict(request, **{
        'levelist': '1',
        'levtype': 'ml',
        'param': os.environ["MODEL2_PARAMETERS"],
    }), f'grib/{date}T{time}.an.ml2.grib')


def pv():
    c_pv.retrieve('reanalysis-era5-complete', dict(request, **{
        'levelist': os.environ["PV_LEVELS"],
        'levtype': 'pv',
        'param': os.environ["PV_PARAMETERS"],
    }), f'grib/{date}T{time}.an.pv.grib')


def sfc():
    c_sfc.retrieve('reanalysis-era5-complete', dict(request, **{
        'levtype': 'sfc',
        'param': os.environ["SFC_PARAMETERS"],
    }), f'grib/{date}T{time}.an.sfc.grib')


threads = []
for levtype in ["ml", "ml2", "pv", "sfc"]:
    if not os.path.isfile(f'grib/{date}T{time}.an.{levtype}.grib'):
        threads.append(Thread(target=globals()[levtype]))

for thread in threads:
    thread.start()

for thread in threads:
    thread.join()
