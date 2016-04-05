#!/bin/bash
#
# compress and archive old logs
#

no_days_keep=5
#no_days_backtrack=30
no_days_backtrack=90
#no_days_backtrack=180

no_months_keep=1
no_months_backtrack=12

debug=yes

top_dir=/mnt/ibreathe/TCEQ/log

## move daily logs
for (( d=${no_days_backtrack}; d>${no_days_keep}; d--))
do
  date_str=$(date +%Y-%m-%d -d "${d} days ago")
  dir_date=$(date +"%Y/%Y-%m" -d "${d} days ago")
  [[ "${debug}" == "yes" ]] && echo "# Processing $d days ago : ${date_str} ..."
  
  for log_prefix in \
	fetch_data_extractor_daily.met \
	fetch_data_extractor_daily.o3 \
	fetch_quick_look.met \
	fetch_quick_look.o3 \
	insert_daily \
	fetch_data_extractor_daily \
	fetch_quick_look \
	insert_quick_look \

  do
    [[ "${debug}" == "yes" ]] && echo "# debug:  looking for ${fname} ..."
    fname=${top_dir}/${log_prefix}.${date_str}.log
    if [ -e ${fname} ]; then
      #echo "# debug: log file '${fname}' found ..."
      [[ "${debug}" == "yes" ]] && echo "# debug:    gzip -9v ${fname}"
      gzip -9v ${fname}
      target_dir=${top_dir}/archive/${dir_date}
      if [ ! -e ${target_dir} ]; then
	[[ "${debug}" == "yes" ]] && echo "# debug:  mkdir -p ${target_dir}"
	mkdir -p ${target_dir}
      fi
      [[ "${debug}" == "yes" ]] && echo "# debug:    mv ${fname}.gz ${target_dir}/"
      mv ${fname}.gz ${target_dir}/
    fi
  done
done


## move monthly logs
for (( m=${no_months_backtrack}; m>${no_months_keep}; m--))
do
  date_str=$(date +%Y-%m -d "${m} months ago")
  dir_date=$(date +"%Y/%Y-%m" -d "${m} months ago")
  [[ "${debug}" == "yes" ]] && echo "# Processing $m months ago : ${date_str} ..."
  
  for log_prefix in \
	fetch_data_extractor_daily.met \
	fetch_data_extractor_daily.o3 \
	fetch_quick_look.met \
	fetch_quick_look.o3 \
	insert_daily \
	fetch_data_extractor_daily \
	fetch_quick_look \
	insert_quick_look \
	compress_data \
	archive_log \

  do
    [[ "${debug}" == "yes" ]] && echo "# debug:  looking for ${fname} ..."
    fname=${top_dir}/${log_prefix}.${date_str}.log
    if [ -e ${fname} ]; then
      #echo "# debug: log file '${fname}' found ..."
      [[ "${debug}" == "yes" ]] && echo "# debug:    gzip -9v ${fname}"
      gzip -9v ${fname}
      target_dir=${top_dir}/archive/${dir_date}
      if [ ! -e ${target_dir} ]; then
	[[ "${debug}" == "yes" ]] && echo "# debug:  mkdir -p ${target_dir}"
	mkdir -p ${target_dir}
#      else
#	[[ "${debug}" == "yes" ]] && echo "### debug:  dir ${target_dir} exists"
      fi
      [[ "${debug}" == "yes" ]] && echo "# debug:    mv ${fname}.gz ${target_dir}/"
      mv ${fname}.gz ${target_dir}/
    fi
  done
done
