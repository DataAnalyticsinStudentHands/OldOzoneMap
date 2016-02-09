#!/bin/bash
#
# insert quick look TCEQ data into database
#
# Last modify: 2012/08/08
#

# top data directory
top_dir=/mnt/ibreathe/TCEQ/quick_look

# data insertion script
push_script=/mnt/ibreathe/TCEQ/scripts/push_ibh_quick_look.pl

# search number of days from today
Ndays=1

# debugging flag: set yes (on) or no (off)
debug=no
#debug=yes

#-----------------------------------
## for checking run status
run_file=/mnt/ibreathe/TCEQ/state/insert_quick_look.sh.run

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
  if [ -d ${top_dir}/${mydate} ]; then

    for inst in winddir windspd o3 temp pm25 humid solar
    do
      #[[ "$debug" == "yes" ]] && echo "find ${top_dir}/${mydate} -type f -mtime -${Ndays} -print | sort -t. -n -k 4,4"
      tmp_list=`find ${top_dir}/${mydate} -type f -name "${inst}.*" -mtime -${Ndays} -print | sort -t. -n -k 3,3`

	#echo "# debug: inst=${inst} ; tmp_list = '$tmp_list'"

      if [[ "${inst}" == "o3" || "${inst}" == "winddir" || "${inst}" == "windspd" ]]; then
	gen_arg="-g"
      else
	gen_arg=''
      fi

      if [ -n "${tmp_list}" ]; then
        [[ "$debug" == "yes" ]] && echo "# debug: tmp_list = '$tmp_list'"
        mylist=`echo ${tmp_list} | sed 's/\r/ /'`
        #[[ "$debug" == "yes" ]] && echo "# executing: 'perl ${push_script} -d -R ${mylist}'"
        #[[ "$debug" == "yes" ]] && echo "# executing: 'perl -g ${push_script} -d -R ${mylist}'" | sed 's/\/mnt\/ibreathe\/TCEQ\/quick_look\/[0-9]\{4\}\/[0-9]\{4\}-[0-9]\{2\}\/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\///g'
        if [[ "$debug" == "yes" ]]; then
          echo "# executing: 'perl ${push_script} -v -d -R ${gen_arg} ${mylist}'" | sed 's/\/mnt\/ibreathe\/TCEQ\/quick_look\/[0-9]\{4\}\/[0-9]\{4\}-[0-9]\{2\}\/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\///g'
          perl ${push_script} -v -d -R ${gen_arg} ${mylist}
        else
	  #echo perl ${push_script} -d -R ${gen_arg} ${mylist}
          perl ${push_script} -d -R ${gen_arg} ${mylist}
        fi
      else
        [[ "$debug" == "yes" ]] && echo "# warning: nothing found in '${mydate}'"
      fi
    done
  fi
done

echo "# insertion ended: `date +%Y/%m/%d.%H:%M:%S`"

#------------------------------
# remove run status file
if [ -e $run_file ]; then
  /bin/rm -f $run_file
fi
