import sys
import xarray as xr

xr.load_dataset(sys.argv[1], engine="cfgrib").to_netcdf(sys.argv[2])
