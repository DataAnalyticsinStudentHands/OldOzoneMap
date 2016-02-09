#!/usr/bin/perl
#
# extract ozone data from screen dump of quick look page on TCEQ internal web site
#
#   http://163.234.120.84/cgi-bin/quick_look.pl?param=44201&view_hours=2&local=00%3A00%3A00&ordinal=1&region_crit=12&include_CAMS=1&include_TAMS=1&include_HOUSTON=1&include_HARRIS_CNTY=1&include_HRM=1&include_EISM=1
#

use strict;
use Getopt::Std;
use POSIX;
use File::Path;
use Time::Local;
#use HTTP::Date qw(str2time);
# from package: libtimedate-perl (Ubuntu) or perl-TimeDate (Centos/EPEL)
use Date::Parse;


my $CAMS_geo_file = 'CAMS.Houston.geo.name.csv';
my (%CAMS_lat, %CAMS_lon);	# CAMS lat/lon
my %CAMS_name;			# CAMS name

my %hash_date_time;		# hash for date time index
my %hash_epoch;			# hash for epoch time
my %hash_site_id;		# hash for site id; mapping: site_id ==> epoch ==> Ozone data
my %hash_delay;			# hash for delay; mapping: site_id ==> epoch ==> Ozone data

my %options;			# cmd line options
my $FH = *STDOUT;		# file handler for output

# set command line options
getopts("dhHGo:O:p:vR", \%options);

# print usage if needed
usage() if exists($options{h}) || !(exists($options{H}) ||
	exists($options{o}) || exists($options{O}) || exists($options{v}) ||
	exists($options{G}) || exists($options{d}) ||
	exists($ARGV[0]) );

if (exists($options{o})) {
  open (OUTPUT, ">$options{o}") or die "Couldn't write to '$options{o}': $?\n";
  $FH = *OUTPUT;
} # if

#
# get geo location
#
open (CAMS, "<$CAMS_geo_file") or die "# Error: cannot open CAMS geo location file '$CAMS_geo_file': $?\n";
while (my $line = <CAMS>) {
  next if $line =~ /site_id/;		# skip header
  chomp($line);
  my @tmp_list = split /,/, $line;
  $CAMS_lat{$tmp_list[0]} = $tmp_list[1];
  $CAMS_lon{$tmp_list[0]} = $tmp_list[2];
  $CAMS_name{$tmp_list[0]} = $tmp_list[3];
} # while
close CAMS;

#
# read quick look output file/dir
#

