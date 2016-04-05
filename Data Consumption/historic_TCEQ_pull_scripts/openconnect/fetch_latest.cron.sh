#!/bin/bash
#
# fetch TCEQ latest data via cron job
#

config_file=/root/openconnect/openconnect.conf
top_dir=/tmp

source $config_file

with_network=0

echo "# debug: checking network ..."

for n in $NETWORKS; do
  echo "# debug: checking '$n' ..."
  if /bin/netstat -nr | grep $n; then
    with_network=1
  fi
done

if [ ! $with_network -eq 1 ]; then
  echo "# Error: network not available.  Program terminated."
  exit 1
fi

epoch_now=`date +%s`
str_y=`TZ=America/Regina date +%Y -d @${epoch_now}`
str_ym=`TZ=America/Regina date +%Y-%m -d @${epoch_now}`
str_ymd=`TZ=America/Regina date +%Y-%m-%d -d @${epoch_now}`
str_ymd_hms=`TZ=America/Regina date +%Y-%m-%d.%H_%M_%S -d @${epoch_now}`

target_dir=$top_dir/$str_y/$str_ym/$str_ymd
outfile=O3.$str_ymd_hms.txt

echo "target_dir = $target_dir"
echo "outfile = $outfile"

if [ ! -e $target_dir ]; then
  mkdir -p $target_dir
fi

echo "elinks -source 0 \"http://163.234.120.84/cgi-bin/quick_look.pl?param=44201&view_hours=2&&ordinal=1&region_crit=12&include_CAMS=1&include_TAMS=1&include_HOUSTON=1&include_HARRIS_CNTY=1&include_HRM=1&include_EISM=1\" > $target_dir/$outfile"

elinks -source 0 "http://163.234.120.84/cgi-bin/quick_look.pl?param=44201&view_hours=2&&ordinal=1&region_crit=12&include_CAMS=1&include_TAMS=1&include_HOUSTON=1&include_HARRIS_CNTY=1&include_HRM=1&include_EISM=1" > $target_dir/$outfile
