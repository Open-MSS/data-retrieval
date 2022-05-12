#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer


if [ ! -f grib/${BASE}.ml_v.grib ]; then
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
    param=V,
    stream=oper,
    type=fc,
    target="grib/${BASE}.ml_v.grib"
EOF
fi

export mlfile_v=mss/${BASE}.ml_v.nc
echo copy ml_v
cdo -f nc4c -t ecmwf copy grib/${BASE}.ml_v.grib $mlfile_v
ncatted -O \
    -a units,time,o,c,"${time_units}" \
    $mlfile_v
