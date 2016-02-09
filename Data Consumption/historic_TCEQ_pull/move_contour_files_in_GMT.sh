#!/bin/bash
#
# move contour data files based on GMT date
#

#/mnt/ibreathe/generatedcontour/2012/07/01/1341119700_bs4.js

top_dir=/mnt/ibreathe/generatedcontour

#years="2012 2011 2010 2009"
years="2012/07/01"

# more debug message
more_debug=true

for y in $years; do
  echo "# processing ${top_dir}/${y} ..."
  find ${top_dir}/${y} -name \*_bs?.js -print | while read line; do
    full_path=$line
    if [ -e ${full_path} ]; then
      if [[ "${full_path}" =~ _bs0.js ]] || [[ "${full_path}" =~ _bs4.js ]]; then
        #echo "pattern matched"
	fpath=${full_path%/*}
	fname=${full_path##*/}
	fepoch=${full_path:(-17):10}
	[[ "${more_debug}" =~ true ]] && echo "# debug: epoch = ${fepoch} (${full_path})"
	date_str=$(date -u +"%Y/%m/%d" -d @${fepoch})
	[[ "${more_debug}" =~ true ]] && echo "# debug: new dir (${full_path}) = ${top_dir}/${date_str}"
      else
        echo "Error: file name '${full_path}' doesn't match pattern"
      fi
    else
      echo "Error: file '${full_path}' not found"
    fi
  done
done
