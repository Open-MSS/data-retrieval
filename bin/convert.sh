#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer

export mlfile=mss/${BASE}.ml.nc
export plfile=mss/${BASE}.pl.nc
export alfile=mss/${BASE}.al.nc
export tlfile=mss/${BASE}.tl.nc
export pvfile=mss/${BASE}.pv.nc
export sfcfile=mss/${BASE}.sfc.nc
export tmpfile=mss/.${BASE}.tmp.nc

if [ ! -f grib/${BASE}.ml.grib ]; then
   echo FATAL `date` Model level file is missing
   exit
fi
if [ ! -f grib/${BASE}.sfc.grib ]; then
   echo FATAL `date` Surface file is missing
   exit
fi
if [ ! -f grib/${BASE}.pv.grib ]; then
   echo FATAL `date` Potential Vorticity level file is missing
   exit
fi
if [ ! -f grib/${BASE}.tl.grib ]; then
   echo FATAL `date` Potential Temperature level file is missing
   exit
fi


# Convert grib to netCDF, set init time
cdo -f nc4c -t ecmwf copy grib/${BASE}.tl.grib $tlfile
ncatted -O \
    -a standard_name,lev,o,c,atmosphere_potential_temperature_coordinate \
    -a units,time,o,c,"${time_units}" \
    $tlfile

cdo -f nc4c -t ecmwf copy grib/${BASE}.pv.grib $pvfile
ncatted -O \
    -a standard_name,lev,o,c,atmosphere_ertel_potential_vorticity_coordinate \
    -a units,lev,o,c,"uK m^2 kg^-1 s^-1" \
    -a units,time,o,c,"${time_units}" \
    $pvfile

cdo -f nc4c -t ecmwf copy grib/${BASE}.ml.grib $mlfile
ncatted -O \
    -a standard_name,cc,o,c,cloud_area_fraction_in_atmosphere_layer \
    -a standard_name,o3,o,c,mole_fraction_of_ozone_in_air \
    -a standard_name,ciwc,o,c,specific_cloud_ice_water_content \
    -a standard_name,clwc,o,c,specific_cloud_liquid_water_content \
    -a units,cc,o,c,dimensionless \
    -a units,time,o,c,"${time_units}" \
    $mlfile

ncdump -h $mlfile | grep -q "lev = 1 "
if [ $? -eq 0 ]; then
    echo Fixing dimensions
    cdo chname,lev,dummy $mlfile $tmpfile
    rm $mlfile
    cdo chname,lev_2,lev $tmpfile $mlfile
    rm $tmpfile
fi

cdo -f nc4c -t ecmwf copy grib/${BASE}.sfc.grib $sfcfile
ncatted -O \
    -a standard_name,HCC,o,c,high_cloud_area_fraction \
    -a standard_name,LCC,o,c,low_cloud_area_fraction \
    -a standard_name,MCC,o,c,medium_cloud_area_fraction \
    -a standard_name,MSL,o,c,air_pressure_at_sea_level \
    -a standard_name,U10M,o,c,surface_eastward_wind \
    -a standard_name,V10M,o,c,surface_northward_wind \
    -a units,HCC,o,c,dimensionless \
    -a units,LCC,o,c,dimensionless \
    -a units,MCC,o,c,dimensionless \
    $sfcfile

cdo merge $sfcfile $mlfile $tmpfile
mv $tmpfile $mlfile

# Add pressure and geopotential height to model levels file
$BINDIR/add_pressure_gph.sh $mlfile

echo add ancillary
# Add ancillary information
$PYTHON $BINDIR/add_ancillary.py $mlfile --pv --theta --tropopause --n2

echo separate sfc/ml
# Separate sfc from ml variables
ncks -7 -L 7 -C -O -x -vhyai,hyam,hybi,hybm,lev,n2,clwc,u,q,t,pres,zh,cc,w,v,ciwc,pt,pv,o3,d $mlfile $sfcfile
ncks -C -O -vtime,lev,lon,lat,n2,clwc,u,q,t,pres,zh,cc,w,v,ciwc,pt,pv,o3,d,hyai,hyam,hybi,hybm,lnsp $mlfile $mlfile

# Interpolate to different grids
echo "Creating pressure level file..."
cdo ml2pl,$PRES_LEVELS $mlfile $plfile
ncatted -O -a standard_name,plev,o,c,atmosphere_pressure_coordinate $plfile
ncap2 -O -s "plev/=100;plev@units=\"hPa\"" $plfile $plfile
ncks -7 -L 7 -C -O -x -v lev,lnsp,nhyi,nhym,hyai,hyam,hybi,hybm $plfile $plfile

echo "Creating potential temperature level file..."
$PYTHON $BINDIR/rename_standard.py $mlfile $tlfile
ncap2 -O -s "PV*=1000000" $tlfile $tlfile
ncks -O -7 -L 7 $tlfile $tlfile

echo "Creating potential vorticity level file..."
ncap2 -O -s "lev/=1000" $pvfile $pvfile
$PYTHON $BINDIR/rename_standard.py $mlfile $pvfile
$PYTHON bin/interpolate_missing_variables.py $mlfile $pvfile pv
ncks -O -7 -L 7 $pvfile $pvfile

echo "Creating altitude level file..."
ncks -C -O -vtime,lev,lon,lat,n2,u,t,pres,zh,w,v,pt,pv,hyai,hyam,hybi,hybm,lnsp $mlfile $tmpfile
cdo ml2hl,$GPH_LEVELS $tmpfile $alfile
rm $tmpfile
ncatted -O -a standard_name,height,o,c,atmosphere_altitude_coordinate $alfile
ncap2 -O -s "height@units=\"km\";height=height/1000" $alfile $alfile
ncks -7 -L 7 -C -O -x -v lev,sp,lnsp $alfile $alfile

# Model/surface levels
ncks -O -d lev,0,0 -d lev,16,28,4 -d lev,32,124,2 $mlfile $mlfile
ncatted -O -a standard_name,lev,o,c,atmosphere_hybrid_sigma_pressure_coordinate $mlfile
ncks -7 -L 7 -C -O -x -v lnsp,nhyi,nhym,hyai,hyam,hybi,hybm $mlfile $mlfile

echo "Done, your netcdf files are located at $(pwd)/mss"
