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
    target="grib/${BASE}.ml_lnsp_z.grib_tmp"
EOF
fi
#avoid that download_ecmwf_sfc.sh access incomplete grib-file
mv grib/${BASE}.ml_lnsp_z.grib_tmp grib/${BASE}.ml_lnsp_z.grib

