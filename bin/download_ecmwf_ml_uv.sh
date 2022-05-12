#!/bin/bash
#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): May Baer


if [ ! -f grib/${BASE}.ml_uv.grib ]; then
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
    param=$MODELUV_PARAMETERS,
    stream=oper,
    type=fc,
    target="grib/${BASE}.ml_uv.grib"
EOF
fi

export mlfile_uv=mss/${BASE}.ml_uv.nc
echo copy ml_uv
cdo -f nc4c -t ecmwf copy grib/${BASE}.ml_uv.grib $mlfile_uv
ncatted -O \
    -a units,time,o,c,"${time_units}" \
    $mlfile_uv
