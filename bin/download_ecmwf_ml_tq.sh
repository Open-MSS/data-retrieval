#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer
if [ ! -f grib/${BASE}.ml_tq.grib ]; then
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
    levelist=$MODEL_LEVELS,
    levtype=ml,
    param=T/Q,
    stream=oper,
    type=fc,
    target="grib/${BASE}.ml_tq.grib"
EOF
fi

