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
1. Clone this repository and move into it

       git clone https://github.com/Open-MSS/data-retrieval.git
       cd data-retrieval

2. Make the shell scripts executable

       chmod +x ./bin/*.sh

3. Install all requirements

       pip -r install requirements.txt

4. Make sure cdo and nco are installed\
   e.g. for Ubuntu/Debian

       sudo apt-get install cdo nco netcdf-bin

5. Adjust the settings.config to your liking

Usage
-----
1. After completing both setups, you can use this script as follows:

       ./bin/get_cds.sh <date> <time>

   For example, to get ERA5 data for March 2nd 2020 at 12 o'clock, use

       ./bin/get_cds.sh 2020-03-02 12:00:00

2. Done, copy the .nc files to your mss data directory and give them their appropriate suffix.\
   Using the demodata for MSS, this is ~/mss/testdata and EUR_LL015 suffix.

       for file in ./mss/*.nc; do mv "$file" "${file/.nc/.EUR_LL015.nc}"; done
       mv ./mss/*.nc ~/mss/testdata


ECMWF forecast
==============

ECTrans Setup
-------------
1. Login at https://ecaccess.ecmwf.int/ecmwf/ \
   Go to https://ecaccess.ecmwf.int/ecmwf/gateway/ECtrans/Setup
2. Click "Add association" at the bottom of the page \
   Call the association "MSS-Data-Transfer" and set up your SFTP/FTP Server to your liking \
   If you want to call it something else, make sure to change `ectrans_id` inside the `settings.config`

Scripts Setup
-------------
1. Clone this repository and move into it

       git clone https://github.com/Open-MSS/data-retrieval.git
       cd data-retrieval
       git checkout ecgate-forecast

2. Make the shell scripts executable

       chmod +x ./bin/*.sh

3. Create a .bashrc for setting up paths asn tools

       cat bashrc_ecmwf >> ~/.bashrc
       source ~/.bashrc

4. Install all requirements

       pip3 install --user -r requirements.txt

5. Adjust the settings.config to your liking

Usage
-----
After completing both setups, you can use this script as follows:

    ./bin/get_ecmwf.sh <date> <time> <step>

Where \<date\> and \<time\> is the date and time where the forecast was created, and \<step\> is how many hours after the date and time you want your data.\
For example, to get a forecast created at 22nd of April 2021 at 0 o'clock, for 23rd and 24th of April at 0 o'clock, use

    ./bin/get_ecmwf.sh 2021-04-22 00:00:00 24/48

