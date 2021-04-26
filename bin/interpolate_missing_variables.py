"""
Copyright (C) 2021 by Forschungszentrum Juelich GmbH
Author(s): May Baer
"""

from metpy.interpolate import interpolate_1d
import xarray as xr
import numpy as np
import sys


def interpolate_vertical(ml_file, inter_file, new_vertical_axis):
    """
    Linearly interpolate all 4D variables of ml_file to the levels of new_vertical_axis and save it in inter_file
    """
    with xr.load_dataset(inter_file) as interpolated:
        reference = [variable for variable in interpolated.variables if len(interpolated[variable].shape) == 4][0]
        with xr.open_dataset(ml_file) as ml:
            for variable in [variable for variable in ml.variables if variable not in interpolated.variables
                                                                      and len(ml[variable].dims) == 4
                                                                      and "lev_2" in ml[variable].dims]:
                try:
                    x = np.array(ml[new_vertical_axis].data)
                    y = np.array(ml[variable].data)
                    interpolated_data = interpolate_1d(interpolated["lev"].data, x, y, axis=1)

                    interpolated[variable] = interpolated[reference].copy(data=interpolated_data)
                    interpolated[variable].attrs = ml[variable].attrs
                except Exception as e:
                    print(variable, e)
        interpolated.to_netcdf(inter_file)


ml = sys.argv[1]
inter_file = sys.argv[2]
vertical_axis = sys.argv[3]
interpolate_vertical(ml, inter_file, vertical_axis)
