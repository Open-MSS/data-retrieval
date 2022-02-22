"""
Copyright (C) 2021 by Forschungszentrum Juelich GmbH
Author(s): Joern Ungermann, May Baer
"""
import datetime
import itertools
import optparse
import os
import sys

from metpy.calc import (
    potential_temperature, potential_vorticity_baroclinic,
    brunt_vaisala_frequency_squared, geopotential_to_height)
from metpy.units import units
import xarray as xr

import numpy as np
import tqdm

VARIABLES = {
    "pres": ("FULL", "hPa", "air_pressure", "Pressure"),
    "pt": ("FULL", "K", "air_potential_temperature", "Potential Temperature"),
    "pv": ("FULL", "uK m^2 kg^-1 s^-1", "ertel_potential_vorticity", "Potential Vorticity"),
    "n2": ("FULL", "s^-2", "square_of_brunt_vaisala_frequency_in_air", "N^2"),
    "TROPOPAUSE": ("HORIZONTAL", "km", "tropopause_altitude",
                   "vertical location of first WMO thermal tropopause"),
    "TROPOPAUSE_PRESSURE": ("HORIZONTAL", "Pa", "tropopause_air_pressure",
                            "vertical location of first WMO thermal tropopause"),
    "TROPOPAUSE_THETA": ("HORIZONTAL", "K", "tropopause_air_potential_temperature",
                         "vertical location of first WMO thermal tropopause"),
    "TROPOPAUSE_SECOND": ("HORIZONTAL", "km", "secondary_tropopause_altitude",
                          "vertical location of second WMO thermal tropopause"),
    "TROPOPAUSE_SECOND_PRESSURE": ("HORIZONTAL", "Pa", "secondary_tropopause_air_pressure",
                                   "vertical location of second WMO thermal tropopause"),
    "TROPOPAUSE_SECOND_THETA": ("HORIZONTAL", "K", "secondary_tropopause_air_potential_temperature",
                                "vertical location of second WMO thermal tropopause"),
}


def find_tropopause(alts, temps):
    """
    Identifies position of thermal tropopauses in given altitude/temperature
    profile. Has some issues with inversions, which is circumventyed partly by
    setting seek to False, which is not strictly necessary by WMO definition.

    The thermal definition of the tropopause, WMO, 1957:

    (a) The first tropopause is defined as the lowest level at which the lapse
    rate decreases to 2 degree C/km or less, provided also the average lapse rate
    between this level and all higher levels within 2 km does not exceed 2 degree C/km.

    (b) If above the first tropopause the average lapse rate between any level
    and all higher levels within 1 km exceeds 3 degree C/km, then a second tropopause
    is defined by the same criterion as under (a). This tropopause may be either
    within or above the 1 km layer.
    """
    dtdz_wmo1, dtdz_wmo2 = -2, -3
    z_crit1, z_crit2 = 2, 1
    zmin, zmax = 5, 22

    alts = np.asarray(alts)
    temps = np.asarray(temps)
    valid = (~(np.isnan(alts) | np.isnan(temps))) & (alts > zmin - 3) & (alts < zmax + 3)
    alts, temps = alts[valid], temps[valid]
    if len(alts) < 3:
        return []
    if alts[0] > alts[1]:  # check for proper order and reverse if necessary
        alts = alts[::-1]
        temps = temps[::-1]

    result = []
    # This differentiation is sufficient as we are looking at average lapse rate
    # with respect to higher levels anyway, so using a more accurate left/right
    # differentiation does not really improve things here.
    lapse_rate = np.diff(temps) / np.diff(alts)

    lapse_alts = (alts[1:] + alts[:-1]) / 2.
    seek = True
    for j in range(1, len(lapse_rate)):
        if not seek and lapse_rate[j] < dtdz_wmo2:
            ks = np.where((lapse_alts[j] <= alts) & (alts <= lapse_alts[j] + z_crit2))[0]
            # This way of calculating the average lapse rate is optimal. Don't
            # try to improve. Integrate t'/(z1-z0) numerically (no trapez! do it
            # stupid way) with infinitesimal h. Differentiate numerically using
            # same h. Simplify. Voila. As h can be assumed as small as possible,
            # this is accurate.
            if len(ks) > 1:
                k, ks = ks[0], ks[1:]
                avg_lapse = (temps[ks] - temps[k]) / (alts[ks] - alts[k])
                if all(avg_lapse < -3):
                    seek = True
            else:
                seek = True

        if seek and lapse_rate[j - 1] <= dtdz_wmo1 < lapse_rate[j]:
            alt = np.interp(dtdz_wmo1,
                            lapse_rate[j - 1:j + 1], lapse_alts[j - 1:j + 1])
            if not (zmin <= alt <= zmax):
                continue

            ks = np.where((alt <= alts) & (alts <= alt + z_crit1))[0]
            if len(ks) > 1:
                k, ks = ks[0], ks[1:]
                avg_lapse = (temps[ks] - temps[k]) / (alts[ks] - alts[k])
                if all(avg_lapse > dtdz_wmo1):
                    result.append(alt)
                    seek = False
            else:
                result.append(alt)
                seek = False
    return result


