#!/bin/bash
#
# padding function name for JSONP
#
more_debug=true

if (( $# <= 0 )); then
  echo "Usage: $0 path_to_file"
else
  fname=$1
  if [ -e ${fname} ]; then
    if [[ "${fname}" =~ _bs0.js ]] || [[ "${fname}" =~ _bs4.js ]]; then
      #echo "pattern matched"
      patterns=$(grep contourData ${fname} | wc -l)
      #echo "patterns = ${patterns}"
      if (( ${patterns} <= 0 )); then
	fepoch=${fname:(-17):10}
	[[ "${more_debug}" =~ true ]] && echo "# debug: epoch = ${fepoch} (${fname})"
	#echo '# debug: cmd: sed -e "s/^/contourData${fepoch}(/; s/$/)/" $fname > /tmp/aa.txt'
	#sed -e "s/^/contourData${fepoch}(/; s/$/)/" $fname > /tmp/aa.txt
	#echo '# debug: cmd: sed -i -e "s/^/contourData${fepoch}(/; s/$/)/" $fname'
	sed -i -e "s/^/contourData${fepoch}(/; s/$/)/" $fname
      else
	echo "Error: file '${fname}' has been padded"
      fi
    else
      echo "Error: file name '${fname}' doesn't match pattern"
    fi
  else
    echo "Error: file '${fname}' not found"
  fi
fi
