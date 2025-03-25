#!/bin/bash

#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer, Jens-Uwe Grooss

#SBATCH --qos=normal
#SBATCH --job-name=get_ecmwf
#SBATCH --output=get_ecmwf.%j.out
#SBATCH --error=get_ecmwf.%j.out


# This script works with the cdo version installed on ECACCESS and 
# in an mambaforge environment ncenv that includes cartopy (0.20.1), metpy (1.1.0)
# nco (5.0.4), netcdf4 (1.5.8), scipy (1.7.3) and xarray (0.20.2)

# Define model domain sector, resolution and id name for ectrans in settings.config

# defines for performance measurements
N=`date +%s%N`
export PS4='+[$(((`date +%s%N`-$N)/1000000))ms][${BASH_SOURCE}:${LINENO}]: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
# enable line below for debugging and performance timing
# set -x
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
#    ecaccess-job-submit -ni fc00h036 get_ecmwf.sh
# If these variables are empty, forecast times are defined in settings.config


# aviso trigger

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --date)
    AVISO_DATE="$2"
    shift # past argument
    shift # past value
    ;;
    --stream)
    STREAM="$2"
    shift # past argument
    shift # past value
    ;;
    --time)
    AVISO_HH="$2"
    shift # past argument
    shift # past value
    ;;
    --step)
    AVISO_STEP="$2"
    shift # past argument
    shift # past value
    ;;
esac
done

echo `date`: Notification received for stream $STREAM, date $AVISO_DATE, time $AVISO_HH, step $AVISO_STEP
##20250304 00 72
export YEAR=${AVISO_DATE:0:4}
export MONTH=${AVISO_DATE:4:2}
export DAY=${AVISO_DATE:6:2}
export HH=$AVISO_HH
export FCSTEP=`printf '%03d' $AVISO_STEP`

case $FCSTEP in
    036)
	export STEP=0/to/36/by/3
	;;
    072)
	export STEP=39/to/72/by/3
	;;
    108)
	export STEP=75/to/108/by/3
	;;
    144)
	export STEP=114/to/144/by/6
	;;
    228)
	export STEP=156/to/228/by/12
	;;
    *)
esac

cd $WORKDIR
mkdir -p mss
mkdir -p grib

# Set path, filenames and variables used later in the script
export DATE=${YEAR}-${MONTH}-${DAY}
export YMD=${YEAR}${MONTH}${DAY}
export TIME=${HH}:00:00
export BASE=${DATASET}.${YMD}T${HH}.${FCSTEP}
export init_date=$(date +%Y-%m-%dT%H:%M:%S)
echo BASE: $BASE

if [[ "$init_date" > "$DATE" ]] 
then 
    export init_date="${DATE}T${TIME}"
fi
export time_units="hours since ${init_date}"

# Retrieve ml, sfc, pv and pt files
. $BINDIR/download_ecmwf.sh

if [ $DOWNLOAD_ONLY == "yes" ]
then
    lockfile=grib/${BASE}.ready
    echo touch $lockfile and exit
    touch $lockfile
    exit 1
fi

# Convert grib to netCDF, set init time
. $BINDIR/convert.sh

if [ $ECTRANS_ID == "none" ]
then
    echo "no ectrans transfer -- move data to " $MSSDIR
  if [ x$TRANSFER_MODEL_LEVELS == x"yes" ]; then
      mv $mlfile $MSSDIR
  fi
  if [ -f $tlfile ]; then
      mv $tlfile $MSSDIR
  fi
  if [ -f $plfile ]; then
      mv $plfile $MSSDIR
  fi
  if [ -f $pvfile ]; then
      mv $pvfile $MSSDIR

  fi
  if [ -f $alfile ]; then
      mv $alfile $MSSDIR
  fi
  if [ -f $sfcfile ]; then
      mv $sfcfile $MSSDIR
  fi
else  

if ecaccess-association-list | grep -q $ECTRANS_ID; then
  echo "Transfering files to "$ECTRANS_ID 
  if [ x$TRANSFER_MODEL_LEVELS == x"yes" ]; then
      ectrans -remote $ECTRANS_ID -source $mlfile -target $mlfile -overwrite -remove 
  fi
  if [ -f $tlfile ]; then
      ectrans -remote $ECTRANS_ID -source $tlfile -target $tlfile -overwrite -remove 
  fi
  if [ -f $plfile ]; then
      ectrans -remote $ECTRANS_ID -source $plfile -target $plfile -overwrite -remove 
  fi
  if [ -f $pvfile ]; then
      ectrans -remote $ECTRANS_ID -source $pvfile -target $pvfile -overwrite -remove 
  fi
  if [ -f $alfile ]; then
      ectrans -remote $ECTRANS_ID -source $alfile -target $alfile -overwrite -remove 
  fi
  if [ -f $sfcfile ]; then
      ectrans -remote $ECTRANS_ID -source $sfcfile -target $sfcfile -overwrite -remove
  fi
fi
fi

if [[ x$CLEANUP == x"yes" ]]
then
  export CYMD=${CLEANUP_YEAR}${CLEANUP_MONTH}${CLEANUP_DAY}
  export CBASE=${DATASET}.${CYMD}T${HH}.${FCSTEP}
  echo cleanup $CBASE
    
  # clean up locally
  for f in $mlfile $tlfile $plfile $pvfile $alfile $sfcfile grib/${CBASE}*.grib;
  do
      if [ -f $f ];
      then
          rm $f
      fi
  done
  if [ $ECTRANS_ID == "none" ]
  then
    # clean up MSS server dir
    for f in $MSSDIR/${CBASE}*.nc
    do
	if [ -f $f ];
	then
            rm $f
	fi
    done
  fi
fi
echo `date`: ECMWF data converson finished
