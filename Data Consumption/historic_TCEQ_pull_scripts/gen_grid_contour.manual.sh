#!/bin/bash
#
# generate grid / contour
#

#forward_processing=yes
forward_processing=no

#starting_date="2012-05-01"
starting_date="2009-01-01 00:00:00"
#starting_date="2012-05-26 08:20:00"
#starting_date="2012-06-06 21:00:00"
starting_epoch=$(date +%s -d "$starting_date");

#ending_date="2012-05-01 1:10"
##ending_date="2011-12-31 23:55:00"
ending_date="2010-03-31 14:20:00"
#ending_date="2012-06-14 18:45:00"
ending_epoch=$(date +%s -d "$ending_date");

sleep_duration=1

echo "# starting date = $starting_date"
echo "# starting epoch = $starting_epoch"
echo "# ending date = $ending_date"
echo "# ending epoch = $ending_epoch"

if [[ "$forward_processing" == "yes" ]]; then
  echo "# forward processing ..."
  for (( e=${starting_epoch}; e<=${ending_epoch}; e+=300))
  do
    date_str=$(date +%Y-%m-%d.%H:%M:%S -d @${e})
    echo "# processing ($date_str) band 0 ..."
    /usr/bin/php /var/www/html/test/ozonemaps/api/tools/calculategrid.php $e -1 0
    echo "# processing ($date_str) band 4 ..."
    /usr/bin/php /var/www/html/test/ozonemaps/api/tools/calculategrid.php $e -1 4
    sleep ${sleep_duration}
  done
else
  echo "# backward processing ..."
  for (( e=${ending_epoch}; e>=${starting_epoch}; e-=300))
  do
    date_str=$(date +%Y-%m-%d.%H:%M:%S -d @${e})
    echo "# processing ($date_str) band 0 ..."
    /usr/bin/php /var/www/html/test/ozonemaps/api/tools/calculategrid.php $e -1 0
    echo "# processing ($date_str) band 4 ..."
    /usr/bin/php /var/www/html/test/ozonemaps/api/tools/calculategrid.php $e -1 4
    sleep ${sleep_duration}
  done
fi
