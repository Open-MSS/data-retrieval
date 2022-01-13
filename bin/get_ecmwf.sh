#!/bin/bash

#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer, Jens-Uwe Grooss

#SBATCH --qos=normal
#SBATCH --job-name=get_fc_data
#SBATCH --output=get_fc_data.%j.out
#SBATCH --error=get_fc_data.%j.out


# This script works with the cdo version installed on ECACCESS and 
# in an mambaforge environment ncenv that includes cartopy (0.20.1), metpy (1.1.0)
# nco (5.0.4), netcdf4 (1.5.8), scipy (1.7.3) and xarray (0.20.2)

module load cdo
. $HOME/mambaforge/etc/profile.d/conda.sh
conda activate ncenv

# Define model domain sector, resolution and id name for ectrans
export area=70/160/0/260
export grid=1.0/1.0
export ectrans_id=data2_df8

# Delete grib and nc files after transfer
cleanup=yes

# get forecast date
# If used as a shell script that is run on a event trigger,
# the $MSJ* environment variables contain the corresponding time info.
# This can be done from the web interface or e.g. by the command
#    ecaccess-job-submit -ni fc00h036 get_fc_data.sh
# If these variables are empty, a pre-defined forecast of today is run.


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
    echo Date: $MSJ_YEAR $MSJ_MONTH $MSJ_DAY
    echo BASETIME, STEP:  $MSJ_BASETIME $MSJ_STEP
   
    DAY=$MSJ_DAY
    MONTH=$MSJ_MONTH
    YEAR=$MSJ_YEAR
    HH=$MSJ_BASETIME
    FCSTEP=${MSJ_STEP:1:3}
fi

# HH=00
# DAY=13
# MONTH=01
# YEAR=2022
# STEP=0/to/36/by/6
# FSTEP=036
# FCSTEP=0
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


# write data to the $SCRATCH directory with more available disk quota
BINDIR=$HOME/data-retrieval/bin
WORKDIR=$SCRATCH
PYTHON=python3
# export WORKDIR="$(dirname $0)/.."
# BINDIR=$WORKDIR/bin
cd $WORKDIR
mkdir -p mss
mkdir -p grib
pwd


# Set path, filenames and variables used later in the script
export DATE=${YEAR}-${MONTH}-${DAY}
export YMD=${YEAR}${MONTH}${DAY}
export TIME=${HH}:00:00
export STEP=${STEP}
export BASE=ecmwf_${YMD}_${HH}.${FCSTEP}
export mlfile=mss/${BASE}.ml.nc
export plfile=mss/${BASE}.pl.nc
export alfile=mss/${BASE}.al.nc
export tlfile=mss/${BASE}.tl.nc
export pvfile=mss/${BASE}.pv.nc
export sfcfile=mss/${BASE}.sfc.nc
export tmpfile=mss/.${BASE}.tmp.nc
export gph_levels=0,250,500,750,1000,1250,1500,1750,2000,2250,2500,2750,3000,3250,3500,3750,4000,4250,4500,4750,5000,5250,5500,5750,6000,6250,6500,6750,7000,7250,7500,7750,8000,8250,8500,8750,9000,9250,9500,9750,10000,10250,10500,10750,11000,11250,11500,11750,12000,12250,12500,12750,13000,13250,13500,13750,14000,14250,14500,14750,15000,15250,15500,15750,16000,16250,16500,16750,17000,17250,17500,17750,18000,18250,18500,18750,19000,19250,19500,19750,20000,20500,21000,21500,22000,22500,23000,23500,24000,24500,25000,25500,26000,26500,27000,27500,28000,28500,29000,29500,30000,30500,31000,31500,32000,32500,33000,33500,34000,34500,35000,35500,36000,36500,37000,37500,38000,38500,39000,39500,40000,41000,42000,43000,44000,45000,46000,47000,48000,49000,50000,51000,52000,53000,54000,55000,56000,57000,58000,59000,60000
init_date=$(date +%Y-%m-%dT%H:%M:%S)
if [[ "$init_date" > "$DATE" ]] 
then 
    init_date="${DATE}T${TIME}"
fi
export time_units="hours since ${init_date}"

# Retrieve ml, sfc, pv and pt files
$BINDIR/download_ecmwf.sh $DATE $TIME $STEP

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
cdo ml2pl,85000,50000,40000,30000,20000,15000,12000,10000,8000,6500,5000,4000,3000,2000,1000,500,100 $mlfile $plfile
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
ncks -O -7 -L 7 $pvfile $pvfile

echo "Creating altitude level file..."
ncks -C -O -vtime,lev,lon,lat,n2,u,t,pres,zh,w,v,pt,pv,hyai,hyam,hybi,hybm,lnsp $mlfile $tmpfile
cdo ml2hl,$gph_levels $tmpfile $alfile
rm $tmpfile
ncatted -O -a standard_name,height,o,c,atmosphere_altitude_coordinate $alfile
ncap2 -O -s "height@units=\"km\";height=height/1000" $alfile $alfile
ncks -7 -L 7 -C -O -x -v lev,sp,lnsp $alfile $alfile

# Model/surface levels
ncks -O -d lev,0,0 -d lev,16,28,4 -d lev,32,124,2 $mlfile $mlfile
ncatted -O -a standard_name,lev,o,c,atmosphere_hybrid_sigma_pressure_coordinate $mlfile
ncks -7 -L 7 -C -O -x -v lnsp,nhyi,nhym,hyai,hyam,hybi,hybm $mlfile $mlfile

echo "Done, your netcdf files are located at $(pwd)/mss"

if ecaccess-association-list | grep -q $ectrans_id; then
  echo "Transfering files to "$ectrans_id 
  ectrans -verbose -remote $ectrans_id -source $mlfile -target $mlfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $tlfile -target $tlfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $plfile -target $plfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $pvfile -target $pvfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $alfile -target $alfile -overwrite -remove 
  ectrans -verbose -remote $ectrans_id -source $sfcfile -target $sfcfile -overwrite -remove
fi

if [[ $cleanup == "yes" ]]
then
  # clean up locally
  rm -f $mlfile $tlfile $plfile $pvfile $alfile $sfcfile
  rm -f grib/${BASE}*.grib
fi
