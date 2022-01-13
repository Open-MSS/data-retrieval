#!/bin/bash
# Copyright (C) 2021 by Forschungszentrum Juelich GmbH
# Author(s): May Baer, Joern Ungermann

export input=$1

echo "Adding geopotential height..."
cdo gheight -aexpr,"aps=exp(lnsp)" $input gph.nc

echo "Adding pressure..."
cdo pressure_fl -aexpr,"aps=exp(lnsp)" $input pressure.nc
ncrename -vpressure,pres pressure.nc

echo "Merging to original file..."
cdo merge $input gph.nc pressure.nc merged.nc
mv merged.nc $input
rm gph.nc pressure.nc
