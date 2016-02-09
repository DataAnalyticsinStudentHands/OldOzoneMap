#!/bin/bash
#
# fetch TCEQ ozone data via quick_look script
#
#     fetch_quick_look.sh [Ndays] [start_date]
#
#  Last modify: 2012/07/20
#
#  http://rhone3.tceq.texas.gov/cgi-bin/quick_look.pl?param=44201&view_hours=2&local=&_GMT=&region_crit=12&include_type=CAMS&include_type=TAMS&include_type=UT&include_type=WATER&include_type=HOUSTON&include_type=HARRIS_CNTY&include_type=SETRPC&include_type=HRM&include_type=CPS&include_type=LCRA&include_type=ACOG&include_type=ASOS&include_type=CAPCOG&include_type=MEXICO&include_type=EISM&include_type=COCP&include_type=PRIVATE_INDUSTRY&include_type=PRIVATE_OTHER&include_type=ASSY&include_type=MOBILE&include_type=TEST
#

skip_openconnect=no

config_file=/mnt/ibreathe/TCEQ/scripts/openconnect.conf
openconnect_script=/mnt/ibreathe/TCEQ/scripts/openconnect.init.sh
top_dir=/mnt/ibreathe/TCEQ/quick_look

debug=no

sleep_sec=1

#
# last N hours
#

nHours=6

# take first argument as nHours
if [ $# -ge 1 ]; then
  nHours=$1
  if [[ `echo ${nHours} | sed 's/^[-+0-9][0-9]*//' | wc -c` -ne 1 ]]; then
    echo "# Error: argument '$Ndays' is not a number"
    exit 1
  elif (( $nHours >= 1 )); then
    [[ "$debug" == "yes" ]] && echo "# debug: nHours = '$nHours'"
  fi
fi

  epoch_now=`date +%s`
  #str_y=`TZ=America/Regina date +%Y -d @${epoch_now}`
  #str_ym=`TZ=America/Regina date +%Y-%m -d @${epoch_now}`
  #str_ymd=`TZ=America/Regina date +%Y-%m-%d -d @${epoch_now}`
  str_ymd_hms=`TZ=America/Regina date +%Y-%m-%d.%H%M%S -d @${epoch_now}`

  [[ "$debug" == "yes" ]] && echo "epoch_now = ${str_ymd_hms} (${epoch_now}) for ${nHours} hours"


#--------------

if [[ "$skip_openconnect" != "yes" ]]; then

  source $config_file

  with_network=0

  #[[ "$debug" == "yes" ]] && echo "### date: `date +%Y-%m-%d.%H_%M_%S`"
  #[[ "$debug" == "yes" ]] && echo "# debug: checking network ..."

  for n in $NETWORKS; do
    [[ "$debug" == "yes" ]] && echo "# debug: checking '$n' ..."
    if /bin/netstat -nr | grep $n; then
      with_network=1
    fi
  done

  if [ ! $with_network -eq 1 ]; then
    #echo "# Error: network not available.  Program terminated."
    #exit 1

    [[ "$debug" == "yes" ]] && echo "# Warning: network not available.  Reconnect to TCEQ."
    sudo ${openconnect_script} start
  
    #[[ "$debug" == "yes" ]] && echo "# debug: checking network ..."

    with_network2=0

    for n in $NETWORKS; do
      [[ "$debug" == "yes" ]] && echo "# debug: checking '$n' ..."
      if /bin/netstat -nr | grep $n; then
        with_network2=1
      fi
    done
  
    if [ ! $with_network2 -eq 1 ]; then
      [[ "$debug" == "yes" ]] && echo "# Error: network not available.  Program terminated."
      exit 1
    fi
  fi

fi ## skip_openconnect

#
# start download data
#

#	"o3 44201" \
#	"windsp 61103" \
#	"winddir 61104" \

for v in  \
	"temp 62101" \
	"humid 62201" \
	"pm25 88502" \
	"solar 63301" \

do
  set -- $v
  inst=$1
  inst_id=$2

  URL_region="local=&_GMT=&region_crit=12&include_type=CAMS&include_type=TAMS&include_type=UT&include_type=WATER&include_type=HOUSTON&include_type=HARRIS_CNTY&include_type=SETRPC&include_type=HRM&include_type=CPS&include_type=LCRA&include_type=ACOG&include_type=ASOS&include_type=CAPCOG&include_type=MEXICO&include_type=EISM&include_type=COCP&include_type=PRIVATE_INDUSTRY&include_type=PRIVATE_OTHER&include_type=ASSY&include_type=MOBILE&include_type=TEST"

  epoch_now_nanosec=`date +%s.%N`
  epoch_now=${epoch_now_nanosec%.*}
  str_y=`TZ=America/Regina date +%Y -d @${epoch_now}`
  str_ym=`TZ=America/Regina date +%Y-%m -d @${epoch_now}`
  str_ymd=`TZ=America/Regina date +%Y-%m-%d -d @${epoch_now}`
  str_ymd_hms=`TZ=America/Regina date +%Y-%m-%d.%H%M%S -d @${epoch_now}`

  target_dir=${top_dir}/${str_y}/${str_ym}/${str_ymd}
  [[ "$debug" == "yes" ]] && echo "# debug: target_dir = $target_dir"
  if [ ! -e $target_dir ]; then
    [[ "$debug" == "yes" ]] && echo "# debug: mkdir -p $target_dir"
    mkdir -p $target_dir
  fi

  outfile=${inst}.${str_ymd_hms}.${nHours}h.${epoch_now}.txt
  [[ "$debug" == "yes" ]] && echo "# debug: outfile = $outfile"


  echo "## starting epoch: $epoch_now" > $target_dir/$outfile

  echo "elinks -source 0  \"http://rhone3.tceq.texas.gov/cgi-bin/quick_look.pl?param=${inst_id}&view_hours=${nHours}&....\"  >> $target_dir/$outfile"
  elinks -source 0  "http://rhone3.tceq.texas.gov/cgi-bin/quick_look.pl?param=${inst_id}&view_hours=${nHours}&${URL_region}"  >> $target_dir/$outfile

  ending_epoch_nanosec=`date +%s.%N`
  time_spent=$(echo "${ending_epoch_nanosec} - ${epoch_now_nanosec}" | bc -l)

  echo "## ending epoch: $ending_epoch_nanosec" >> $target_dir/$outfile
  echo "## time spent: $time_spent sec" >> $target_dir/$outfile

  [[ "$debug" == "yes" ]] && echo "##"
  sleep ${sleep_sec}
  [[ "$debug" == "yes" ]] && echo ""
done

