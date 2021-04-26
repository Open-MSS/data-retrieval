#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer

declare -A GPH_FAC=( ["m"]=1. ["km"]=1000.0 ["m^2s^-2"]=9.80665 )
declare -A PRESSURE_FAC=( ["hPa"]=100.0 ["Pa"]=1.0 )

# Dynamically assign named command line arguments
for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=) 
    declare "$KEY=$VALUE"     
done

echo "Adding geopotential height..."
ncap2 -s 'sp=exp(lnsp);sp@units="Pa";sp@standard_name="surface_air_pressure";sp@code=134;sp@table=128' $input sp.nc
cdo gheight sp.nc gph.nc
# gheight is in meters, convert
ncap2 -s "zh=zh*${GPH_FAC[$gph_units]};zh@units=\"${gph_units}\"" gph.nc gph2.nc
mv gph2.nc gph.nc

echo "Adding pressure..."
cdo pressure_fl sp.nc pressure.nc
# pressure is in Pa, convert
ncap2 -s "pressure=pressure/${PRESSURE_FAC[$pressure_units]};pressure@units=\"${pressure_units}\"" pressure.nc pressure2.nc
mv pressure2.nc pressure.nc

echo "Merging to original file..."
cdo merge sp.nc gph.nc pressure.nc merged.nc
mv merged.nc $input
rm gph.nc pressure.nc sp.nc
