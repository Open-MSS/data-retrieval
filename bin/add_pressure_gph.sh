#!/bin/bash
# Copyright (C) 2021 by Forschungszentrum Juelich GmbH
# Author(s): May Baer, Joern Ungermann

export input=$1

TMPDIR=$(mktemp -d) 

echo "Adding pressure..."
cdo pressure_fl -aexpr,"aps=exp(lnsp)" $input $TMPDIR/pressure.nc
ncrename -vpressure,pres $TMPDIR/pressure.nc

echo "Merging to original file..."
cdo merge $input $TMPDIR/pressure.nc $TMPDIR/merged.nc
mv $TMPDIR/merged.nc $input
rm -rf $TMPDIR
