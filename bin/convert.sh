#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer

export mlfile=mss/${BASE}.ml.nc
export mlfile_u=mss/${BASE}.ml_u.nc
export mlfile_v=mss/${BASE}.ml_v.nc
export mlfile_uv=mss/${BASE}.ml_uv.nc
export mlfile_tq=mss/${BASE}.ml_tq.nc
export plfile=mss/${BASE}.pl.nc
export pvfile=mss/${BASE}.pv.nc
export alfile=mss/${BASE}.al.nc
export tlfile=mss/${BASE}.tl.nc
export sfcfile=mss/${BASE}.sfc.nc
export sfcfile_ancillary=mss/${BASE}.sfc_ancillary.nc
export tmpfile=mss/${BASE}.tmp

if [ ! -f grib/${BASE}.ml_tq.grib ]; then
   echo FATAL `date` "Model level t,q file (grib) is missing"
   exit
fi
if [ ! -f grib/${BASE}.ml_lnsp_z.grib ]; then
   echo FATAL `date` "Model level lnsp, z file (grib) is missing"
   exit
fi
if [ ! -f $sfcfile ]; then
   echo FATAL `date` "Surface file(nc) is missing"
   exit
fi

echo adding gph
$PYTHON $BINDIR/compute_geopotential_on_ml.py grib/${BASE}.ml_tq.grib grib/${BASE}.ml_lnsp_z.grib -o ${tmpfile}
cdo -f nc4c -t ecmwf copy ${tmpfile} ${tmpfile}_z
ncatted -O \
    -a standard_name,z,o,c,geopotential_height \
    ${tmpfile}_z
rm ${tmpfile}

#merge ml-grib files and convert with cdo to netcdf (sorting ascending for time step requried in grib_copy otherwise cdo does not recognise correct times for additional vars)
echo "merge ml-grib files (check this section if you miss additonal parameters in ml files)"
if [[ -f grib/${BASE}.ml1.grib && -f grib/${BASE}.ml2.grib && -f grib/${BASE}.ml3.grib && -f grib/${BASE}.ml4.grib && -f grib/${BASE}.ml5.grib ]]; then
   grib_copy -B'step:i asc' grib/${BASE}.ml_tq.grib grib/${BASE}.ml1.grib grib/${BASE}.ml2.grib grib/${BASE}.ml3.grib grib/${BASE}.ml4.grib grib/${BASE}.ml5.grib grib/${BASE}.ml.grib
elif [[ -f grib/${BASE}.ml1.grib && -f grib/${BASE}.ml2.grib && -f grib/${BASE}.ml3.grib && -f grib/${BASE}.ml4.grib ]]; then
   grib_copy -B'step:i asc' grib/${BASE}.ml_tq.grib grib/${BASE}.ml1.grib grib/${BASE}.ml2.grib grib/${BASE}.ml3.grib grib/${BASE}.ml4.grib grib/${BASE}.ml.grib
elif [[ -f grib/${BASE}.ml1.grib && -f grib/${BASE}.ml2.grib && -f grib/${BASE}.ml3.grib ]]; then
   grib_copy -B'step:i asc' grib/${BASE}.ml_tq.grib grib/${BASE}.ml1.grib grib/${BASE}.ml2.grib grib/${BASE}.ml3.grib grib/${BASE}.ml.grib
else
   grib_copy -B'step:i asc' grib/${BASE}.ml_tq.grib grib/${BASE}.ml.grib
fi
echo copy ml
cdo -f nc4c -t ecmwf copy grib/${BASE}.ml.grib $mlfile
ncatted -O \
    -a standard_name,cc,o,c,cloud_area_fraction_in_atmosphere_layer \
    -a standard_name,ciwc,o,c,specific_cloud_ice_water_content \
    -a standard_name,clwc,o,c,specific_cloud_liquid_water_content \
    -a units,cc,o,c,dimensionless \
    -a units,time,o,c,"${time_units}" \
    $mlfile
if [[ x$MODEL_PARAMETERS4 == x"O3" ]]; then 
  ncatted -O \
      -a standard_name,o3,o,c,mass_fraction_of_ozone_in_air \
      $mlfile
