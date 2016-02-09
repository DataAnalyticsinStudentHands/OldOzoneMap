#!/bin/bash
#
# fetch TCEQ daily data via data_extractor script
#
#    fetch_data_extractor.daily.o3.sh [Ndays] [start_date]
#
# Last modify: 2011/10/28
#

skip_openconnect=no

config_file=/mnt/ibreathe/TCEQ/scripts/openconnect.conf
openconnect_script=/mnt/ibreathe/TCEQ/scripts/openconnect.init.sh
top_dir=/mnt/ibreathe/TCEQ/data_extractor/daily

debug=yes

sleep_sec=1

#
# last N days from current date (GMT) 
#

Ndays=2

# take first argument as Ndays
if [ $# -ge 1 ]; then
  Ndays=$1
  if [[ `echo ${Ndays} | sed 's/^[-+0-9][0-9]*//' | wc -c` -ne 1 ]]; then
    echo "# Error: argument '$Ndays' is not a number"
    exit 1
  elif (( $Ndays >= 1 )); then
    [[ "$debug" == "yes" ]] && echo "# debug: Ndays = '$Ndays'"
  fi
fi

# take second argument as start date
if [ $# -eq 2 ]; then
  start_date=$2
  start_date=`TZ=UTC date +%Y-%m-%d -d "$start_date"`
  epoch_start=`TZ=UTC date +%s -d "$start_date"`
  epoch_end=$((epoch_start+${Ndays}*24*60*60+1))
  end_date=`TZ=UTC date +%Y-%m-%d -d @${epoch_end}`

  epoch_now=`date +%s`
  date_now_str=`TZ=UTC date +%Y-%m-%d.%H%M%S -d @${epoch_now}`
else
  epoch_now=`date +%s`
  ##epoch_now=`date +%s -d "37 days ago"`

  end_date=`TZ=UTC date +%Y-%m-%d -d @${epoch_now}`
  #epoch_end=`TZ=UTC date +%s -d "${end_date}"`
  epoch_end=`TZ=UTC date +%s -d "${end_date} 23:59:59"`
  epoch_start=$((epoch_end-${Ndays}*24*60*60+1))
  start_date=`TZ=UTC date +%Y-%m-%d -d @${epoch_start}`

  # fix end date
  epoch_end=$((epoch_end+2))
  end_date=`TZ=UTC date +%Y-%m-%d -d @${epoch_end}`

  date_now_str=`TZ=UTC date +%Y-%m-%d.%H%M%S -d @${epoch_now}`
fi


[[ "$debug" == "yes" ]] && echo "start_date = ${start_date} (epoch_start = ${epoch_start})  +  ${Ndays} days  =  end_date = ${end_date} (epoch_end = ${epoch_end})"

start_year=${start_date:0:4}
start_month=${start_date:5:2}
start_day=${start_date:8:2}

start_month_no=${start_month#0}
start_month_no=$((start_month_no-1))
start_day_no=${start_day#0}

end_year=${end_date:0:4}
end_month=${end_date:5:2}
end_day=${end_date:8:2}

end_month_no=${end_month#0}
end_month_no=$((end_month_no-1))
end_day_no=${end_day#0}

#[[ "$debug" == "yes" ]] && echo "## debug: check (${date_now_str} GMT)  start_date = ${start_year}/${start_month}/${start_day} ;  end_date = ${end_year}/${end_month}/${end_day}"
##[[ "$debug" == "yes" ]] && echo "## check (${date_now_str} GMT)  start_date_no = ${start_year}/${start_month_no}/${start_day_no} ;  end_date = ${end_year}/${end_month_no}/${end_day_no}"
echo "# processing: ${date_now_str} GMT : start_date = ${start_year}/${start_month}/${start_day} ;  end_date = ${end_year}/${end_month}/${end_day}"

#exit


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

target_dir=${top_dir}/${start_year}/${start_year}-${start_month}/${start_date}

[[ "$debug" == "yes" ]] && echo "# debug: target_dir = $target_dir"

if [ ! -e $target_dir ]; then
  [[ "$debug" == "yes" ]] && echo "# debug: mkdir -p $target_dir"
  mkdir -p $target_dir
fi

#	"temp 62101" \
#	"humid 62201" \
#	"pm25 88502" \
#	"solar 63301" \

for v in  \
	"o3 44201" \
	"windsp 61103" \
	"winddir 61104" \

do
  set -- $v
  inst=$1
  inst_id=$2

  URL_date="start_month=${start_month_no}&start_year=${start_year}&quarter=1&quarter_year=${start_year}&single_year=${start_year}&select_date=r&start_month1=${start_month_no}&start_day1=${start_day_no}&start_year1=${start_year}&end_month1=${end_month_no}&end_day1=${end_day_no}&end_year1=${end_year}&start_year2=${start_year}&end_year2=${start_year}"
  URL_inst="source=z&zeno_param=${inst_id}&agc_param=45201&database=5m"
  URL_output="output_device=w&output_file=none&overwrite=u&email_address=none&create_config=c&config_file=none&config_overwrite=u&existing_config_file=1.cfg&select_format=g"
  URL_region="select_location=r&reg_crit=12&include_type=CAMS&include_type=TAMS&include_type=UT&include_type=VICTORIA&include_type=WATER&include_type=DALLAS&include_type=FTWORTH&include_type=HOUSTON&include_type=HARRIS_CNTY&include_type=ELPASO&include_type=SETRPC&include_type=HRM&include_type=CPS&include_type=LCRA&include_type=ACOG&include_type=ASOS&include_type=CAPCOG&include_type=MEXICO&include_type=EISM&include_type=COCP&include_type=PRIVATE_INDUSTRY&include_type=PRIVATE_OTHER&include_type=ASSY&include_type=MOBILE&include_type=TEST"
  URL_format="time=u&decimals=5&truncate=t&date_format=s5&time_format=24h&data_flag=t&co_units=b&agc_units=v&water_interval=15&delimiter=c&spaces=8&align=r&sort_order=c&site_id=c&param_id=e"

  epoch_now=`date +%s`
  date_now_str=`TZ=UTC date +%Y-%m-%d.%H%M%S -d @${epoch_now}`
  #outfile=${inst}.${date_now_str}.${Ndays}d.${epoch_now}.txt
  outfile=${inst}.${start_date}.${Ndays}d.${epoch_now}.txt
  [[ "$debug" == "yes" ]] && echo "# debug: outfile = $outfile"

  #exit

  echo "## starting epoch: $epoch_now" > $target_dir/$outfile

  ##echo "elinks -source 0  \"http://rhone3.tceq.state.tx.us/cgi-bin/data_extract.pl?${URL_date}&${URL_inst}&${URL_output}&${URL_region}&${URL_format}\"  >> $target_dir/$outfile"
  echo "elinks -source 0  \"http://rhone3.tceq.state.tx.us/cgi-bin/data_extract.pl?${URL_date}&${URL_inst}&....\"  >> $target_dir/$outfile"
  elinks -source 0  "http://rhone3.tceq.state.tx.us/cgi-bin/data_extract.pl?${URL_date}&${URL_inst}&${URL_output}&${URL_region}&${URL_format}"  >> $target_dir/$outfile

  ending_epoch=`date +%s`
  time_spent=$((ending_epoch-epoch_now))

  echo "## ending epoch: $ending_epoch" >> $target_dir/$outfile
  echo "## time spent: $time_spent sec" >> $target_dir/$outfile

  [[ "$debug" == "yes" ]] && echo "##"
  sleep ${sleep_sec}
  [[ "$debug" == "yes" ]] && echo ""
done

