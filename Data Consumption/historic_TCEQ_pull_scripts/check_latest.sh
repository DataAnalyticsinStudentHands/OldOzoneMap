#!/bin/bash
#
# check date of latest data file
#

no_days_backtrack=5

debug=yes

top_dir_quick_look=/mnt/ibreathe/TCEQ/quick_look
top_dir_data_extractor=/mnt/ibreathe/TCEQ/data_extractor/daily
top_dir_grid=/mnt/ibreathe/gridData
top_dir_contour=/mnt/ibreathe/generatedcontour

control_c()
# run if user hit control-c
{
  echo -en "# debug:  Control-C pressed!  Exiting...\n"
  exit 1
}

# trap keyboard interrupt (control-c)
trap control_c SIGINT

for v in \
	"quick_look ${top_dir_quick_look} yymymd o3 txt" \
	"data_extractor ${top_dir_data_extractor} yymymd o3 txt" \
	"grid ${top_dir_grid} ymd gridData js" \
	"contour ${top_dir_contour} ymd '' bs4.js" \

do

  set -- $v
  name=$1
  top_dir=$2
  date_str_type=$3
  prefix=$4
  ext=$5

  for (( d=0; d<=${no_days_backtrack}; d++ ))
  do
    date_str_yymymd=$(date +"%Y/%Y-%m/%Y-%m-%d" -d "${d} days ago")
    date_str_ymd=$(date +"%Y/%m/%d" -d "${d} days ago")
    date_str=$(date +"%Y-%m-%d" -d "${d} days ago")

    [[ "${debug}" == "yes" ]] && echo "# Processing ${name}: $d days ago : ${date_str} ..."

    if [[ "${date_str_type}" == "yymymd" ]]; then
      dir_date_str=${date_str_yymymd}
    else
      dir_date_str=${date_str_ymd}
    fi
  
    target_dir=${top_dir}/${dir_date_str}

    if [ -e ${target_dir} ]; then
      prefix=${prefix%\'\'}
      fname=`ls -lcat ${target_dir}/${prefix}*${ext} | head -1 | awk '{print $9}'`
      if [ -e ${fname} ]; then
	fepoch=$(stat -c %Y ${fname})
	fepoch_date=$(date +%Y-%m-%d.%H:%M:%S -d @${fepoch})
        echo "# debug: ${name}: found ${fname} : ${fepoch_date} (${fepoch})"
        break;
      fi
    fi
  done
done
