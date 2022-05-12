#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer


if [ ! -f grib/${BASE}.ml_u.grib ]; then
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
    param=U,
    stream=oper,
    type=fc,
    target="grib/${BASE}.ml_u.grib"
EOF
fi

export mlfile_u=mss/${BASE}.ml_u.nc
echo copy ml_u
cdo -f nc4c -t ecmwf copy grib/${BASE}.ml_u.grib $mlfile_u
ncatted -O \
    -a units,time,o,c,"${time_units}" \
    $mlfile_u
