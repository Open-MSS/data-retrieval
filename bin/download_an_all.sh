#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer

cd $WORK
. settings.config

if [ ! -f grib/${BASE}.ml.grib ]; then
    mars <<EOF
    retrieve,
    time=$2,
    date=$1,
    step=$3,
    area=$area,
    grid=$grid,
    class=od,
    levelist=1/to/137,
    levtype=ml,
    param=130.128/131.128/132.128/133.128/135.128/152.128/155.128/203.128/246.128/247.128/248.128,
    stream=oper,
    type=fc,
    target="grib/${BASE}.ml.grib"
EOF
fi
if [ ! -f grib/${BASE}.sfc.grib ]; then
    mars <<EOF
    retrieve,
    time=$2,
    date=$1,
    step=$3,
    area=$area,
    grid=$grid,
    class=od,
    levtype=sfc,
    param=129.128/151.128/165.128/166.128/186.128/187.128/188.128,
    stream=oper,
    type=fc,
    target="grib/${BASE}.sfc.grib"
EOF
fi
if [ ! -f grib/${BASE}.pv.grib ]; then
    mars <<EOF
    retrieve,
    time=$2,
    date=$1,
    step=$3,
    area=$area,
    grid=$grid,
    class=od,
    levelist=2000,
    levtype=pv,
    param=3/54/131/132/133/203,
    stream=oper,
    type=fc,
    target="grib/${BASE}.pv.grib"
EOF
fi
if [ ! -f grib/${BASE}.tl.grib ]; then
    mars <<EOF
    retrieve,
    time=$2,
    date=$1,
    step=$3,
    area=$area,
    grid=$grid,
    class=od,
    levelist=330/350/370/395/475,
    levtype=pt,
    param=54/60/131/132/133/155/203,
    stream=oper,
    type=fc,
    target="grib/${BASE}.tl.grib"
EOF
fi
