#!/bin/bash
#
# compress data files
#

no_days_keep=5
#no_days_backtrack=30
no_days_backtrack=180

debug=yes


control_c()
# run if user hit control-c
{
  echo -en "# debug:  Control-C pressed!  Exiting...\n"
  exit 1
}

# trap keyboard interrupt (control-c)
trap control_c SIGINT


for top_dir in \
	/mnt/ibreathe/TCEQ/data_extractor/daily \
	/mnt/ibreathe/TCEQ/quick_look \

do
  for (( d=${no_days_backtrack}; d>${no_days_keep}; d--))
  do
    date_str_ymd=$(date +%Y-%m-%d -d "${d} days ago")
    date_str_ym=$(date +%Y-%m -d "${d} days ago")
    date_str_y=$(date +%Y -d "${d} days ago")

    [[ "${debug}" == "yes" ]] && echo "# Processing $d days ago : ${date_str_ymd} ..."
  
    target_dir=${top_dir}/${date_str_y}/${date_str_ym}/${date_str_ymd}
    for f in $(ls ${target_dir}/*.txt)
    do
      #[[ "${debug}" == "yes" ]] && echo "# debug:  processing ${f} ..."
      gzip -9v --rsyncable ${f}
    done
  done
done
