"""
Copyright (C) 2021 by Forschungszentrum Juelich GmbH
Author(s): May Baer
"""

import datetime
import sys

import xarray as xr
import numpy as np

from metpy.interpolate import interpolate_1d
from metpy.calc import geopotential_to_height
from metpy.units import units


def interpolate_vertical(ml_file, new_file, vert_axis, vert_units, levels):
    """
    Linearly interpolate all 4D variables of ml_file to the levels of
    vert_axis and save it in new_file
    """

    ml = xr.load_dataset(ml_file)

    interp = xr.Dataset(coords={
        "lon": ml.coords["lon"],
        "lat": ml.coords["lat"],
        "time": ml.coords["time"],
        vert_axis: levels})
    interp.attrs = ml.attrs
    interp.coords[vert_axis].attrs = ml.variables[vert_axis].attrs
    new_coords = ("time", vert_axis, "lat", "lon")
    xp = ml[vert_axis]

    if ml[vert_axis].attrs["standard_name"] == "geopotential_height":
        xp = geopotential_to_height(xp)
        xp.attrs["units"] = str(xp.data.units)
        xp.data = xp.data.magnitude
    if ml[vert_axis].attrs["standard_name"] == "pressure":
        xp = np.log(xp)
        levels = np.log(levels)

    xp = xp.data[:] * units(xp.attrs["units"]).to(vert_units).m
    interp.coords[vert_axis].attrs["units"] = vert_units

    print("Interpolating ", end="")
    for var in list(ml.variables):
        if len(ml[var].dims) != 4:
            del ml[var]
            continue
        if var == vert_axis:
            continue
        print(var, end=" ")
        y = ml[var].data[:]
        interp[var] = (new_coords, interpolate_1d(levels, xp, y, axis=1))
        interp[var].attrs = ml[var].attrs
    print()

    now = datetime.datetime.now().isoformat()
    history = now + ":" + " ".join(sys.argv)
    if "history" in interp.attrs:
        history += "\n" + interp.attrs["history"]
    interp.attrs["history"] = history
    interp.attrs["date_modified"] = now

    interp.to_netcdf(
        new_file,
        format="NETCDF4_CLASSIC")


ml_file = sys.argv[1]
new_file = sys.argv[2]
vert_axis = sys.argv[3]
vert_units = sys.argv[4]
levels = [float(x) for x in sys.argv[5].split("/")]
interpolate_vertical(ml_file, new_file, vert_axis, vert_units, levels)
