#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer
if [ ! -f grib/${BASE}.sfc.grib ]; then
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
    levtype=sfc,
    param=$SFC_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.sfc.grib"
EOF
fi
echo converting sfc 
export sfcfile=mss/${BASE}.sfc.nc
export tmpfile_sfc=mss/${BASE}.sfc.tmp
cdo -f nc4c -t ecmwf copy grib/${BASE}.sfc.grib $sfcfile
ncatted -O \
    -a standard_name,BLH,o,c,atmosphere_boundary_layer_thickness \
    -a standard_name,CI,o,c,sea_ice_area_fraction \
    -a standard_name,HCC,o,c,high_cloud_area_fraction \
    -a standard_name,LCC,o,c,low_cloud_area_fraction \
    -a standard_name,LSM,o,c,land_binary_mask \
    -a standard_name,MCC,o,c,medium_cloud_area_fraction \
    -a standard_name,MSL,o,c,air_pressure_at_sea_level \
    -a standard_name,SSTK,o,c,sea_surface_temperature \
    -a standard_name,U10M,o,c,surface_eastward_wind \
    -a standard_name,V10M,o,c,surface_northward_wind \
    -a units,HCC,o,c,dimensionless \
    -a units,LCC,o,c,dimensionless \
    -a units,MCC,o,c,dimensionless \
    $sfcfile

# extract lnsp and remove lev dimension.
# wait for lnsp/Z file
until [ -f grib/${BASE}.ml_lnsp_z.grib ]
do
   echo `date` "Waiting for lnsp_z.grib..."
   sleep 1m
done
grib_copy -w shortName=lnsp grib/${BASE}.ml_lnsp_z.grib ${tmpfile_sfc}
cdo -f nc4c -t ecmwf copy ${tmpfile_sfc} ${tmpfile_sfc}2
ncwa -O -alev ${tmpfile_sfc}2 ${tmpfile_sfc}
ncks -7 -C -O -x -vhyai,hyam,hybi,hybm,lev ${tmpfile_sfc} ${tmpfile_sfc}2
rm ${tmpfile_sfc}
#lon in ml-files in range 0-360, i.e. for nc-file of lnsp, for sfc file it's  -180 to 180
#make lon to same range as in sfcfile
cdo setgrid,${sfcfile} ${tmpfile_sfc}2 ${tmpfile_sfc}3
cdo merge ${sfcfile} ${tmpfile_sfc}3 ${tmpfile_sfc}
mv ${tmpfile_sfc} $sfcfile
rm ${tmpfile_sfc}2
rm ${tmpfile_sfc}3

echo copy sfc.nc
#copy files
if ecaccess-association-list | grep -q $ECTRANS_ID; then
  echo "Transfering sfc files to "$ECTRANS_ID 
  ectrans -remote $ECTRANS_ID -source $sfcfile -target $sfcfile -overwrite -remove 
fi
