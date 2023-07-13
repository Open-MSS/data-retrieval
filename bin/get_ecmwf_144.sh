#!/bin/bash

#Copyright (C) 2021 by Forschungszentrum Juelich GmbH
#Author(s): Joern Ungermann, May Baer, Jens-Uwe Grooss

#SBATCH --qos=et
#SBATCH --job-name=get_ecmwf
#SBATCH --output=/ec/res4/scratch/ddp/mss_wms/files_for_mss/batch_out/get_ecmwf.%j.out
#SBATCH --error=/ec/res4/scratch/ddp/mss_wms/files_for_mss/batch_out/get_ecmwf.%j.out
#SBATCH --chdir=/ec/res4/scratch/ddp/mss_wms/files_for_mss/batch_out/


# This script works with the cdo version installed on ECACCESS and 
# in an mambaforge environment ncenv that includes cartopy (0.20.1), metpy (1.1.0)
# nco (5.0.4), netcdf4 (1.5.8), scipy (1.7.3) and xarray (0.20.2)

# Define model domain sector, resolution and id name for ectrans in settings.config

# defines for performance measurements
N=`date +%s%N`
export PS4='+[$(((`date +%s%N`-$N)/1000000))ms][${BASH_SOURCE}:${LINENO}]: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
# enable line below for debugging and performance timing
# set -x

export MAINDIR=$HOME/mss_wms/data_retrieval_for_ipa_mss_wms_atos/data-retrieval/
export BINDIR=$MAINDIR/bin

. ${MAINDIR}/settings.default

if [ ! -f ${MAINDIR}/settings_144.config ]; then
    echo Please copy the settings.example to settings_144.config and configure your setup!
    exit 1
fi

. ${MAINDIR}/settings_144.config

# get forecast date
# If used as a shell script that is run on a event trigger,
# the $MSJ* environment variables contain the corresponding time info.
# This can be done from the web interface or e.g. by the command
#    ecaccess-job-submit -ni fc00h144 get_ecmwf.sh
# If these variables are empty, forecast times are defined in settings.config


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
	    export STEP=0/to/36/by/3
	    ;;
	072)
	    export STEP=39/to/72/by/3
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
export BASE=${DATASET}.${YMD}T${HH}.${FCSTEP}
export init_date=$(date +%Y-%m-%dT%H:%M:%S)
echo $BASE

if [[ "$init_date" > "$DATE" ]] 
then 
    export init_date="${DATE}T${TIME}"
fi
export time_units="hours since ${init_date}"

# Retrieve pl files from mars
if [ x$PRES_FROM_MARS == x"yes" ]; then
  echo "Run mars request for data on pl..."
  date
  . $BINDIR/download_ecmwf_pl.sh &
fi
# Retrieve ml, sfc, pv and pt files
echo "Run mars request for data ml lnsp/Z..."
date 
. $BINDIR/download_ecmwf_ml_lnsp_z.sh &
echo "Run mars request for data on 2pv..."
date 
. $BINDIR/download_ecmwf_pv.sh &
echo "Run mars request for data ml T/Q..."
date 
. $BINDIR/download_ecmwf_ml_tq.sh &
echo "Run mars request for data ml u..."
date 
. $BINDIR/download_ecmwf_ml_u.sh &
echo "Run mars request for data ml v..."
date 
. $BINDIR/download_ecmwf_ml_v.sh &
echo "Run mars request for data sfc..."
date 
. $BINDIR/download_ecmwf_sfc.sh &

# Retrieve ml additional parameters

if [[ x$MODEL_PARAMETERS1 != x"" ]]; then
   echo "Run mars request for data ml parameters 1..."
   date 
   . $BINDIR/download_ecmwf_ml_para1.sh &
fi
if [[ x$MODEL_PARAMETERS2 != x"" ]]; then
   echo "Run mars request for data ml parameters 2..."
   date 
   . $BINDIR/download_ecmwf_ml_para2.sh &
fi
if [[ x$MODEL_PARAMETERS3 != x"" ]]; then
   echo "Run mars request for data ml parameters 3..."
   date 
   . $BINDIR/download_ecmwf_ml_para3.sh &
fi
if [[ x$MODEL_PARAMETERS4 != x"" ]]; then
   echo "Run mars request for data ml parameters 4..."
   date 
   . $BINDIR/download_ecmwf_ml_para4.sh &
fi
if [[ x$MODEL_PARAMETERS5 != x"" ]]; then
   echo "Run mars request for data ml parameters 5..."
   date 
   . $BINDIR/download_ecmwf_ml_para5.sh &
fi


# Convert grib to netCDF, set init time
wait
echo "Run convert.sh"
. $BINDIR/convert.sh

if ecaccess-association-list | grep -q $ECTRANS_ID; then
  echo "Transfering files to "$ECTRANS_ID 
  ectrans -remote $ECTRANS_ID -source $mlfile_uv -target $mlfile_uv -overwrite -remove 
  if [ -f $sfcfile_ancillary ]; then
      ectrans -remote $ECTRANS_ID -source $sfcfile_ancillary -target $sfcfile_ancillary -overwrite -remove 
  fi
  if [ -f $tlfile ]; then
      ectrans -remote $ECTRANS_ID -source $tlfile -target $tlfile -overwrite -remove 
  fi
  if [ -f $plfile ] && [ x$PRES_FROM_MARS != x"yes" ]; then
      ectrans -remote $ECTRANS_ID -source $plfile -target $plfile -overwrite -remove 
  fi
  if [ -f $alfile ]; then
      ectrans -remote $ECTRANS_ID -source $alfile -target $alfile -overwrite -remove 
  fi
fi
#---------------------comet meteograms----------------
if [[ x$COMET_MET == x"yes" ]]
then
  echo "Run extract_comet_ncks.sh"
  . $MAINDIR/extract_comet_ncks.sh
  sleep 4m
  fpath="/home/ms/spdescan/ddp/scratch/mss_wms/files_for_mss/mss/sites"
  ppath="/home/ms/spdescan/ddp/mss_wms/data_retrieval_for_ipa_mss_wms_comet2"
  a="$(find ${fpath} -name "*144.sfc.nc" | head -1)"
  date
  echo Run plot_comet_sfc.py 
  python3.8 $ppath/plot_comet_sfc.py
  #for init date
  initdate=$(awk -F'LL025.|.144' '{print $2}' <<< "$a")
  initdate=${initdate/T/}'00'
  echo Initdate ${initdate} 
  chmod a+r $fpath/*.png
  scp -p $fpath/*.png gisi_so@lx001.pa.op.dlr.de:websites/missionsupport/classic/forecasts/forecasts2/${initdate}/
  mv $fpath/*.png $fpath/files_plotted/
  rm $fpath/*.nc
fi

if [[ x$CLEANUP == x"yes" ]]
then
  # clean up locally
  for f in $mlfile $tlfile $plfile $pvfile $alfile $sfcfile $sfcfile_ancillary $mlfile_u $mlfile_v $mlfile_uv mss/${BASE}.tmp_z mss/${BASE}.tmp grib/${BASE}*.grib;
  do
      if [ -f $f ];
      then
          rm $f
      fi
  done
fi
