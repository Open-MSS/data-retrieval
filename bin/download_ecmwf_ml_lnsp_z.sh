#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer
if [ ! -f grib/${BASE}.ml_lnsp_z.grib ]; then
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
    param=LNSP/Z,
    stream=oper,
    type=fc,
    target="grib/${BASE}.ml_lnsp_z.grib"
EOF
fi

