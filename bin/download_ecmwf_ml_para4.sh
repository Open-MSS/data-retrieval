#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer
if [ ! -f grib/${BASE}.ml4.grib ]; then
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
    param=$MODEL_PARAMETERS4,
    stream=oper,
    type=fc,
    target="grib/${BASE}.ml4.grib"
EOF
fi
