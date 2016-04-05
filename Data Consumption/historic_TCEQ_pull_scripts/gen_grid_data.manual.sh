#!/bin/bash
#
# dump grid data
#

#forward_processing=yes
forward_processing=no

#starting_date="2012-05-01"
starting_date="2012-06-01 00:00:00"
starting_epoch=$(date +%s -d "$starting_date");

#ending_date="2012-05-01 00:00:00"
ending_date="2012-07-31 04:20:00"
ending_epoch=$(date +%s -d "$ending_date");

echo "# starting date = $starting_date"
echo "# starting epoch = $starting_epoch"
echo "# ending date = $ending_date"
echo "# ending epoch = $ending_epoch"

if [[ "$forward_processing" == "yes" ]]; then
  echo "# forward processing ..."
  for (( e=${starting_epoch}; e<=${ending_epoch}; e+=300))
  do
    date_str=$(date +%Y-%m-%d.%H:%M:%S -d @${e})
    echo "# processing ($date_str) ..."
    /usr/bin/php /var/www/html/test/ozonemaps/dump_grid_json.php $e
  done
else
  echo "# backward processing ..."
  for (( e=${ending_epoch}; e>=${starting_epoch}; e-=300))
  do
    date_str=$(date +%Y-%m-%d.%H:%M:%S -d @${e})
    echo "# processing ($date_str) ..."
    /usr/bin/php /var/www/html/test/ozonemaps/dump_grid_json.php $e
  done
fi
