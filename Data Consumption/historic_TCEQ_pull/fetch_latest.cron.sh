#!/bin/bash
#
# fetch TCEQ latest data via cron job
#

config_file=/home/tihuang/TCEQ/openconnect.conf
top_dir=/virt/TCEQ

source $config_file

with_network=0

echo "### date: `date +%Y-%m-%d.%H_%M_%S`"

echo "# debug: checking network ..."

for n in $NETWORKS; do
  echo "# debug: checking '$n' ..."
  if /bin/netstat -nr | grep $n; then
    with_network=1
  fi
done

if [ ! $with_network -eq 1 ]; then
  #echo "# Error: network not available.  Program terminated."
  #exit 1

  echo "# Warning: network not available.  Reconnect to TCEQ."
  #sudo /home/tihuang/TCEQ/openconnect.init.sh stop
  #su --session-command="/home/tihuang/TCEQ/openconnect.init.sh stop"
  #su - -c "/home/tihuang/TCEQ/openconnect.init.sh start"
  sudo /home/tihuang/TCEQ/openconnect.init.sh start
  
  echo "# debug: checking network ..."

  with_network2=0

  for n in $NETWORKS; do
    echo "# debug: checking '$n' ..."
    if /bin/netstat -nr | grep $n; then
      with_network2=1
    fi
  done
  
  if [ ! $with_network2 -eq 1 ]; then
    echo "# Error: network not available.  Program terminated."
    exit 1
  fi
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

echo "## starting epoch: $epoch_now" > $target_dir/$outfile

#echo "elinks -source 0 \"http://163.234.120.84/cgi-bin/quick_look.pl?param=44201&view_hours=2&&ordinal=1&region_crit=12&include_CAMS=1&include_TAMS=1&include_HOUSTON=1&include_HARRIS_CNTY=1&include_HRM=1&include_EISM=1\" >> $target_dir/$outfile"
#
#elinks -source 0 "http://163.234.120.84/cgi-bin/quick_look.pl?param=44201&view_hours=2&&ordinal=1&region_crit=12&include_CAMS=1&include_TAMS=1&include_HOUSTON=1&include_HARRIS_CNTY=1&include_HRM=1&include_EISM=1" >> $target_dir/$outfile

echo "elinks -source 0 \"http://rhone3.tceq.texas.gov/cgi-bin/quick_look.pl?param=44201&view_hours=2&local=&_GMT=&ordinal=1&region_crit=12&include_type=CAMS&include_type=TAMS&include_type=UT&include_type=VICTORIA&include_type=WATER&include_type=DALLAS&include_type=FTWORTH&include_type=HOUSTON&include_type=HARRIS_CNTY&include_type=ELPASO&include_type=SETRPC&include_type=HRM&include_type=CPS&include_type=LCRA&include_type=ACOG&include_type=ASOS&include_type=CAPCOG&include_type=MEXICO&include_type=EISM&include_type=COCP&include_type=PRIVATE_INDUSTRY&include_type=PRIVATE_OTHER\" >> $target_dir/$outfile"

elinks -source 0 "http://rhone3.tceq.texas.gov/cgi-bin/quick_look.pl?param=44201&view_hours=2&local=&_GMT=&ordinal=1&region_crit=12&include_type=CAMS&include_type=TAMS&include_type=UT&include_type=VICTORIA&include_type=WATER&include_type=DALLAS&include_type=FTWORTH&include_type=HOUSTON&include_type=HARRIS_CNTY&include_type=ELPASO&include_type=SETRPC&include_type=HRM&include_type=CPS&include_type=LCRA&include_type=ACOG&include_type=ASOS&include_type=CAPCOG&include_type=MEXICO&include_type=EISM&include_type=COCP&include_type=PRIVATE_INDUSTRY&include_type=PRIVATE_OTHER" >> $target_dir/$outfile

ending_epoch=`date +%s`
time_spent=$((ending_epoch-epoch_now))

echo "## ending epoch: $ending_epoch" >> $target_dir/$outfile
echo "## time spent: $time_spent sec" >> $target_dir/$outfile
