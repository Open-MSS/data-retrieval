#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer

if [ ! -f grib/${BASE}.pv.grib ]; then
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
    levelist=$PV_LEVELS,
    levtype=pv,
    param=$PV_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.pv.grib"
EOF
fi

echo converting pv
export pvfile=mss/${BASE}.pv.nc
cdo -f nc4c -t ecmwf copy grib/${BASE}.pv.grib $pvfile
ncatted -O \
    -a standard_name,lev,o,c,atmosphere_ertel_potential_vorticity_coordinate \
    -a standard_name,Z,o,c,geopotential_height \
    -a standard_name,O3,o,c,mass_fraction_of_ozone_in_air \
    -a standard_name,PRES,o,c,air_pressure \
    -a standard_name,PT,o,c,air_potential_temperature \
    -a standard_name,Q,o,c,specific_humidity \
    -a standard_name,U,o,c,eastward_wind \
    -a standard_name,V,o,c,northward_wind \
    -a units,lev,o,c,"uK m^2 kg^-1 s^-1" \
    -a units,time,o,c,"${time_units}" \
    $pvfile
ncap2 -O -s "lev/=1000" $pvfile $pvfile
ncks -O -7 -L 7 $pvfile $pvfile

#copy files
if ecaccess-association-list | grep -q $ECTRANS_ID; then
  echo "Transfering pv files to "$ECTRANS_ID 
  ectrans -remote $ECTRANS_ID -source $pvfile -target $pvfile -overwrite -remove 
fi
