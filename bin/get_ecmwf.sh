#!/bin/bash

#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer, Jens-Uwe Grooss

#SBATCH --qos=normal
#SBATCH --job-name=get_fc_data
#SBATCH --output=get_fc_data.%j.out
#SBATCH --error=get_fc_data.%j.out


# This script works with the cdo version installed on ECACCESS and 
# in an mambaforge environment ncenv that includes cartopy (0.20.1), metpy (1.1.0)
# nco (5.0.4), netcdf4 (1.5.8), scipy (1.7.3) and xarray (0.20.2)

# Define model domain sector, resolution and id name for ectrans

export MAINDIR=$HOME/data-retrieval
export BINDIR=$MAINDIR/bin

. ${MAINDIR}/settings.default

if [ ! -f ${MAINDIR}/settings.config ]; then
    echo Please copy the settings.example to settings.config and configure your setup!
    exit 1
fi

. ${MAINDIR}/settings.config

# get forecast date
# If used as a shell script that is run on a event trigger,
# the $MSJ* environment variables contain the corresponding time info.
# This can be done from the web interface or e.g. by the command
#    ecaccess-job-submit -ni fc00h036 get_fc_data.sh
# If these variables are empty, forecast times are defined in settings.


if [[ $MSJ_YEAR != "" ]]
then
    echo Date: $MSJ_YEAR $MSJ_MONTH $MSJ_DAY
    echo BASETIME, STEP:  $MSJ_BASETIME $MSJ_STEP
   
    export DAY=$MSJ_DAY
    export MONTH=$MSJ_MONTH
    export YEAR=$MSJ_YEAR
    export HH=$MSJ_BASETIME
    export FCSTEP=${MSJ_STEP: -3}

    case $FCSTEP in
	036)
	    export STEP=0/to/36/by/6
	    ;;
	072)
	    export STEP=42/to/72/by/6
	    ;;
	144)
	    export STEP=78/to/144/by/6
	    ;;
	*)
    esac
fi


cd $WORKDIR
mkdir -p mss
mkdir -p grib

# Set path, filenames and variables used later in the script
export DATE=${YEAR}-${MONTH}-${DAY}
export YMD=${YEAR}${MONTH}${DAY}
export TIME=${HH}:00:00
export BASE=ecmwf_${YMD}_${HH}.${FCSTEP}
export init_date=$(date +%Y-%m-%dT%H:%M:%S)
echo $BASE

if [[ "$init_date" > "$DATE" ]] 
then 
    export init_date="${DATE}T${TIME}"
fi
export time_units="hours since ${init_date}"

# Retrieve ml, sfc, pv and pt files
$BINDIR/download_ecmwf.sh

# Convert grib to netCDF, set init time
. $BINDIR/convert.sh

if ecaccess-association-list | grep -q $ECTRANS_ID; then
  echo "Transfering files to "$ECTRANS_ID 
  ectrans -verbose -remote $ECTRANS_ID -source $mlfile -target $mlfile -overwrite -remove 
  if [ -f $tlfile ]; then
      ectrans -verbose -remote $ECTRANS_ID -source $tlfile -target $tlfile -overwrite -remove 
  fi
  if [ -f $plfile ]; then
      ectrans -verbose -remote $ECTRANS_ID -source $plfile -target $plfile -overwrite -remove 
  fi
  if [ -f $pvfile ]; then
      ectrans -verbose -remote $ECTRANS_ID -source $pvfile -target $pvfile -overwrite -remove 
  fi
  if [ -f $alfile ]; then
      ectrans -verbose -remote $ECTRANS_ID -source $alfile -target $alfile -overwrite -remove 
  fi
  if [ -f $sfcfile ]; then
      ectrans -verbose -remote $ECTRANS_ID -source $sfcfile -target $sfcfile -overwrite -remove
  fi
fi

if [[ $CLEANUP == "yes" ]]
then
  # clean up locally
  rm -f $mlfile $tlfile $plfile $pvfile $alfile $sfcfile
  rm -f grib/${BASE}*.grib
fi