def parse_args(args):
    oppa = optparse.OptionParser(usage="""
    add_ancillary.py

    Adds PV and ancillary quantities to 4D model data given as NetCDF.

    Usage: add_ancillary.py [options] <sfc netCDF file> <ml netCDF file>

    Example:
    add_ancillary.py ecmwfr_ana_sfc_06072912.nc ecmwfr_ana_ml_06072912.nc
    """)

    oppa.add_option('--theta', '', action='store_true',
                    help="Add pt potential temperature field")
    oppa.add_option('--n2', '', action='store_true',
                    help="Add n2 static stability.")
    oppa.add_option('--pv', '', action='store_true',
                    help="Add pv potential vorticity.")
    oppa.add_option('--pressure', '', action='store_true',
                    help="Add pressure")
    oppa.add_option('--tropopause', '', action='store_true',
                    help="Add first and second tropopause")
    opt, arg = oppa.parse_args(args)

    if len(arg) != 2:
        print(oppa.get_usage())
        sys.exit(1)
    if not os.path.exists(arg[0]):
        print("Cannot find model data at", arg[0])
        sys.exit(1)
    if not os.path.exists(arg[1]):
        print("Cannot find model data at", arg[1])
        sys.exit(1)
    if not (opt.theta or opt.n2 or opt.pv or opt.pressure or opt.tropopause):
        sys.exit(0)
    return opt, arg[0], arg[1]


def my_geopotential_to_height(zh):
    try:
        result = geopotential_to_height(zh)
    except ValueError:
        zh = zh.copy()
        zh.data = 9.80665 * (zh.data * units(zh.attrs["units"])).to("m").m
        zh.attrs["units"] = "m^2s^-2"
        result = geopotential_to_height(zh)
    return result


def add_tropopauses(ml, sfc):
    """
    Adds first and second thermal WMO tropopause to model. Fill value is -999.
    """

    try:
        temp = (ml["t"].data * units(ml["t"].attrs["units"])).to("K").m
        press = np.log((ml["pres"].data * units(ml["pres"].attrs["units"])
                        ).to("hPa").m)
        gph = my_geopotential_to_height(ml["z"]).data.to("km").m
        theta = (ml["pt"].data * units(ml["pt"].attrs["units"])).to("K").m
    except KeyError as ex:
        print("Some variables are missing for WMO tropopause calculation:", ex)
        return sfc

    if gph[0, 1, 0, 0] < gph[0, 0, 0, 0]:
        gph = gph[:, ::-1, :, :]
        press = press[:, ::-1, :, :]
        temp = temp[:, ::-1, :, :]
        theta = theta[:, ::-1, :, :]

    valid = np.isfinite(gph[0, :, 0, 0])
    assert gph[0, valid, 0, 0][1] > gph[0, valid, 0, 0][0]
    assert press[0, valid, 0, 0][1] < press[0, valid, 0, 0][0]

    above_tropo1 = np.empty((gph.shape[0], gph.shape[2], gph.shape[3]))
    above_tropo1[:] = np.nan
    above_tropo2 = above_tropo1.copy()
    above_tropo1_press = above_tropo1.copy()
    above_tropo2_press = above_tropo1.copy()
    above_tropo1_theta = above_tropo1.copy()
    above_tropo2_theta = above_tropo1.copy()
    for iti, ilo, ila in tqdm.tqdm(
            itertools.product(range(gph.shape[0]), range(gph.shape[3]), range(gph.shape[2])),
            total=gph.shape[0] * gph.shape[3] * gph.shape[2], ascii=True):
        tropopauses = find_tropopause(gph[iti, :, ila, ilo], temp[iti, :, ila, ilo])
        tropopauses = [x for x in tropopauses if 5 < x < 22]
        if len(tropopauses) > 0:
            above_tropo1[iti, ila, ilo] = min(tropopauses)
            above_tropo1_press[iti, ila, ilo] = np.interp(
                above_tropo1[iti, ila, ilo], gph[iti, :, ila, ilo], press[iti, :, ila, ilo])
            above_tropo1_theta[iti, ila, ilo] = np.interp(
                above_tropo1[iti, ila, ilo], gph[iti, :, ila, ilo], theta[iti, :, ila, ilo])
            second = [x for x in tropopauses if x > above_tropo1[iti, ila, ilo]]
            if len(second) > 0:
                above_tropo2[iti, ila, ilo] = min(second)
            above_tropo2_press[iti, ila, ilo] = np.interp(
                above_tropo2[iti, ila, ilo], gph[iti, :, ila, ilo], press[iti, :, ila, ilo])
            above_tropo2_theta[iti, ila, ilo] = np.interp(
                above_tropo2[iti, ila, ilo], gph[iti, :, ila, ilo], theta[iti, :, ila, ilo])

    above_tropo1_press = np.exp(above_tropo1_press)
    above_tropo2_press = np.exp(above_tropo2_press)

    for name, var in [
            ("TROPOPAUSE", above_tropo1),
            ("TROPOPAUSE_SECOND", above_tropo2),
            ("TROPOPAUSE_PRESSURE", above_tropo1_press * 100),
            ("TROPOPAUSE_SECOND_PRESSURE", above_tropo2_press * 100),
            ("TROPOPAUSE_THETA", above_tropo1_theta),
            ("TROPOPAUSE_SECOND_THETA", above_tropo2_theta)]:
        sfc[name] = (("time", "lat", "lon"), var.astype(np.float32))
        sfc[name].attrs["units"] = VARIABLES[name][1]
        sfc[name].attrs["standard_name"] = VARIABLES[name][2]
        sfc[name].attrs["long_name"] = VARIABLES[name][3]
    return sfc


