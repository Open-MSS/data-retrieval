"""
Copyright (C) 2021 by Forschungszentrum Juelich GmbH
Author(s): May Baer
"""

import xarray as xr
import sys


def fill_attributes(ml_file, other_file):
    """
    Takes all variables with same names and copies the attributes from ml to the file
    """
    with xr.load_dataset(other_file) as other:
        with xr.open_dataset(ml_file) as ml:
            for variable in other.variables:
                if variable in ml.variables:
                    other[variable].attrs = ml[variable].attrs
        other.to_netcdf(other_file)


ml_file = sys.argv[1]
other_file = sys.argv[2]
fill_attributes(ml_file, other_file)
