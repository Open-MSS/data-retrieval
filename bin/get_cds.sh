#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer

export BINDIR=$(dirname $0)
export WORKDIR=${BINDIR}/..

. ${BINDIR}/../settings.default
if [ -f ${BINDIR}/../settings.config ]; then
    . ${BINDIR}/../settings.config
fi


cd $WORKDIR
mkdir -p mss
mkdir -p grib
pwd

export DATE=$1
export TIME=$2
export BASE=${DATE}T${TIME}.an
export GRIB=grib/${BASE}.grib
init_date=$(date +%Y-%m-%dT%H:%M:%S)
if [[ "$init_date" > "$DATE" ]] 
then 
    init_date="${DATE}T${TIME}"
fi
export time_units="hours since ${init_date}"

# Download ml, sfc, pv and pt files
echo "Downloading files, this might take a long time!"
$PYTHON bin/download_cds.py

. $BINDIR/convert.sh

if [[ $CLEANUP == "yes" ]]                                                           
then
  # clean up locally
  rm -f grib/${BASE}*.grib
fi