def main():
    option, sfc_filename, ml_filename = parse_args(sys.argv[1:])

    sfc = xr.open_dataset(sfc_filename)
    ml = xr.open_dataset(ml_filename)

    if option.pressure:
        print("Adding pressure...")
        try:
            sp = np.exp(sfc["lnsp"])
            lev = ml["lev"].data.astype(int) - 1
            ml["pres"] = (
                ("time", "lev", "lat", "lon"),
                (ml["hyam"].data[:][lev][np.newaxis, :, np.newaxis, np.newaxis] +
                 ml["hybm"].data[:][lev][np.newaxis, :, np.newaxis, np.newaxis] *
                 sp.data[:][:, np.newaxis, :, :]) / 100)
        except KeyError as ex:
            print("Some variables miss for PRES calculation", ex)
        else:
            ml["pres"].attrs["units"] = VARIABLES["pres"][1]
            ml["pres"].attrs["standard_name"] = VARIABLES["pres"][2]
    if option.theta or option.pv:
        print("Adding potential temperature...")
        try:
            ml["pt"] = potential_temperature(ml["pres"], ml["t"])
        except KeyError as ex:
            print("Some variables miss for THETA calculation", ex)
        else:
            ml["pt"].data = ml["pt"].data.to(VARIABLES["pt"][1]).m
            ml["pt"].attrs["units"] = VARIABLES["pt"][1]
            ml["pt"].attrs["standard_name"] = VARIABLES["pt"][2]
    if option.pv:
        print("Adding potential vorticity...")
        try:
            ml = ml.metpy.assign_crs(grid_mapping_name='latitude_longitude',
                                     earth_radius=6.356766e6)
            ml["pv"] = potential_vorticity_baroclinic(
                ml["pt"], ml["pres"], ml["u"], ml["v"])
        except KeyError as ex:
            print("Some variables miss for PV calculation", ex)
        else:
            ml["pv"].data = ml["pv"].data.to(VARIABLES["pv"][1]).m
            ml["pv"].attrs["units"] = VARIABLES["pv"][1]
            ml["pv"].attrs["standard_name"] = VARIABLES["pv"][2]
        finally:
            ml = ml.drop("metpy_crs")
    if option.n2:
        print("Adding N2...")
        try:
            ml["n2"] = brunt_vaisala_frequency_squared(
                my_geopotential_to_height(ml["z"]), ml["pt"])
        except KeyError as ex:
            print("Some variables miss for N2 calculation", ex)
        else:
            ml["n2"].data = ml["n2"].data.to(VARIABLES["n2"][1]).m
            ml["n2"].attrs["units"] = VARIABLES["n2"][1]
            ml["n2"].attrs["standard_name"] = VARIABLES["n2"][2]
    if option.tropopause:
        print("Adding first and second tropopause")
        sfc = add_tropopauses(ml, sfc)

    for xin in [ml, sfc]:
        now = datetime.datetime.now().isoformat()
        history = now + ":" + " ".join(sys.argv)
        if "history" in xin.attrs:
            history += "\n" + xin.attrs["history"]
        xin.attrs["history"] = history
        xin.attrs["date_modified"] = now

    sfc.to_netcdf(sfc_filename, format="NETCDF4_CLASSIC")
    # no compression, yet, as ml is still converted by ncks
    ml.to_netcdf(ml_filename, format="NETCDF4_CLASSIC")


if __name__ == "__main__":
    main()
