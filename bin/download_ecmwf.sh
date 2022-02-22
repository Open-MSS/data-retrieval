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
    truncation=$ECMWF_TRUNCATION,
    resol=$ECMWF_RESOL,
    class=od,
    levelist=$MODEL_LEVELS,
    levtype=ml,
    param=$MODEL_PARAMETERS,
    stream=oper,
    type=$ECMWF_TYPE,
    target="grib/${BASE}.ml.grib"
EOF
fi
if [ ! -f grib/${BASE}.ml2.grib ]; then
    mars <<EOF
    retrieve,
    time=$TIME,
    date=$DATE,
    step=$STEP,
    area=$AREA,
    grid=$GRID,
    truncation=$TRUNCATION,
    resol=$RESOL,
    class=od,
    levelist=1,
    levtype=ml,
    param=$MODEL2_PARAMETERS,
    stream=oper,
    type=$ECMWF_TYPE,
    target="grib/${BASE}.ml2.grib"
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
    truncation=$TRUNCATION,
    resol=$RESOL,
    class=od,
    levtype=sfc,
    param=$SFC_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.sfc.grib"
EOF
fi
if [ ! -f grib/${BASE}.pv.grib ]; then
    if [[ x$PV_LEVELS != x"" ]]; then
        mars <<EOF
        retrieve,
        time=$TIME,
        date=$DATE,
        step=$STEP,
        area=$AREA,
        grid=$GRID,
        truncation=$TRUNCATION,
        resol=$RESOL,
        class=od,
        levelist=$PV_LEVELS,
        levtype=pv,
        param=$PV_PARAMETERS,
        stream=oper,
        type=fc,
        target="grib/${BASE}.pv.grib"
EOF
    fi
fi