for (my $v = 0; $v <= $#ARGV; $v++) {

  my @flist;            # file list

  if ( -d $ARGV[$v]) {
    # it's a directory
    my $dir = $ARGV[$v];
    print $FH "# debug: ARGV[$v] = '$dir' is a directory\n" if exists($options{v});
    opendir(DIR, $dir) or die "# Error: cannot open directory '$dir': $!\n";
    while (my $file = readdir(DIR)) {
      next unless (-f "$dir/$file");            # we only want file
      push(@flist, "$dir/$file");
      print $FH "# debug:   find input file '$dir/$file' \n" if exists($options{v});
    } # while
  } # if
  else {
    # it's a file
    push(@flist,$ARGV[$v]);
    print $FH "# debug:   find input file '$ARGV[$v]' \n" if exists($options{v});
  } # else

  foreach my $fn (@flist) {
    next unless (-e $fn);

    print "## processing $fn\n" if exists($options{v}) && exists($options{o});
    print $FH "## processing $fn]\n" if exists($options{v});

    open (INPUT, "<$fn") or die "# Error: cannot open input file '$fn': $?\n";

    my $line;
    my $base_epoch;			# base epoch time for data (basically 00:00 CST of reporting day)
    my $report_epoch;			# epoch time of "quick look" page gnerated

    my @time_label;			# time label at top of table

    while ($line = <INPUT>) {
      last if $line =~ /Report generated: /;	# skip everything up till "Report generated: "
    } # while

    chomp($line);
    my ($year,$month,$day,$hour,$min,$sec,$tzone);

    # get date time
    #	Report generated: Monday August 15, 2011 12:00:01 CST
    if ($line =~ /Report generated:\s+\w+\s+(\w+)\s+(\d+),\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\w+)/) {
      $month = $1;
      $day = $2;
      $year = $3;
      $hour = $4;
      $min = $5;
      $sec = $6;
      $tzone = $7;

      $month = substr($month,0,3);
      $report_epoch = str2time("$day $month $year $hour:$min:$sec $tzone");
      $base_epoch = str2time("$day $month $year 00:00:00 $tzone");
      print $FH "# debug: date/time => $year / $month / $day,  $hour:$min:$sec $tzone\n" if exists($options{v});
      print $FH "# report_epoch: $report_epoch\n" if exists($options{v});
      print $FH "# base_epoch: $base_epoch\n" if exists($options{v});
    } # if
    #     Report generated: Monday August 15, 2011
    #                   00:00:01 CST
    elsif ($line =~ /Report generated:\s+\w+\s+(\w+)\s+(\d+),\s+(\d+)/) {
      $month = $1;
      $day = $2;
      $year = $3;
      $line = <INPUT>;		# read another line
      chomp($line);
      if ($line =~ /\s+(\d+):(\d+):(\d+)\s+(\w+)/) {
        $hour = $1;
        $min = $2;
        $sec = $3;
        $tzone = $4;

        $month = substr($month,0,3);
        $report_epoch = str2time("$day $month $year $hour:$min:$sec $tzone");
        $base_epoch = str2time("$day $month $year 00:00:00 $tzone");
        print $FH "# debug: date/time => $year / $month / $day,  $hour:$min:$sec $tzone\n" if exists($options{v});
        print $FH "# report_epoch: $report_epoch\n" if exists($options{v});
        print $FH "# base_epoch: $base_epoch\n" if exists($options{v});
      } # if
      else {
        die "# Error: cannot parse date/time from '$line'\n";
      } # else
    } # elsif
    else {
      die "# Error: cannot parse date/time from '$line'\n";
    } # else

    # skip till separator line
    while ($line = <INPUT>) {
      last if $line =~ /--------+----/;	# skip everything up till table separtor line
    } # while

    # now good stuff
    my $counter = 0;
    my $counter_QAS = 0;
    #my %tmp_hash;			# temp hash for Ozone data
    my $header = 0;			# no header yet

    while (my $line = <INPUT>) {
      next if $line =~/----+----/;		# skip separator
      chomp($line);
      last if $line =~ /^\s*$/;
      $line =~ s/^\s+//;			# remove leading blanks
      $line =~ s/\s+$//;			# remove tailing blanks

      #
      # split input line
      #
      my @tmp_list = split /\|/, $line;	# split line that separated by '|'

      # get header / time
      if ($header == 0) {
	for (my $i = 3; $i <= $#tmp_list; $i++) {
	  next if ($tmp_list[$i] =~ /\[.*\]/);
	  my $tmp_str = $tmp_list[$i];
	  $tmp_str =~ s/\s+//g;			# remove blanks
	  next if length($tmp_str) <= 0;	# skip empty block
	  #print $FH "# debug: date/time str = '$day $month $year $tmp_str:00 $tzone'\n" if exists($options{v});
	  my $tmp_epoch = str2time("$day $month $year $tmp_str:00 $tzone");
	  #print $FH "# debug: tmp_epoch = '$tmp_epoch'\n" if exists($options{v});
	  push(@time_label, $tmp_epoch);
	  $hash_epoch{$tmp_epoch} = 1;
	} # for
	$header = 1;

#        if (exists($options{v})) {
#          for (my $t = 0; $t <= $#time_label; $t++) {
#            my $tmp_str = epoch_to_datetime($time_label[$t]);
#            print $FH "# debug: time label [$t]: $tmp_str ($time_label[$t])\n";
#          } # foreach
#        } # if

	next;
      } # if

      # now processing data
      my $tmp_site = $tmp_list[2];
      $tmp_site =~ s/\s+//g;
      $tmp_site =~ s/\[\d+\]//;

      if (length($tmp_site) <= 0) {
	#
	# assume site id is 603 if it's not assigned
	#
	$tmp_site = 603;
	my $tmp_site_poc = $tmp_list[$#time_label+5];
	$tmp_site_poc =~ s/\s+//g;
	$tmp_site .= "_$tmp_site_poc";
      } # if

      last if $tmp_site =~ /CAMS/;			# reaching the end of data table

      print $FH "# debug: site id = $tmp_site\n" if exists($options{v});
      print $FH "# debug: tmp_list items = $#tmp_list / $#time_label\n" if exists($options{v}) && exists($options{R});

      if ($#tmp_list <= ($#time_label + 6)) {
	#
	# normal table layout
	#
	if (!exists($hash_site_id{$tmp_site})) {
	  my %tmp_hash;					# hash to store values
	  $hash_site_id{$tmp_site} = \%tmp_hash;	# store data to hash_site_id
	} # if
	if (!exists($hash_delay{$tmp_site})) {
	  my %tmp_hash_d;				# hash to store values
	  $hash_delay{$tmp_site} = \%tmp_hash_d;	# store data to hash_delay
	} # if
	for (my $n = 0; $n <= $#time_label; $n++) {
	  my $tmp_value = $tmp_list[$n+3];
	  $tmp_value =~ s/\s+//g;			# remove blanks
	  if (length($tmp_value > 0)) {
	    my $tmp_datetime_str = epoch_to_datetime($time_label[$n]);
	    print $FH "# debug:   site $tmp_site : [$tmp_datetime_str] = '$tmp_value'\n" if exists($options{v}) && exists($options{R});
	    if (!exists($hash_site_id{$tmp_site}->{$time_label[$n]})) {
	      $hash_site_id{$tmp_site}->{$time_label[$n]} = $tmp_value;
	      my $delay = $report_epoch - $time_label[$n];
	      if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # if
	      elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	        print $FH "# debug: updated: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) with $hash_site_id{$tmp_site}->{$time_label[$n]} \n" if exists($options{v});
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # elsif
	    } # if
	    elsif ($hash_site_id{$tmp_site}->{$time_label[$n]} != $tmp_value) {
	      print $FH "# debug: mismatch: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) : $hash_site_id{$tmp_site}->{$time_label[$n]} <> $tmp_value\n" if exists($options{v});
	    } # elsif
	  } # if
	  else {
	    my $delay = $report_epoch - $time_label[$n];
	    if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # if
	    elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	      print $FH "# debug: continuous missing data: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v});
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # elsif
	  } # else
	  #push(@time_label, $tmp_epoch);
	} # for
      } # if
      elsif ($#tmp_list <= ($#time_label + 8)) {
	# extra stuff
	$tmp_site = $tmp_list[3];
	$tmp_site =~ s/\s+//g;			# remove blanks
	if ($tmp_site =~ /\[\d+\]/) {
	  $tmp_site =~ s/\[\d+\]//;
	} # if

	if (!exists($hash_site_id{$tmp_site})) {
	  my %tmp_hash;					# hash to store values
	  $hash_site_id{$tmp_site} = \%tmp_hash;	# store data to hash_site_id
	} # if
	if (!exists($hash_delay{$tmp_site})) {
	  my %tmp_hash_d;				# hash to store values
	  $hash_delay{$tmp_site} = \%tmp_hash_d;	# store data to hash_delay
	} # if
	my $offset = 0;
	for (my $n = 0; $n <= $#time_label; $n++) {
	  my $tmp_value = $tmp_list[$n+4+$offset];

	  if ($tmp_value =~ /\[\d+\]/ || $tmp_value =~ /^\s+$/) {
	    $tmp_value = $tmp_list[$n+5+$offset];		# use next value
	    $tmp_value =~ s/\[\d+\]//;
	    $offset ++;
	  } # if

	  $tmp_value =~ s/\s+//g;			# remove blanks
	  if (length($tmp_value > 0)) {
	    my $tmp_datetime_str = epoch_to_datetime($time_label[$n]);
	    print $FH "## debug:   site $tmp_site : [$tmp_datetime_str] = '$tmp_value'\n" if exists($options{v}) && exists($options{R});
	    if (!exists($hash_site_id{$tmp_site}->{$time_label[$n]})) {
	      $hash_site_id{$tmp_site}->{$time_label[$n]} = $tmp_value;
	      my $delay = $report_epoch - $time_label[$n];
	      if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # if
	      elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	        print $FH "## debug: updated: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) with $hash_site_id{$tmp_site}->{$time_label[$n]} \n" if exists($options{v});
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # elsif
	    } # if
	    elsif ($hash_site_id{$tmp_site}->{$time_label[$n]} != $tmp_value) {
	      print $FH "## debug: mismatch: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) : $hash_site_id{$tmp_site}->{$time_label[$n]} <> $tmp_value\n" if exists($options{v});
	    } # elsif
	  } # if
	  else {
	    my $delay = $report_epoch - $time_label[$n];
	    if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # if
	    elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	      print $FH "## debug: continuous missing data: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v});
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # elsif
	  } # else
	  #push(@time_label, $tmp_epoch);
	} # for
      } # elsif
      else {
	# lots of extra stuff

	if (!exists($hash_site_id{$tmp_site})) {
	  my %tmp_hash;					# hash to store values
	  $hash_site_id{$tmp_site} = \%tmp_hash;	# store data to hash_site_id
	} # if
	if (!exists($hash_delay{$tmp_site})) {
	  my %tmp_hash_d;				# hash to store values
	  $hash_delay{$tmp_site} = \%tmp_hash_d;	# store data to hash_delay
	} # if

	# get regular stuff first
	for (my $n = 0; $n <= $#time_label; $n++) {
	  my $tmp_value = $tmp_list[$n+3];
	  $tmp_value =~ s/\s+//g;			# remove blanks
	  if (length($tmp_value > 0)) {
	    my $tmp_datetime_str = epoch_to_datetime($time_label[$n]);
	    print $FH "### debug:   site $tmp_site : [$tmp_datetime_str] = '$tmp_value'\n" if exists($options{v}) && exists($options{R});
	    if (!exists($hash_site_id{$tmp_site}->{$time_label[$n]})) {
	      $hash_site_id{$tmp_site}->{$time_label[$n]} = $tmp_value;
	      my $delay = $report_epoch - $time_label[$n];
	      if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # if
	      elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	        print $FH "### debug: updated: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) with $hash_site_id{$tmp_site}->{$time_label[$n]} \n" if exists($options{v});
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # elsif
	    } # if
	    elsif ($hash_site_id{$tmp_site}->{$time_label[$n]} != $tmp_value) {
	      print $FH "### debug: mismatch: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) : $hash_site_id{$tmp_site}->{$time_label[$n]} <> $tmp_value\n" if exists($options{v});
	    } # elsif
	  } # if
	  else {
	    my $delay = $report_epoch - $time_label[$n];
	    if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # if
	    elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	      print $FH "### debug: continuous missing data: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v});
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # elsif
	  } # else
	  #push(@time_label, $tmp_epoch);
	} # for

	# get reset of lines
	my $base_offset = $#time_label + 6;
	my $tmp_site_pov = $tmp_list[$base_offset + $#time_label + 1];
	$tmp_site_pov =~ s/\s+//g;
	$tmp_site =~ s/_\d+$/_$tmp_site_pov/;
	print $FH "# debug: new site id = $tmp_site / $tmp_site_pov\n" if exists($options{v});

	if (!exists($hash_site_id{$tmp_site})) {
	  my %tmp_hash;					# hash to store values
	  $hash_site_id{$tmp_site} = \%tmp_hash;	# store data to hash_site_id
	} # if
	if (!exists($hash_delay{$tmp_site})) {
	  my %tmp_hash_d;				# hash to store values
	  $hash_delay{$tmp_site} = \%tmp_hash_d;	# store data to hash_delay
	} # if

	for (my $n = 0; $n <= $#time_label; $n++) {
	  my $tmp_value = $tmp_list[$n+$base_offset];
	  $tmp_value =~ s/\s+//g;			# remove blanks
	  if (length($tmp_value > 0)) {
	    my $tmp_datetime_str = epoch_to_datetime($time_label[$n]);
	    print $FH "#### debug:   site $tmp_site : [$tmp_datetime_str] = '$tmp_value'\n" if exists($options{v}) && exists($options{R});
	    if (!exists($hash_site_id{$tmp_site}->{$time_label[$n]})) {
	      $hash_site_id{$tmp_site}->{$time_label[$n]} = $tmp_value;
	      my $delay = $report_epoch - $time_label[$n];
	      if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # if
	      elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	        print $FH "#### debug: updated: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) with $hash_site_id{$tmp_site}->{$time_label[$n]} \n" if exists($options{v});
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # elsif
	    } # if
	    elsif ($hash_site_id{$tmp_site}->{$time_label[$n]} != $tmp_value) {
	      print $FH "#### debug: mismatch: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) : $hash_site_id{$tmp_site}->{$time_label[$n]} <> $tmp_value\n" if exists($options{v});
	    } # elsif
	  } # if
	  else {
	    my $delay = $report_epoch - $time_label[$n];
	    if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # if
	    elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	      print $FH "#### debug: continuous missing data: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v});
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # elsif
	  } # else
	  #push(@time_label, $tmp_epoch);
	} # for

	# get reset of lines
	my $base_offset = $#time_label*2 + 8;
	my $tmp_site_pov = $tmp_list[$base_offset + $#time_label + 1];
	$tmp_site_pov =~ s/\s+//g;
	$tmp_site =~ s/_\d+$/_$tmp_site_pov/;
	print $FH "# debug: new site id = $tmp_site / $tmp_site_pov\n" if exists($options{v});

	if (!exists($hash_site_id{$tmp_site})) {
	  my %tmp_hash;					# hash to store values
	  $hash_site_id{$tmp_site} = \%tmp_hash;	# store data to hash_site_id
	} # if
	if (!exists($hash_delay{$tmp_site})) {
	  my %tmp_hash_d;				# hash to store values
	  $hash_delay{$tmp_site} = \%tmp_hash_d;	# store data to hash_delay
	} # if

	for (my $n = 0; $n <= $#time_label; $n++) {
	  my $tmp_value = $tmp_list[$n+$base_offset];
	  $tmp_value =~ s/\s+//g;			# remove blanks
	  if (length($tmp_value > 0)) {
	    my $tmp_datetime_str = epoch_to_datetime($time_label[$n]);
	    print $FH "##### debug:   site $tmp_site : [$tmp_datetime_str] = '$tmp_value'\n" if exists($options{v}) && exists($options{R});
	    if (!exists($hash_site_id{$tmp_site}->{$time_label[$n]})) {
	      $hash_site_id{$tmp_site}->{$time_label[$n]} = $tmp_value;
	      my $delay = $report_epoch - $time_label[$n];
	      if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # if
	      elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	        print $FH "##### debug: updated: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) with $hash_site_id{$tmp_site}->{$time_label[$n]} \n" if exists($options{v});
	        $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	      } # elsif
	    } # if
	    elsif ($hash_site_id{$tmp_site}->{$time_label[$n]} != $tmp_value) {
	      print $FH "##### debug: mismatch: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n]) : $hash_site_id{$tmp_site}->{$time_label[$n]} <> $tmp_value\n" if exists($options{v});
	    } # elsif
	  } # if
	  else {
	    my $delay = $report_epoch - $time_label[$n];
	    if (!exists($hash_delay{$tmp_site}->{$time_label[$n]})) {
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # if
	    elsif ($hash_delay{$tmp_site}->{$time_label[$n]} < $delay) {
	      print $FH "##### debug: continuous missing data: site[$tmp_site] \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v});
	      $hash_delay{$tmp_site}->{$time_label[$n]} = $delay;
	    } # elsif
	  } # else
	  #push(@time_label, $tmp_epoch);
	} # for

      } # elsif

      next;

#      if ($tmp_list[2] =~ /\[.*\]/) {	# skip QAS state
#	$counter_QAS++;
#	next;
#      } # if
#
#      my $key_date_time = "$tmp_list[0],$tmp_list[1]";
#      $hash_date_time{$key_date_time} = 1;
#
#      my ($month,$day,$year) = split /\//, $tmp_list[0];
#      my ($hours,$min,$sec) = split /:/, $tmp_list[1];
#      $month = $month/1 - 1;		# month: 0..11
#      my $epoch = timegm($sec,$min,$hours,$day,$month,$year);
#      $hash_epoch{$epoch} = 1;
#      
#      $tmp_hash{$epoch} = $tmp_list[2];
#
#      $counter++;
#      #print $FH "# input data [$counter]/$epoch: '$line'\n" if exists($options{v});
    } # while

    close INPUT;

  } # foreach
} # for

#
# generate output
#

my $CFH = *STDOUT;		# file handler for output
if (exists($options{O})) {
  open (CSVOUTPUT, ">>$options{O}") or die "Couldn't write to '$options{O}': $?\n";
  $CFH = *CSVOUTPUT;
} # if

if (!exists($options{d})) {
  #
  # print data in CSV format
  #
  # print header
  print $CFH '#site_id/epoch,latitude,longitude';
  foreach my $e (sort keys %hash_epoch) {
    print $CFH ",$e"
  } # foreach
  print $CFH "\n";

  # print 2nd header
  if (exists($options{H}) || exists($options{G})) {
    print $CFH '#site_id/date.time,latitude,longitude';
    if (exists($options{G})) {
      foreach my $e (sort keys %hash_epoch) {
	print $CFH ',"'.epoch_to_GMT_datetime($e).'"';
      } # foreach
    } # if
    else {
      foreach my $e (sort keys %hash_epoch) {
	print $CFH ',"'.epoch_to_datetime($e).'"';
      } # foreach
    } # else
    print $CFH "\n";
  } # if

  foreach my $id (sort { $a <=> $b } keys %hash_site_id) {
    print $FH "# id = $id, lat = $CAMS_lat{$id}, lon = $CAMS_lon{$id}\n" if exists($options{v});
    print $CFH "$id,$CAMS_lat{$id},$CAMS_lon{$id}";
    foreach my $e (sort keys %hash_epoch) {
      if (exists($hash_site_id{$id}->{$e})) {
	print $CFH ",$hash_site_id{$id}->{$e}";
      } # if
      else {
	print $CFH ',';
      } # else
    } # foreach
    print $CFH "\n";
  } # foreach

} # if
else {
  print $CFH "epoch,date_time,site,delay\n";

  foreach my $e (sort keys %hash_epoch) {
    foreach my $id (sort { $a <=> $b } keys %hash_site_id) {
      if (exists($hash_delay{$id}->{$e})) {
        print $CFH "$e,\"".epoch_to_datetime($e)."\",$id,$hash_delay{$id}->{$e}\n";
      } # if
      else {
        print $CFH "$e,\"".epoch_to_datetime($e)."\",$id,\n";
      } # else
    } # foreach
  } # foreach
} # if

close $FH;

#------------------------------------
#
# convert epoch to datetime string
#
sub epoch_to_datetime {

  my ($epoch) = @_;

  my ($sec, $min, $hour, $day, $month, $year) = (localtime($epoch))[0,1,2,3,4,5,6];
  my $datetime_str = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year+1900, $month+1, $day, $hour, $min, $sec;

  return $datetime_str;
} # sub epoch_to_datetime

#------------------------------------
#
# convert epoch to GMT datetime string
#
sub epoch_to_GMT_datetime {

  my ($epoch) = @_;

  my ($sec, $min, $hour, $day, $month, $year) = (gmtime($epoch))[0,1,2,3,4,5,6];
  my $GMT_datetime_str = sprintf "%d/%02d/%02d %02d:%02d:%02d GMT", $year+1900, $month+1, $day, $hour, $min, $sec;

  return $GMT_datetime_str;
} # sub epoch_to_GMT_datetime

#-------------------------------------
#
# usage
#
sub usage {
  print $FH "Usage: $0 [options] input_file\n";
  print $FH <<__usage__;
  -d		show delay
  -h	    	print usage
  -H	    	print 2nd header with local date time (instead of epoch time)
  -G	    	print 2nd header with GMT date time (instead of epoch time)
  -o outfile	write message/log to outfile instead of STDOUT
  -O CSVfile	write output to CSVfile instead of STDOUT (aggregated output)
  -p prefix	prefix for output file
  -v		verbose output
  -R		show raw value (use with -v)
__usage__
  exit; 
} # sub usage
