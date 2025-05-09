#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer

export mlfile=mss/${BASE}.${LABEL}ml.nc
export plfile=mss/${BASE}.${LABEL}pl.nc
export alfile=mss/${BASE}.${LABEL}al.nc
export tlfile=mss/${BASE}.${LABEL}tl.nc
export pvfile=mss/${BASE}.${LABEL}pv.nc
export sfcfile=mss/${BASE}.${LABEL}sfc.nc
export tmpfile=mss/.${BASE}.${LABEL}tmp

if [ ! -f grib/${BASE}.ml.grib ]; then
   echo FATAL `date` Model level file is missing
   exit
fi
if [ ! -f grib/${BASE}.ml2.grib ]; then
   echo FATAL `date` Model2 level file is missing
   exit
fi
if [[ x$SFC_PARAMETERS != x"" ]]; then
    if [ ! -f grib/${BASE}.sfc.grib ]; then
       echo FATAL `date` Surface file is missing
       exit
    fi
fi
if [[ x$PV_LEVELS != x"" ]]; then
    if [ ! -f grib/${BASE}.pv.grib ]; then
       echo FATAL `date` Potential Vorticity level file is missing
       exit
    fi
fi

echo adding gph

$PYTHON $BINDIR/compute_geopotential_on_ml.py grib/${BASE}.ml.grib grib/${BASE}.ml2.grib -o ${tmpfile}

cdo -f nc4c -t ecmwf copy ${tmpfile} ${tmpfile}_z
ncatted -O \
    -a standard_name,z,o,c,geopotential_height \
    ${tmpfile}_z
rm ${tmpfile}

echo copy ml
cdo -f nc4c -t ecmwf copy grib/${BASE}.ml.grib $mlfile
ncatted -O \
    -a standard_name,cc,o,c,cloud_area_fraction_in_atmosphere_layer \
    -a standard_name,o3,o,c,mass_fraction_of_ozone_in_air \
    -a standard_name,ciwc,o,c,specific_cloud_ice_water_content \
    -a standard_name,clwc,o,c,specific_cloud_liquid_water_content \
    -a units,cc,o,c,dimensionless \
    -a units,time,o,c,"${time_units}" \
    $mlfile
cdo merge ${mlfile} ${tmpfile}_z ${tmpfile}
mv ${tmpfile} $mlfile 
rm ${tmpfile}_z

if [[ x$SFC_PARAMETERS != x"" ]]; then
    echo converting sfc
    cdo -f nc4c -t ecmwf copy grib/${BASE}.sfc.grib $sfcfile

    cdo showatts  $sfcfile
    echo "ncatted"

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
        -a standard_name,TCW,o,c,total_column_water \
        -a standard_name,TCWV,o,c,total_column_cloud_liquid_water \
        -a standard_name,T2M,o,c,2_meter_temperature \
        -a standard_name,D2M,o,c,2_meter_dewpoint \
        -a standard_name,ISHF,o,c,instantaneous_surface_sensible_heat_flux\
        -a standard_name,IEWS,o,c,instantaneous_x_surface_stress\
        -a standard_name,INSS,o,c,instantaneous_y_surface_stress\
        -a units,HCC,o,c,dimensionless \
        -a units,LCC,o,c,dimensionless \
        -a units,MCC,o,c,dimensionless \
        -a units,CI,o,c,dimensionless \
        -a units,LSM,o,c,dimensionless \
        -a units,ASN,o,c,dimensionless \
        -a units,SD,o,c,m \
        $sfcfile

    cdo showatts  $sfcfile
fi
# extract lnsp and remove lev dimension.
grib_copy -w shortName=lnsp grib/${BASE}.ml2.grib ${tmpfile}
cdo -f nc4c -t ecmwf copy ${tmpfile} ${tmpfile}2
ncwa -O -alev ${tmpfile}2 ${tmpfile}
ncks -7 -C -O -x -vhyai,hyam,hybi,hybm,lev ${tmpfile} ${tmpfile}2
rm ${tmpfile}
if [[ x$SFC_PARAMETERS != x"" ]]; then
    cdo merge ${sfcfile} ${tmpfile}2 ${tmpfile}
else
    mv ${tmpfile}2 ${tmpfile}
fi
mv ${tmpfile} $sfcfile
rm ${tmpfile}2

echo add ancillary
$PYTHON $BINDIR/add_ancillary.py $sfcfile $mlfile $ANCILLARY

echo fix up ml
ncks -O -7 -C -x -v hyai,hyam,hybi,hybm $MODEL_REDUCTION $mlfile $mlfile
ncatted -O -a standard_name,lev,o,c,atmosphere_hybrid_sigma_pressure_coordinate $mlfile

if [[ x$PV_LEVELS != x"" ]]; then
    echo converting pv
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
fi

if [[ x$PRES_LEVELS != x"" ]]; then
    echo "Creating pressure level file..."
    $PYTHON $BINDIR/interpolate_model.py $mlfile $plfile pres hPa $PRES_LEVELS
    ncatted -O -a standard_name,pres,o,c,atmosphere_pressure_coordinate $plfile
fi

if [[ x$THETA_LEVELS != x"" ]]; then
    echo "Creating potential temperature level file..."
    $PYTHON $BINDIR/interpolate_model.py $mlfile $tlfile pt K $THETA_LEVELS
    ncatted -O -a standard_name,pt,o,c,atmosphere_potential_temperature_coordinate $tlfile
fi

if [[ x$GPH_LEVELS != x"" ]]; then
    echo "Creating altitude level file..."
    $PYTHON $BINDIR/interpolate_model.py $mlfile $alfile z m $GPH_LEVELS
    ncatted -O -a standard_name,z,o,c,atmosphere_altitude_coordinate $alfile
fi

echo "Done, your netcdf files are located at $(pwd)/mss"
