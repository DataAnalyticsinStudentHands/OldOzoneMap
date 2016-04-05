#!/bin/bash
#
# insert daily TCEQ data into database
#
# Last modify: 2011/10/28
#

# top data directory
top_dir=/mnt/ibreathe/TCEQ/data_extractor/daily

# data insertion script
push_script=/mnt/ibreathe/TCEQ/scripts/push_ibh_data3.pl

# search number of days from today
Ndays=3

# debugging flag: set yes (on) or no (off)
debug=no

# steate file top dir
state_top_dir=/mnt/ibreathe/TCEQ/state

#-----------------------------------
## for checking run status
run_file=/mnt/ibreathe/TCEQ/state/insert_daily_data.sh.run

# threshold in seconds
threshold_run=1800

#
# check run status file
#
function check_runfile {
  my_run_file=$1
  my_threshold_value=$2
  if [ -e $my_run_file ]; then
    fdate=$(stat -c %Y $my_run_file)
    now=`date +%s`
    my_threshold=$(($now - $my_threshold_value))
    ##echo "# debug: fdate($my_run_file)=$fdate now=$now threshold=$my_threshold threshold_value=$my_threshold_value"
    if [ $fdate -gt $my_threshold ]; then
      ##echo "# debug: program still running"
      return 0
    else
      echo "# debug: run file '$my_run_file' is too old -- restart at `date +%Y/%m/%d.%H:%M:%S`"
      touch $my_run_file
    fi
  else
    touch $my_run_file
  fi
  return 10
}

check_runfile $run_file $threshold_run
return_val=$?
return_val=2
if [ $return_val -lt 1 ]; then
  echo "# debug: program still running -- exit at `date +%Y/%m/%d.%H:%M:%S`"
  exit
fi

#
# end of run status check
#
#-------------------------------

echo "# insertion started: `date +%Y/%m/%d.%H:%M:%S`"

# scanning through directories
for ((d=${Ndays}; d>=0; d--))
do
  # set date
  mydate=`TZ=UTC date +"%Y/%Y-%m/%Y-%m-%d" -d "${d} days ago"`
  [[ "$debug" == "yes" ]] && echo "mydate [$d] = '$mydate'"

  state_fname="${state_top_dir}/${mydate:0:12}/ibh_state.${mydate:13:11}.txt"
  echo "## state_fname = '$state_fname'"
  if [ -e ${state_fname} ]; then
    state_list=`awk -F, '{print $1}' ${state_fname} | sort | uniq | sed 's/\r/ /'`
    #echo "# state_list = '$state_list'"
  fi

  if [ -d ${top_dir}/${mydate} ]; then
    #[[ "$debug" == "yes" ]] && echo "find ${top_dir}/${mydate} -type f -mtime -${Ndays} -print | sort -t. -n -k 4,4"
    tmp_list=`find ${top_dir}/${mydate} -type f -mtime -${Ndays} -print | sort -t. -n -k 4,4`
    if [ -n "${tmp_list}" ]; then
      [[ "$debug" == "yes" ]] && echo "# debug: tmp_list = '$tmp_list'"
      ##mylist=`echo ${tmp_list} | sed 's/\r/ /'`

      mylist=''
      for f in $tmp_list; do
	fname=${f##*/}
        fname=${fname%.gz}
        #fdate=`echo ${fname} | awk -F. '{print $2}'`
        #fdate_y=${fdate:0:4}
        #fdate_ym=${fdate:0:7}
        #state_file=${state_top_dir}/${fdate_y}/${fdate_ym}/ibh_state.${fdate}.txt
        #[[ "$debug" == "yes" ]] && echo "## f = '$f'   ==>   fname = '$fname'  +  fdate = '$fdate'"

	if [ -n "${state_list}" ]; then
	  if [[ "${state_list}" =~ "${fname}" ]]; then
	    #[[ "$debug" == "yes" ]] && echo "###     '${fname}' found in '${state_fname}'"
	    echo "###     '${fname}' found in '${state_fname}'"
	  else
	    #[[ "$debug" == "yes" ]] && echo "###     '${fname}' not found in '${state_fname}'"
	    echo "###     '${fname}' not found in '${state_fname}'"
	    mylist="${mylist} ${f}"
	  fi
	else
	  echo "##  state_list is zero length"
	  mylist="${mylist} ${f}"
	fi
        echo "# mylist = '$mylist'"

#	if [ -e ${state_fname} ]; then
#	  #echo "###    state file '${state_fname}' found"
#	  if grep -q "${fname}" ${state_fname}
#	  then
#	    [[ "$debug" == "yes" ]] && echo "###     '${fname}' found in '${state_fname}"
#	  else
#	    [[ "$debug" == "yes" ]] && echo "###     '${fname}' not found in '${state_fname}"
#	    mylist="${mylist} ${f}"
#	  fi
#	fi

      done
      echo "# mylist = '$mylist'"

      #[[ "$debug" == "yes" ]] && echo "# executing: 'perl ${push_script} -d ${mylist}'"
      [[ "$debug" == "yes" ]] && echo "# executing: 'perl ${push_script} -d ${mylist}'" | sed 's/\/mnt\/ibreathe\/TCEQ\/data_extractor\/daily\/[0-9]\{4\}\/[0-9]\{4\}-[0-9]\{2\}\/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\///g'
      ##perl ${push_script} -d ${mylist}
    else
      [[ "$debug" == "yes" ]] && echo "# warning: nothing found in '${mydate}'"
    fi
  fi
done

echo "# insertion ended: `date +%Y/%m/%d.%H:%M:%S`"

#------------------------------
# remove run status file
if [ -e $run_file ]; then
  /bin/rm -f $run_file
fi
