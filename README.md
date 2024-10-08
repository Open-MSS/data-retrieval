mss-data-retrieval
====================
Scripts to get and process ERA5 and ECMWF data for MSS on Linux


CDS-API
=======

Setup
-----

1. Create an account at https://cds.climate.copernicus.eu/user/register \
   Log into your account
2. Navigate to https://cds.climate.copernicus.eu/api-how-to#install-the-cds-api-key \
   Copy the content of the upper black box to the right and paste it into `~/.cdsapirc`
3. Accept https://cds.climate.copernicus.eu/cdsapp/#!/terms/licence-to-use-copernicus-products


Scripts Setup
-------------

1. Clone this repository and change into it

       git clone https://github.com/Open-MSS/data-retrieval.git
       cd data-retrieval

2. Create an environment and install all requirements

       pip install -r requirements.txt

3. Make sure cdo and nco are installed\
   e.g. for Ubuntu/Debian

       sudo apt-get install cdo nco netcdf-bin

4. Adjust the settings.config to your liking (copy from settings.example)


Usage
-----

1. After completing both setups, you can use this script as follows:

       ./bin/get_cds.sh <date> <time>

   For example, to get ERA5 data for March 2nd 2020 at 12 o'clock, use

       ./bin/get_cds.sh 2020-03-02 12:00:00

2. Done, copy the .nc files to your mss data directory and give them their appropriate suffix.\
   Using the demodata for MSS, this is ~/mss/testdata and EUR\_LL015 suffix.

       for file in ./mss/*.nc; do mv "$file" "${file/.nc/.EUR_LL015.nc}"; done
       mv ./mss/*.nc ~/mss/testdata
