#!/bin/sh
#
#  dump table to csv
#

database=ibreathedb
username=ibhro
passwd=user4iBH

year=2011

if [ $# -ge 1 ]; then
  year=$1
fi

table=ibh_data_year_${year}

inst_list="o3,o3_flag,windspd,windspd_flag,winddir,winddir_flag"

#date_string=`date +%Y%m%d_%H%M%S`


echo "# year = ${year}"

# get data

echo "select epoch,siteID,${inst_list} from ${table} order by epoch,siteID;"
echo "select epoch,siteID,${inst_list} from ${table} order by epoch,siteID;" | mysql -u $username --password=$passwd $database | sed -e 's/\\n/\\r/g' > ${database}.${table}.dump.csv

