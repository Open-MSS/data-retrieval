#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer

if [ ! -f grib/${BASE}.pl.grib ]; then
    mars <<EOF
    retrieve,
    time=$TIME,
    date=$DATE,
    step=$STEP,
    area=$AREA,
    grid=$GRID,
    truncation=$TRUNCATION,
    resol=$RESOL,
    class=od,
    levelist=$PRES_LEVELS,
    levtype=pl,
    param=$PRES_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.pl.grib"
EOF
fi

echo converting pl from mars

export plfile=mss/${BASE}.pl.nc
cdo -t ecmwf -f nc copy grib/${BASE}.pl.grib $plfile
ncatted -O \
    -a standard_name,PV,o,c,ertel_potential_vorticity \
    -a standard_name,O3,o,c,mass_fraction_of_ozone_in_air \
    -a standard_name,T,o,c,air_temperature \
    -a standard_name,Z,o,c,geopotential_height \
    -a standard_name,U,o,c,eastward_wind \
    -a standard_name,V,o,c,northward_wind \
    -a standard_name,Q,o,c,specific_humidity \
    -a standard_name,W,o,c,lagrangian_tendency_of_air_pressure \
    -a standard_name,D,o,c,divergence_of_wind \
    -a standard_name,plev,o,c,atmosphere_pressure_coordinate \
    $plfile

#copy files
echo "copy pl.nc (from mars)"
if ecaccess-association-list | grep -q $ECTRANS_ID; then
  echo "Transfering pl files to "$ECTRANS_ID 
  ectrans -remote $ECTRANS_ID -source $plfile -target $plfile -overwrite -remove 
fi
