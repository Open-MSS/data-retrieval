#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer


# Limit maximum threads to a reasonable number on large multi-core computers to avoid potential issues
export OMP_NUM_THREADS=4
export MKL_NUM_THREADS=${OMP_NUM_THREADS}
export NUMEXPR_NUM_THREADS=${OMP_NUM_THREADS}
export OPENBLAS_NUM_THREADS=${OMP_NUM_THREADS}
export VECLIB_MAXIMUM_THREADS=${OMP_NUM_THREADS}

# Set path, filenames and variables used later in the script
export WORK="$(dirname $0)/.."
cd $WORK
export DATE=$1
export TIME=$2
export STEP=$3
export BASE=${DATE}T${TIME}.fc
export GRIB=grib/${BASE}.grib
export mlfile=mss/${BASE}.ml.nc
export plfile=mss/${BASE}.pl.nc
export alfile=mss/${BASE}.al.nc
export tlfile=mss/${BASE}.tl.nc
export pvfile=mss/${BASE}.pv.nc
export sfcfile=mss/${BASE}.sfc.nc
export tmpfile=mss/.${BASE}.tmp.nc
export gph_levels=0,25,50,75,100,125,150,175,200,225,250,275,300,325,350,375,400,425,450,475,500,525,550,575,600,625,650,675,700,725,750,775,800,825,850,875,900,925,950,975,1000,1025,1050,1075,1100,1125,1150,1175,1200,1225,1250,1275,1300,1325,1350,1375,1400,1425,1450,1475,1500,1525,1550,1575,1600,1625,1650,1675,1700,1725,1750,1775,1800,1825,1850,1875,1900,1925,1950,1975,2000,2050,2100,2150,2200,2250,2300,2350,2400,2450,2500,2550,2600,2650,2700,2750,2800,2850,2900,2950,3000,3050,3100,3150,3200,3250,3300,3350,3400,3450,3500,3550,3600,3650,3700,3750,3800,3850,3900,3950,4000,4100,4200,4300,4400,4500,4600,4700,4800,4900,5000,5100,5200,5300,5400,5500,5600,5700,5800,5900,6000
init_date=$(date +%Y-%m-%dT%H:%M:%S)
if [[ "$init_date" > "$DATE" ]] 
then 
    init_date="${DATE}T${TIME}"
fi
export time_units="hours since ${init_date}"

# Retrieve ml, sfc, pv and pt files
./bin/download_an_all.sh $DATE $TIME $STEP

# convert grib to netCDF, set init time
cdo -f nc4c copy grib/${BASE}.tl.grib $tlfile
ncatted -a units,time,o,c,"${time_units}" $tlfile
cdo -f nc4c copy grib/${BASE}.pv.grib $pvfile
ncatted -a units,time,o,c,"${time_units}" $pvfile
cdo -f nc4c copy grib/${BASE}.ml.grib $mlfile
ncatted -a units,time,o,c,"${time_units}" $mlfile
cdo -f nc4c copy grib/${BASE}.sfc.grib $sfcfile
ncatted -a units,time,o,c,"${time_units}" $sfcfile

cdo merge $sfcfile $mlfile $tmpfile
mv $tmpfile $mlfile

ncatted -O -a standard_name,cc,o,c,cloud_area_fraction_in_atmosphere_layer \
           -a standard_name,o3,o,c,mole_fraction_of_ozone_in_air \
           -a standard_name,ciwc,o,c,specific_cloud_ice_water_content \
           -a standard_name,clwc,o,c,specific_cloud_liquid_water_content \
           -a units,cc,o,c,dimensionless $mlfile

# Change weird cdo names
ncrename -h -O -v .var3,pt -v .var54,presure -v .var129,z -v .var131,u -v .var132,v -v .var133,q -v .var203,o3 $pvfile
ncrename -h -O -v .var54,pressure -v .var60,pv -v .var131,u -v .var132,v -v .var133,q -v .var155,d -v .var203,o3 $tlfile
ncrename -h -O -v .var129,z -v .var151,msl -v .var165,10u -v .var166,10v -v .var186,lcc -v .var187,mcc -v .var188,hcc $mlfile

# Add pressure and geopotential height to model levels file
./bin/add_pressure_gph.sh input=$mlfile pressure_units=Pa gph_units="m^2s^-2"

