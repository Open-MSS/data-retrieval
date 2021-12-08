mss-data-retrieval
==================
Scripts to get and process data for MSS on ecGates

ECTrans Setup
=============
1. Login at https://ecaccess.ecmwf.int/ecmwf/ \
   Go to https://ecaccess.ecmwf.int/ecmwf/gateway/ECtrans/Setup
2. Click "Add association" at the bottom of the page \
   Call the association "MSS-Data-Transfer" and set up your SFTP/FTP Server to your liking

Scripts Setup
=============
1. Clone this repository and move into it

       git clone https://github.com/Open-MSS/data-retrieval.git
       cd data-retrieval
       git checkout ecgate-forecast

2. Make the shell scripts executable

       chmod +x ./bin/*.sh
       
3. Create a .bashrc for paths

       cat .bashrc > ~/.bashrc
       source ~/.bashrc

4. Install all requirements

       pip3 install --user -r requirements.txt

Usage
=====
After completing both setups, you can use this script as follows:

    ./bin/get_data.sh <date> <time> <step>

Where \<date\> and \<time\> is the date and time where the forecast was created, and \<step\> is how many hours after the date and time you want your data.\
For example, to get a forecast created at 22nd of April 2021 at 0 o'clock, for 23rd and 24th of April at 0 o'clock, use

    ./bin/get_data.sh 2021-04-22 00:00:00 24/48
    
