#!/bin/bash
#
# fetch TCEQ latest data via cron job
#

skip_openconnect=yes

config_file=/mnt/ibreathe/TCEQ/scripts/TCEQ/openconnect.conf
openconnect_script=/mnt/ibreathe/TCEQ/scripts/openconnect.init.sh

##top_dir=/virt/TCEQ/data_extractor/monthly
top_dir=/mnt/ibreathe/TCEQ/data_extractor/monthly

sleep_sec=30


if [[ "$skip_openconnect" != "yes" ]]; then

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
  sudo ${openconnect_script} start
  
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

fi ## skip_openconnect

#
# start download data
#

#for y in "2011"
for y in "2012"
do

  str_y=${y}
  ## month: start from 1 to 12
  ##starting_month=1
  ##ending_month=12
  starting_month=9
  ending_month=9
  
  target_dir=$top_dir/$str_y
  echo "target_dir = $target_dir"

  if [ ! -e $target_dir ]; then
    mkdir -p $target_dir
  fi

  ## 
  #for mon in `seq ${starting_month} ${ending_month}`
  for (( mon=${ending_month}; mon >= ${starting_month}; mon--))
  do
    mon_str=`printf "%02d" $mon`
    m=$((mon-1))
    str_ym="${str_y}-${mon_str}"
    ##echo $str_ym

    for v in  \
	"o3 44201" \
	"temp 62101" \
	"windspd 61103" \
	"winddir 61104" \
	"humid 62201" \
	"pm25 88502" \
	"solar 63301" \

    do
      set -- $v
      inst=$1
      inst_id=$2

      URL_date="select_date=m&start_month=${m}&start_year=${y}&quarter=1&quarter_year=${y}&single_year=${y}&start_month1=0&start_day1=1&start_year1=${y}&end_month1=7&end_day1=31&end_year1=${y}&start_year2=${y}&end_year2=${y}"
      URL_inst="source=z&zeno_param=${inst_id}&agc_param=45201&database=5m"
      URL_output="output_device=w&output_file=none&overwrite=u&email_address=none&create_config=c&config_file=none&config_overwrite=u&existing_config_file=1.cfg&select_format=g"
      URL_region="select_location=r&reg_crit=12&include_type=CAMS&include_type=TAMS&include_type=UT&include_type=VICTORIA&include_type=WATER&include_type=DALLAS&include_type=FTWORTH&include_type=HOUSTON&include_type=HARRIS_CNTY&include_type=ELPASO&include_type=SETRPC&include_type=HRM&include_type=CPS&include_type=LCRA&include_type=ACOG&include_type=ASOS&include_type=CAPCOG&include_type=MEXICO&include_type=EISM&include_type=COCP&include_type=PRIVATE_INDUSTRY&include_type=PRIVATE_OTHER&include_type=ASSY&include_type=MOBILE&include_type=TEST"
      URL_format="time=u&decimals=5&truncate=t&date_format=s5&time_format=24h&data_flag=t&co_units=b&agc_units=v&water_interval=15&delimiter=c&spaces=8&align=r&sort_order=c&site_id=c&param_id=e"

      epoch_now=`date +%s`
      outfile=${inst}.${str_ym}.${epoch_now}.txt
      echo "outfile = $outfile"
      echo "## starting epoch: $epoch_now" > $target_dir/$outfile

      echo "elinks -source 0  \"http://rhone3.tceq.state.tx.us/cgi-bin/data_extract.pl?${URL_date}&${URL_inst}&${URL_output}&${URL_region}&${URL_format}\"  >> $target_dir/$outfile"
      elinks -source 0  "http://rhone3.tceq.state.tx.us/cgi-bin/data_extract.pl?${URL_date}&${URL_inst}&${URL_output}&${URL_region}&${URL_format}"  >> $target_dir/$outfile

      ending_epoch=`date +%s`
      time_spent=$((ending_epoch-epoch_now))

      echo "## ending epoch: $ending_epoch" >> $target_dir/$outfile
      echo "## time spent: $time_spent sec" >> $target_dir/$outfile

      echo "##"
      sleep ${sleep_sec}
      echo ""
    done
  done
done