# Add ancillary information
python3 ./bin/add_ancillary.py $mlfile --pv --theta --tropopause --n2

# separate sfc from ml variables
ncks -7 -L 7 -C -O -x -vlev,n2,clwc,u,q,t,pressure,zh,cc,w,v,ciwc,pt,pv,mod_pv,o3,d $mlfile $sfcfile
ncatted -O -a standard_name,msl,o,c,air_pressure_at_sea_level $sfcfile
ncks -C -O -vtime,lev,lon,lat,n2,clwc,u,q,t,pressure,zh,cc,w,v,ciwc,pt,pv,mod_pv,o3,d,hyai,hyam,hybi,hybm,sp,lnsp $mlfile $tmpfile
mv $tmpfile $mlfile

# interpolate to different grids
echo "Creating pressure level file..."
cdo ml2pl,85000,50000,40000,30000,20000,15000,12000,10000,8000,6500,5000,4000,3000,2000,1000,500,100 $mlfile $plfile
ncatted -O -a standard_name,plev,o,c,atmosphere_pressure_coordinate $plfile
ncap2 -s "plev/=100;plev@units=\"hPa\"" $plfile $plfile-tmp
mv $plfile-tmp $plfile
ncks -7 -L 7 -C -O -x -v lev,sp,lnsp,nhyi,nhym,hyai,hyam,hybi,hybm $plfile $plfile

echo "Creating potential temperature level file..."
python3 ./bin/interpolate_missing_variables.py $mlfile $tlfile pt
python3 bin/rename_standard.py $mlfile $tlfile
ncap2 -s "pv*=1000000" $tlfile $tlfile-tmp
mv $tlfile-tmp $tlfile
ncatted -O -a standard_name,lev,o,c,atmosphere_potential_temperature_coordinate $tlfile
ncks -O -7 -L 7 $tlfile $tlfile

echo "Creating potential vorticity level file..."
ncap2 -s "lev/=1000" $pvfile $pvfile-tmp
mv $pvfile-tmp $pvfile
python3 ./bin/interpolate_missing_variables.py $mlfile $pvfile pv
python3 bin/rename_standard.py $mlfile $pvfile
ncatted -O -a standard_name,lev,o,c,atmosphere_ertel_potential_vorticity_coordinate $pvfile
ncatted -O -a units,lev,o,c,"m^2 K s^-1 kg^-1 10E-6" $pvfile
ncks -O -7 -L 7 $pvfile $pvfile

echo "Creating altitude level file..."
ncks -C -O -vtime,lev,lon,lat,n2,u,t,pressure,zh,w,v,pt,pv,hyai,hyam,hybi,hybm,lnsp $mlfile $tmpfile
cdo ml2hl,$gph_levels $tmpfile $alfile
ncatted -O -a standard_name,height,o,c,atmosphere_altitude_coordinate $alfile
ncap2 -s "height@units=\"km\";height=height/1000" $alfile $alfile-tmp
mv $alfile-tmp $alfile
ncks -7 -L 7 -C -O -x -v lev,sp,lnsp $alfile $alfile
rm $tmpfile

# model/surface levels
ncks -O -d lev,0,0 -d lev,16,28,4 -d lev,32,124,2 $mlfile $tmpfile
mv $tmpfile $mlfile
ncatted -O -a standard_name,lev,o,c,atmosphere_hybrid_sigma_pressure_coordinate $mlfile
ncks -7 -L 7 -C -O -x -v lev_2,sp,lnsp,nhyi,nhym,hyai,hyam,hybi,hybm $mlfile $mlfile

echo "Done, your netcdf files are located at $(pwd)/mss"

if ecaccess-association-list | grep -q 'MSS-Data-Transfer'; then
  echo "Transfering files to MSS-Data-Transfer"
  ectrans -remote MSS-Data-Transfer -source $mlfile &
  ectrans -remote MSS-Data-Transfer -source $tlfile &
  ectrans -remote MSS-Data-Transfer -source $plfile &
  ectrans -remote MSS-Data-Transfer -source $pvfile &
  ectrans -remote MSS-Data-Transfer -source $alfile &
  ectrans -remote MSS-Data-Transfer -source $sfcfile
  wait
fi
