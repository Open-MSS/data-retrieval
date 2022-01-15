#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer


if [ ! -f grib/${BASE}.ml.grib ]; then
    mars <<EOF
    retrieve,
    time=$TIME,
    date=$DATE,
    step=$STEP,
    area=$AREA,
    grid=$GRID,
    class=od,
    levelist=$MODEL_LEVELS,
    levtype=ml,
    param=$MODEL_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.ml.grib"
EOF
fi
if [ ! -f grib/${BASE}.sfc.grib ]; then
    mars <<EOF
    retrieve,
    time=$TIME,
    date=$DATE,
    step=$STEP,
    area=$AREA,
    grid=$GRID,
    class=od,
    levtype=sfc,
    param=$SFC_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.sfc.grib"
EOF
fi
if [ ! -f grib/${BASE}.pv.grib ]; then
    mars <<EOF
    retrieve,
    time=$TIME,
    date=$DATE,
    step=$STEP,
    area=$AREA,
    grid=$GRID,
    class=od,
    levelist=$PV_LEVELS,
    levtype=pv,
    param=$PV_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.pv.grib"
EOF
fi
if [ ! -f grib/${BASE}.tl.grib ]; then
    mars <<EOF
    retrieve,
    time=$TIME,
    date=$DATE,
    step=$STEP,
    area=$AREA,
    grid=$GRID,
    class=od,
    levelist=$THETA_LEVELS,
    levtype=pt,
    param=$THETA_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.tl.grib"
EOF
fi