fi
echo "merge ml-file and geopot. height"
cdo merge ${mlfile} ${tmpfile}_z ${tmpfile}
mv ${tmpfile} $mlfile 

echo fix up ml for wms server but keep original for later calculations
ncks -O -7 -C -x -v hyai,hyam,hybi,hybm $MODEL_REDUCTION $mlfile $tmpfile
ncatted -O -a standard_name,lev,o,c,atmosphere_hybrid_sigma_pressure_coordinate $tmpfile

#copy files
if ecaccess-association-list | grep -q $ECTRANS_ID; then
  echo "Compress ml file before transfering"
  date
  nccopy -u -d5 $tmpfile ${tmpfile}c
  date
  echo "Transfering ml (without u/v and ancillary) files to "$ECTRANS_ID 
  ectrans -remote $ECTRANS_ID -source ${tmpfile}c -target $mlfile -overwrite -remove
  rm ${tmpfile}c 
fi

echo "merge ml file and uv file for later calculations"
cdo -O merge ${mlfile} ${mlfile_u} ${mlfile_v} ${mlfile_uv}

echo add ancillary
#ancillary data are saved to ${sfcfile}ancillary and ${mlfile_uv}ancillary
$PYTHON $BINDIR/add_ancillary.py $sfcfile $mlfile_uv $ANCILLARY
if [ -f ${sfcfile}ancillary ]; then
   mv ${sfcfile}ancillary ${sfcfile_ancillary}
fi

echo "fix up ml complete tmp file (i.e. mfile_uv) for press-, th-, gph-level calculations" 
ncks -O -7 -C -x -v hyai,hyam,hybi,hybm $MODEL_REDUCTION ${mlfile_uv} ${mlfile_uv}
ncatted -O -a standard_name,lev,o,c,atmosphere_hybrid_sigma_pressure_coordinate ${mlfile_uv}

if [[ x$PRES_LEVELS != x"" ]] && [[ x$PRES_FROM_MARS != x"yes" ]]; then
    echo "Creating pressure level file..."
    $PYTHON $BINDIR/interpolate_model.py ${mlfile_uv} $plfile pres hPa $PRES_LEVELS
    ncatted -O -a standard_name,pres,o,c,atmosphere_pressure_coordinate $plfile
fi

if [[ x$THETA_LEVELS != x"" ]]; then
    echo "Creating potential temperature level file..."
    #requires pt from ${mlfile_uv}ancillary
    export ptfile=mss/${BASE}.pt_tmp.nc
    cdo select,name=pt ${mlfile_uv}ancillary ${ptfile}
    cdo -O merge ${mlfile_uv} ${ptfile} ${mlfile_uv}tmp
    $PYTHON $BINDIR/interpolate_model.py ${mlfile_uv}tmp $tlfile pt K $THETA_LEVELS
    ncatted -O -a standard_name,pt,o,c,atmosphere_potential_temperature_coordinate $tlfile
    rm ${mlfile_uv}tmp
    rm ${ptfile}
fi

if [[ x$GPH_LEVELS != x"" ]]; then
    echo "Creating altitude level file..."
    $PYTHON $BINDIR/interpolate_model.py ${mlfile_uv} $alfile z m $GPH_LEVELS
    ncatted -O -a standard_name,z,o,c,atmosphere_altitude_coordinate $alfile
fi

#overwrite mlfile_uv with mlfile that contains u,v and ancillary
mv ${mlfile_uv}ancillary ${mlfile_uv}

echo "fix up ml u,v,ancillary file"
ncks -O -7 -C -x -v hyai,hyam,hybi,hybm $MODEL_REDUCTION $mlfile_uv $mlfile_uv
ncatted -O -a standard_name,lev,o,c,atmosphere_hybrid_sigma_pressure_coordinate $mlfile_uv
echo "Compress ml u,v,ancillary"
date
nccopy -u -d5 $mlfile_uv ${mlfile_uv}c
mv ${mlfile_uv}c $mlfile_uv
date
echo "Done, your netcdf files are located at $(pwd)/mss"
