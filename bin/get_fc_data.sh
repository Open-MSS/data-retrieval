#!/bin/bash

#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer, Jens-Uwe Grooss

#SBATCH --workdir=/scratch/ms/datex/df8
#SBATCH --qos=normal
#SBATCH --job-name=get_fc_data
#SBATCH --output=get_fc_data.%j.out
#SBATCH --error=get_fc_data.%j.out

module load cdo
PATH=/home/ms/datex/df8/mambaforge/bin/:$PATH
conda activate ncenv


# Limit maximum threads to a reasonable number on large multi-core computers to avoid potential issues
export OMP_NUM_THREADS=4
export MKL_NUM_THREADS=${OMP_NUM_THREADS}
export NUMEXPR_NUM_THREADS=${OMP_NUM_THREADS}
export OPENBLAS_NUM_THREADS=${OMP_NUM_THREADS}
export VECLIB_MAXIMUM_THREADS=${OMP_NUM_THREADS}

SRCDIR=$HOME/data-retrieval/bin
WORKDIR=$SCRATCH
cd $WORKDIR
mkdir -p mss
mkdir -p grib


# get forecast date
echo Date: $MSJ_YEAR $MSJ_MONTH $MSJ_DAY
echo BASETIME, STEP:  $MSJ_BASETIME $MSJ_STEP

if [[ $MSJ_YEAR == "" ]]
then
    HH=00
    DAY=`date +%d`
    MONTH=`date +%m`
    YEAR=`date +%Y`
    STEP=0/to/36/by/6
    FSTEP=036
    FCSTEP=0
else    
   
    DAY=$MSJ_DAY
    MONTH=$MSJ_MONTH
    YEAR=$MSJ_YEAR
    HH=$MSJ_BASETIME
    FCSTEP=${MSJ_STEP:1:3}
fi

case $FCSTEP in
    036)
	STEP=0/to/36/by/6
	;;
    072)
	STEP=42/to/72/by/6
	;;
    144)
	STEP=78/to/144/by/6
	;;
    *)
	FCSTEP=$FSTEP
esac

export area=70/160/0/260
export grid=1.0/1.0
ectrans_id=data2_df8

# Set path, filenames and variables used later in the script
export DATE=${YEAR}-${MONTH}-${DAY}
export YMD=${YEAR}${MONTH}${DAY}
export TIME=${HH}:00:00
export STEP=${STEP}
export BASE=ecmwf_${YMD}_${HH}.${FCSTEP}
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
$SRCDIR/download_an_all.sh $DATE $TIME $STEP

# convert grib to netCDF, set init time
cdo -f nc4c -t ecmwf copy grib/${BASE}.tl.grib $tlfile
ncatted -a units,time,o,c,"${time_units}" $tlfile
ncrename -h -O -v PRES,pressure -v PV,pv -v Q,q -v D,d -v U,u -v V,v -v O3,o3 $tlfile
cdo -f nc4c -t ecmwf copy grib/${BASE}.pv.grib $pvfile
ncatted -a units,time,o,c,"${time_units}" $pvfile
ncrename -h -O -v PT,pt -v PRES,pressure -v U,u -v V,v -v Q,q -v O3,o3 $pvfile
cdo -f nc4c -t ecmwf copy grib/${BASE}.ml.grib $mlfile
ncatted -a units,time,o,c,"${time_units}" $mlfile
cdo -f nc4c -t ecmwf copy grib/${BASE}.sfc.grib $sfcfile
ncatted -a units,time,o,c,"${time_units}" $sfcfile
ncrename -h -O -v Z,z -v MSL,msl -v U10M,u10m -v V10M,v10m -v LCC,lcc -v MCC,mcc -v HCC,hcc $sfcfile


cdo merge $sfcfile $mlfile $tmpfile
mv $tmpfile $mlfile

ncatted -O -a standard_name,cc,o,c,cloud_area_fraction_in_atmosphere_layer \
           -a standard_name,o3,o,c,mole_fraction_of_ozone_in_air \
           -a standard_name,ciwc,o,c,specific_cloud_ice_water_content \
           -a standard_name,clwc,o,c,specific_cloud_liquid_water_content \
           -a units,cc,o,c,dimensionless $mlfile

# Add pressure and geopotential height to model levels file
$SRCDIR/add_pressure_gph.sh input=$mlfile pressure_units=Pa gph_units="m^2s^-2"

# Add ancillary information
python3 $SRCDIR/add_ancillary.py $mlfile --pv --theta --tropopause --n2

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
python3 $SRCDIR/interpolate_missing_variables.py $mlfile $tlfile pt
python3 $SRCDIR/rename_standard.py $mlfile $tlfile
ncap2 -s "pv*=1000000" $tlfile $tlfile-tmp
mv $tlfile-tmp $tlfile
ncatted -O -a standard_name,lev,o,c,atmosphere_potential_temperature_coordinate $tlfile
ncks -O -7 -L 7 $tlfile $tlfile

echo "Creating potential vorticity level file..."
ncap2 -s "lev/=1000" $pvfile $pvfile-tmp
mv $pvfile-tmp $pvfile
python3 $SRCDIR/interpolate_missing_variables.py $mlfile $pvfile pv
python3 $SRCDIR/rename_standard.py $mlfile $pvfile
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

if ecaccess-association-list | grep -q $ectrans_id; then
  echo "Transfering files to "$ectrans_id 
  ectrans -verbose -remote $ectrans_id -source $mlfile -target $mlfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $tlfile -target $tlfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $plfile -target $plfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $pvfile -target $pvfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $alfile -target $alfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $sfcfile -target $sfcfile -overwrite -remove
  # clean up locally
  rm -f $mlfile $tlfile $plfile $pvfile $alfile $sfcfile
  rm -f grib/${BASE}*.grib
  wait
fi