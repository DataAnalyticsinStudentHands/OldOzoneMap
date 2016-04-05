#!/bin/bash
#
# find missing data files
#

top_gridData_dir=/mnt/ibreathe/gridData
top_contourData_dir=/mnt/ibreathe/generatedcontour
#top_gridData_dir=/tmp/cc
#top_contourData_dir=/tmp/cc

starting_date="2012/08/17"
ending_date="2012/08/20"
#ending_date="2012/05/02"

forward_processing=yes
more_debug=no
#more_debug=yes

starting_epoch=$(date +%s -d "${starting_date}")
ending_epoch=$(date +%s -d "${ending_date}")


echo "# starting date = $starting_date"
echo "# starting epoch = $starting_epoch"
echo "# ending date = $ending_date"
echo "# ending epoch = $ending_epoch"

function check_files() {
  target_epoch=$1

  date_str=$(date +%Y-%m-%d.%H:%M:%S -d @${target_epoch})
  dir_str=$(date +%Y/%m/%d -d @${target_epoch})
  [[ ${more_debug} == "yes" ]] && echo "# processing ($date_str) ..."
    fname0=${top_contourData_dir}/${dir_str}/${e}_bs0.js
    fname4=${top_contourData_dir}/${dir_str}/${e}_bs4.js
    fnameG=${top_gridData_dir}/${dir_str}/gridData_${e}.js

    for v in "${fname0} contour" "${fname4} contour" "${fnameG} grid" ; do
      set -- $v
      location=$1
      datatype=$2

      if [ ! -e ${location} ]; then
        echo "${datatype}: ${target_epoch} : ${location} : ${date_str} : not_exist"
      elif [ ! -s ${location} ]; then
        echo "${datatype}: ${target_epoch} : ${location} : ${date_str} : empty"
      else
	check=''
	if [[ "${datatype}" == "contour" ]]; then
	  check=`grep contourData ${location} | grep "gen_time" | grep "timestamp" | grep "txnAt"`
	elif [[ "${datatype}" == "grid" ]]; then
	  check=`grep gridData ${location} | grep "gen_time" | grep "timestamp" | grep "gridExtent" | grep -e "]]})$"`
        fi
	if [[ (-z "$check") ]]; then
          echo "${datatype}: ${target_epoch} : ${location} : ${date_str} : bad_data"
	fi
      fi

    done
}

if [[ "$forward_processing" == "yes" ]]; then
  echo "# forward processing ..."
  for (( e=${starting_epoch}; e<=${ending_epoch}; e+=300))
  do
    check_files ${e}
  done
else
  echo "# backward processing ..."
  for (( e=${ending_epoch}; e>=${starting_epoch}; e-=300))
  do
    check_files ${e}
  done
fi
