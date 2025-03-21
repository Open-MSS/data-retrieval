#!/bin/bash
#Copyright (C) 2025 by Forschungszentrum Juelich GmbH
#Author(s): Jens-Uw Grooss

export MAINDIR=$HOME/data-retrieval
export BINDIR=$MAINDIR/bin

. ${MAINDIR}/settings.default

if [ ! -f ${MAINDIR}/settings.config ]; then
    echo Please copy the settings.example to settings.config and configure your setup!
    exit 1
fi

. ${MAINDIR}/settings.config

cd $WORKDIR

export YEAR=`date +%Y`
export MONTH=`date +%m`
export DAY=`date +%d`
AMPM=`date +%p`
if [ $AMPM == AM ]
then 
    export HH=00
else
    export HH=12
fi

   
# script should start at 06h/18h to look for 00 12h forecast
export h_exit=`date --date="+6hours" +%H`

for FCSTEP in 036 072 108 144 228
do

# Set path, filenames and variables used later in the script
    export DATE=${YEAR}-${MONTH}-${DAY}
    export YMD=${YEAR}${MONTH}${DAY}
    export TIME=${HH}:00:00
    export BASE=${DATASET}.${YMD}T${HH}.${FCSTEP}
    export init_date=${DATE}T${TIME}
    echo BASE: $BASE

    lockfile=grib/${DATASET}.${YMD}T${HH}.${FCSTEP}.ready
    echo `date` waiting for lockfile $lockfile
    until  test -e $lockfile
    do
	sleep 30
	h_now=`date +%H`
	if [[ $h_now -ne $h_exit ]] 
	then
	    echo lockfile $lockfile not found by `date`
	    echo exiting script
	    exit 1
	fi
    done
    rm $lockfile
    # Convert grib to netCDF, set init time
    echo `date`: converting ${FCSTEP}h forecast
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
    fi
done
echo `date`: converting finished


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
