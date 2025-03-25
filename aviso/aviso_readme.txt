Use of aviso to trigger job scripts on the European Weather Cloud (EWC)
=======================================================================


* The aviso service runs automatically on EWC machines with the data setup
  It can be activated and deactivated by the command
    sudo systemctl start aviso.service
    sudo systemctl stop aviso.service
  The status can be viewd be
    sudo systemctl status aviso.service

* For test purposes it my be used to test the behaviour on past trigger
  events for a given (past) time range. This can be done by the listen
  command within an env, where aviso is installed, like
    sudo systemctl stop aviso.service
    mamba activate avisoenv
    aviso listen --from 2025-03-05T00:00:00.0Z --to 2025-03-05T08:00:00.0Z
  
* The file config.yaml in the direactory $HOME/.aviso guides the triggering

* if multiple steps are given in a trigger command, like
   step: [36,72,144]
  the programs called by the trigger are executed sequentially, possibly
  not in the time order of the triggers

* the script get_ecmwf_aviso.sh creates ECMWF grib files and converts
  them to MSS-convorm NetCDF files. One can speed up the process by
  parallel download the grib files using "DOWNLOAD_ONLY=yes" in the file
  settings.config and starting convert_all.sh separately.
