#!/usr/bin/perl

#
# monitor ibreathe status
#
#    Typical usage:
#	perl monitor.pl /mnt/ibreathe/TCEQ/script/ibreathe_status.php
#
#    For testing:
#	perl monitor.pl -v -m status.php
#
#
# Created: 02/28/2009
# Modified: 01/23/2011
#
# Author: T. Mark Huang
#
#

use strict;
use Getopt::Std;	# command line option
use DBI; 		# use dbi for database connection
use POSIX qw(ceil floor);
use File::stat;
use Time::Local;

# change these variables for different cluster

database=ibreathedb
username=ibhro
passwd=user4iBH


  # database user id
  my $dbuser = 'ibhro';

  # database password
  my $dbpass = 'user4iBH';

  # database hosting machine name
  my $dbhost = 'localhost';
  ##my $dbhost = '127.0.0.1:3307';

  # database name
  my $dbname = 'ibreathedb';

  # status table
  my $status_table = 'ibreathe_status';

my %datafile;
  $datafile{'data_extractor'} = {
	brief => 'DE',
	topdir => '/mnt/ibreathe/TCEQ/data_extractor/daily',
	date_format => 'yymymd',
	prefix => 'o3',
	ext => 'txt'
  };
  $datafile{'quick_look'} = {
	brief => 'QL',
	topdir => '/mnt/ibreathe/TCEQ/quick_look',
	date_format => 'yymymd',
	prefix => 'o3',
	ext => 'txt'
  };
  $datafile{'contour'} = {
	brief => 'CT',
	topdir => '/mnt/ibreathe/generatedcontour',
	date_format => 'ymd',
	prefix => '',
	ext => 'bs4.js'
  };
  $datafile{'grid'} = {
	brief => 'GR',
	topdir => '/mnt/ibreathe/gridData',
	date_format => 'ymd',
	prefix => 'gridData',
	ext => 'js'
  };

my %options;		# hash used for command line option
my $FH = *STDOUT;	# used for output redirection

## config
my @location_name_short;	# location short name
my @table_name_met;		# table name for met data
my @table_name_chem;		# table name for chemistry data
my @path_webcam;		# path to web cam files
my @path_skycam;		# path to sky cam files

## latest epoch time
my @latest_update_met;		# last update for met data
my @latest_update_chem;		# last update for chem data
my @latest_update_webcam;	# last update for webcam file
my @latest_update_skycam;	# last update for skycam file

## status -- previous epoch time
my @status_met;			# previous status of met data
my @status_chem;		# previous status of chem data
my @status_webcam;		# previous status of webcam
my @status_skycam;		# previous status of webcam
my %status_id;			# hash to store status id

## status string for reporting
my @status_met_str;		# previous status of met data
my @status_chem_str;		# previous status of chem data
my @status_webcam_str;		# previous status of webcam
my @status_skycam_str;		# previous status of skycam
my $subject_string;		# string for email subject

my $notification_threshold = 45 * 60;	# threshold of deciding a site is down (in sec)

# email list for notification
my $email_from = 'hnetwebmaser@tlc2.uh.edu';
my $email_list = 'tihuang@tlc2.uh.edu';
#my $email_list = 'tihuang@tlc2.uh.edu blefer@uh.edu jhflynn@uh.edu anddarrell@gmail.com azucena.r.torres@gmail.com natalie.ferrari@live.com barbaraschmeitz@yahoo.com';  ## updated 2011-01-12

# setup commandline options
getopts("c:dhmo:vw:", \%options);

#
# beginning of main function
#

usage() if exists($options{h}) || !(exists($options{o}) ||
       exists($options{c}) || exists($options{d}) || exists($options{m}) || 
       exists($options{v}) || exists($ARGV[0]) );

if (exists($options{o})) {
  open (OUTPUT, ">>$options{o}") or die "Couldn't write to '$options{o}': $!\n";
  $FH = *OUTPUT;
} # if

if (exists($options{c})) {
  $config_file = $options{c};
} # if

# check for accounting file
die "Error: config file '$config_file' not found.\n" if ! -e $config_file;

print $FH "# debug: use config file '$config_file'\n" if exists($options{v});

open (CONFIG, "<$config_file") or die "# Error: cannot read '$config_file': $?\n";
while (my $line = <CONFIG>) {
  next if ($line =~ /^\s+$/);		# skip blank line
  chomp($line);				# remove LF/CR

  $line =~ s/^\s+//;			# remove leading blanks
  $line =~ s/\s+$//;			# remove tailing blanks

  next if $line =~ /^#/;		# skip comments
  next if $line =~ /^\/\//;		# skip php comments
  next if $line =~ /^<\?php/;		# skip php header
  next if $line =~ /^\?>/;		# skip php tail

  $line =~ s/;$//;			# remove tailing ';'

  my @tmp_list = split /(\s*=\s*)/, $line;	# assume format is "VAR = value"
  ##print $FH "# debug: var='$tmp_list[0]'  sign='$tmp_list[1]'  value='$tmp_list[2]'\n" if exists($options{v});

  $tmp_list[2] =~ s/^'(.*)'$/$1/;	# remove enclosed quote "'"
  $tmp_list[2] =~ s/^"(.*)"$/$1/;	# remove enclosed quote '"'
  
  if ($tmp_list[0] =~ /location_name_short\[(\d)\]/) {
    my $id = $1 - 1;
    $location_name_short[$id] = $tmp_list[2];
    ##print $FH "# debug: location_name_short[$id] = $location_name_short[$id]\n" if exists($options{v});
  } # if
  elsif ($tmp_list[0] =~ /table_var\[(\d)\]\['temp'\]\['table'\]/) {
    my $id = $1 - 1;
    $table_name_met[$id] = $tmp_list[2];
    ##print $FH "# debug: table_name_met[$id] = $table_name_met[$id]\n" if exists($options{v});
  } # elsif
  #### use zeno_table_name
  ##elsif ($tmp_list[0] =~ /table_var\[(\d)\]\['co'\]\['table'\]/) {
  elsif ($tmp_list[0] =~ /zeno_table_var\[(\d)\]\['o3'\]\['table'\]/) {
    my $id = $1 - 1;
    $table_name_chem[$id] = $tmp_list[2];
    ##print $FH "# debug: table_name_chem[$id] = $table_name_chem[$id]\n" if exists($options{v});
  } # elsif
  elsif ($tmp_list[0] =~ /webcam\[(\d)\]/) {
    my $id = $1 - 1;
    $path_webcam[$id] = $top_web_dir.$tmp_list[2];
    ##print $FH "# debug: path_webcam[$id] = $path_webcam[$id]\n" if exists($options{v});
  } # elsif
  elsif ($tmp_list[0] =~ /skycam\[(\d)\]/) {
    my $id = $1 - 1;
    $path_skycam[$id] = $top_web_dir.$tmp_list[2];
    ##print $FH "# debug: path_skycam[$id] = $path_skycam[$id]\n" if exists($options{v});
  } # elsif
  elsif ($tmp_list[0] =~ /notification_threshold/) {
    $notification_threshold = $tmp_list[2];
    print $FH "# debug: notification_threshold = $notification_threshold\n" if exists($options{v});
  } # elsif

} # while

# connect to the database
print $FH "# debug: Connecting to the database $dbname\n" if exists($options{v});
my $dbh = DBI->connect("DBI:mysql:$dbname:$dbhost",$dbuser, $dbpass) ||
	die "# Error: Could not connect to $dbname";

## read status
if (exists($ARGV[0])) {
  open (STATUS, "<$ARGV[0]") or die "# Error: cannot open status file '$ARGV[0]: $?\n";
  while (my $line = <STATUS>) {
    next if ($line =~ /^\s+$/);		# skip blank line
    chomp($line);			# remove LF/CR

    $line =~ s/^\s+//;			# remove leading blanks
    $line =~ s/\s+$//;			# remove tailing blanks

    next if $line =~ /^#/;		# skip comments
    next if $line =~ /^\/\//;		# skip php comments
    next if $line =~ /^<\?php/;		# skip php header
    next if $line =~ /^\?>/;		# skip php tail

    $line =~ s/;$//;			# remove tailing ';'

    my @tmp_list = split /(\s*=\s*)/, $line;	# assume format is "VAR = value"
    ##print $FH "# debug: var='$tmp_list[0]'  sign='$tmp_list[1]'  value='$tmp_list[2]'\n" if exists($options{v});

    $tmp_list[2] =~ s/^'(.*)'$/$1/;	# remove enclosed quote "'"
    $tmp_list[2] =~ s/^"(.*)"$/$1/;	# remove enclosed quote '"'

    if ($tmp_list[0] =~ /status_met\[(\d)\]/) {
      my $id = $1 - 1;
      $status_met[$id] = $tmp_list[2];
      ##print $FH "# debug: status_met[$id] = $status_met[$id]\n" if exists($options{v});
    } # if
    elsif ($tmp_list[0] =~ /status_chem\[(\d)\]/) {
      my $id = $1 - 1;
      $status_chem[$id] = $tmp_list[2];
      ##print $FH "# debug: status_chem[$id] = $status_chem[$id]\n" if exists($options{v});
    } # elsif
    elsif ($tmp_list[0] =~ /status_webcam\[(\d)\]/) {
      my $id = $1 - 1;
      $status_webcam[$id] = $tmp_list[2];
      ##print $FH "# debug: status_webcam[$id] = $status_webcam[$id]\n" if exists($options{v});
    } # elsif
    elsif ($tmp_list[0] =~ /status_skycam\[(\d)\]/) {
      my $id = $1 - 1;
      $status_skycam[$id] = $tmp_list[2];
      ##print $FH "# debug: status_skycam[$id] = $status_skycam[$id]\n" if exists($options{v});
    } # elsif
  } # while

  close STATUS;
} # if
elsif (exists($options{d})) {
  my $sql = "SELECT * FROM $status_table;\n";
  my $sth = $dbh->prepare($sql) or die "# Error: Could not prepare statement: ".$dbh->errstr;
  $sth->execute() or die "# Error: Could not execute statement: ".$sth->errstr;
  my ($id, $site, $type, $status);
  $sth->bind_columns(\$id, \$site, \$type, \$status);
  while ($sth->fetch) {
    if ($type =~ /met/) {
      my $tmp_id = $site - 1;
      $status_met[$tmp_id] = $status;
      $status_id{'met'.$tmp_id.'_met'} = $id;
      print $FH "# debug: status_met[$tmp_id] = $status_met[$tmp_id]\n" if exists($options{v});
    } # if
    elsif ($type =~ /chem/) {
      my $tmp_id = $site - 1;
      $status_chem[$tmp_id] = $status;
      $status_id{'chem'.$tmp_id.'_chem'} = $id;
      print $FH "# debug: status_chem[$tmp_id] = $status_chem[$tmp_id]\n" if exists($options{v});
    } # elsif
    elsif ($type =~ /webcam/) {
      my $tmp_id = $site - 1;
      $status_webcam[$tmp_id] = $status;
      $status_id{'webcam'.$tmp_id.'_webcam'} = $id;
      print $FH "# debug: status_webcam[$tmp_id] = $status_webcam[$tmp_id]\n" if exists($options{v});
    } # elsif
    elsif ($type =~ /skycam/) {
      my $tmp_id = $site - 1;
      $status_skycam[$tmp_id] = $status;
      $status_id{'skycam'.$tmp_id.'_skycam'} = $id;
      print $FH "# debug: status_skycam[$tmp_id] = $status_skycam[$tmp_id]\n" if exists($options{v});
    } # elsif
  } # while
} # elsif
else {
  die "# Error: must specify status file or use '-d'\n";
} # else

# senility check to make sure variables are defined
#for (my $i = 0; $i <= $#table_name_met; $i++) {
#  if (!defined($status_met[$i])) {
#    $status_met[$i] = 'down';		# assume it's down
#  } # if
#  if (!defined($status_chem[$i])) {
#    $status_chem[$i] = 'down';		# assume it's down
#  } # if
#  if (!defined($status_webcam[$i])) {
#    $status_webcam[$i] = 'down';		# assume it's down
#  } # if
#  if (!defined($status_skycam[$i])) {
#    $status_skycam[$i] = 'down';		# assume it's down
#  } # if
#} # for

## get lastest epoch time
for (my $i = 0; $i <= $#table_name_met; $i++) {
  my $sql = "SELECT MAX(epoch) FROM $table_name_met[$i];\n";
  my $sth = $dbh->prepare($sql) or die "# Error: Could not prepare statement: ".$dbh->errstr;
  $sth->execute() or die "# Error: Could not execute statement: ".$sth->errstr;
  $sth->bind_columns(\my $max);
  $sth->fetch;
  $latest_update_met[$i] = $max;
  print $FH "# debug: latest epoch in $table_name_met[$i]: $max\n" if exists($options{v});

  my $sql_chem = "SELECT MAX(epoch) FROM $table_name_chem[$i];\n";
  my $sth_chem = $dbh->prepare($sql_chem) or die "# Error: Could not prepare statement: ".$dbh->errstr;
  $sth_chem->execute() or die "# Error: Could not execute statement: ".$sth_chem->errstr;
  $sth_chem->bind_columns(\my $max_chem);
  $sth_chem->fetch;
  $latest_update_chem[$i] = $max_chem;
  print $FH "# debug: latest epoch in $table_name_chem[$i]: $max_chem\n" if exists($options{v});
} # for

my $current_time = time();
print $FH "# debug: current epoch time = $current_time\n" if exists($options{v});
my $current_threshold = $current_time - $notification_threshold;
print $FH "# debug: current threshold = $current_threshold\n" if exists($options{v});

my $current_skycam_threshold = get_skycam_adjusted_time($current_time) - $notification_threshold;
print $FH "# debug: current skycam threshold = $current_skycam_threshold\n" if exists($options{v});

## check web cam date
for (my $c = 0; $c <= $#path_webcam; $c++) {
  if ( -e $path_webcam[$c] ) {
    $latest_update_webcam[$c] = stat($path_webcam[$c])->mtime;
    print $FH "# debug: file date of '$path_webcam[$c]: $latest_update_webcam[$c]\n" if exists($options{v});
  } # if
} # for

## check web cam date
for (my $s = 0; $s <= $#path_skycam; $s++) {
  if ($s == 0) {	# only MT has skycam
    if ( -e $path_skycam[$s] ) {
      $latest_update_skycam[$s] = stat($path_skycam[$s])->mtime;
      print $FH "# debug: file date of '$path_skycam[$s]: $latest_update_skycam[$s]\n" if exists($options{v});
    } # if
  } # if
  else {
    $latest_update_skycam[$s] = 0;
  } # else
} # for


$subject_string = 'H-NET: ';

## check status
for (my $j = 0; $j <= $#table_name_met; $j++) {
  ## check met data status
  if ($latest_update_met[$j] > 0) {
    if ($latest_update_met[$j] >= $current_threshold) {
      ## update is normal
      if ($status_met[$j] =~ /good/) {
        $status_met_str[$j] = 'Operational';
      } # if
      elsif ($status_met[$j] =~ /down/) {
	$status_met[$j] = 'good';
        $status_met_str[$j] = 'Resume operation';
        $subject_string .= "$location_name_short[$j]: met data: $status_met_str[$j]; ";
      } # elsif
      else {
	# unmatched entry; assume it was down
	print $FH "# debug: unmatch entry for status_met[$j] = '$status_met[$j]'; assume it's down\n" if exists($options{v});
	$status_met[$j] = 'good';
        $status_met_str[$j] = 'Resume operation';
        $subject_string .= "$location_name_short[$j]: met data: $status_met_str[$j]; ";
      } # elsif
      print $FH "# debug: status_met_str[$j] = $status_met_str[$j]\n" if exists($options{v});
    } # if
    else {
      ## didn't get update for 30+ minutes
      $status_met_str[$j] = 'No update since '.epoch_to_datetime($latest_update_met[$j]);
      if ($status_met[$j] =~ /good/) {
        $subject_string .= "$location_name_short[$j]: met data: $status_met_str[$j]; ";
      } # if
      elsif ($status_met[$j] !~ /down/) {
	## it's not "down" and unmatched entry
        $subject_string .= "$location_name_short[$j]: met data: $status_met_str[$j]; ";
      } # elsif
      $status_met[$j] = 'down';
      print $FH "# debug: status_met_str[$j] = $status_met_str[$j]\n" if exists($options{v});
    } # else
  } # if
  else {
    die "# Error: invalid value in latest_update_met[$j]='$latest_update_met[$j]\n";
  } # else

  ## check chem data status
  if ($latest_update_chem[$j] > 0) {
    if ($latest_update_chem[$j] >= $current_threshold) {
      ## update is normal
      if ($status_chem[$j] =~ /good/) {
        $status_chem_str[$j] = 'Operational';
      } # if
      elsif ($status_chem[$j] =~ /down/) {
	$status_chem[$j] = 'good';
        $status_chem_str[$j] = 'Resume operation';
        $subject_string .= "$location_name_short[$j]: chem data: $status_chem_str[$j]; ";
      } # elsif
      else {
	# no match; assume it was down
	print $FH "# debug: unmatch entry for status_chem[$j] = '$status_chem[$j]'; assume it's down\n" if exists($options{v});
	$status_chem[$j] = 'good';
        $status_chem_str[$j] = 'Resume operation';
        $subject_string .= "$location_name_short[$j]: chem data: $status_chem_str[$j]; ";
      } # elsif
      print $FH "# debug: status_chem_str[$j] = $status_chem_str[$j]\n" if exists($options{v});
    } # if
    else {
      ## didn't get update for 30+ minutes
      $status_chem_str[$j] = 'No update since '.epoch_to_datetime($latest_update_chem[$j]);
      if ($status_chem[$j] =~ /good/) {
        $subject_string .= "$location_name_short[$j]: chem data: $status_chem_str[$j]; ";
      } # if
      elsif ($status_chem[$j] !~ /down/) {
	## it's not down and unmatched entry
        $subject_string .= "$location_name_short[$j]: chem data: $status_chem_str[$j]; ";
      } # if
      $status_chem[$j] = 'down';
      print $FH "# debug: status_chem_str[$j] = $status_chem_str[$j]\n" if exists($options{v});
    } # else
  } # if
  else {
    die "# Error: invalid value in latest_update_chem[$j]='$latest_update_chem[$j]\n";
  } # else

  ## check webcam file status
  if ($latest_update_webcam[$j] > 0) {
    if ($latest_update_webcam[$j] >= $current_threshold) {
      ## update is normal
      if ($status_webcam[$j] =~ /good/) {
        $status_webcam_str[$j] = 'Operational';
      } # if
      elsif ($status_webcam[$j] =~ /down/) {
	$status_webcam[$j] = 'good';
        $status_webcam_str[$j] = 'Resume operation';
        $subject_string .= "$location_name_short[$j]: webcam file: $status_webcam_str[$j]; ";
      } # elsif
      else {
	# no match; assume it was down
	print $FH "# debug: unmatch entry for status_webcam[$j] = '$status_webcam[$j]'; assume it's down\n" if exists($options{v});
	$status_webcam[$j] = 'good';
        $status_webcam_str[$j] = 'Resume operation';
        $subject_string .= "$location_name_short[$j]: webcam file: $status_webcam_str[$j]; ";
      } # elsif
      print $FH "# debug: status_webcam_str[$j] = $status_webcam_str[$j]\n" if exists($options{v});
    } # if
    else {
      ## didn't get update for 30+ minutes
      $status_webcam_str[$j] = 'No update since '.epoch_to_datetime($latest_update_webcam[$j]);
      if ($status_webcam[$j] =~ /good/) {
        $subject_string .= "$location_name_short[$j]: webcam file: $status_webcam_str[$j]; ";
      } # if
      elsif ($status_webcam[$j] !~ /down/) {
	## it's not down and unmatched entry
        $subject_string .= "$location_name_short[$j]: webcam file: $status_webcam_str[$j]; ";
      } # if
      $status_webcam[$j] = 'down';
      print $FH "# debug: status_webcam_str[$j] = $status_webcam_str[$j]\n" if exists($options{v});
    } # else
  } # if
  else {
    die "# Error: invalid value in latest_update_webcam[$j]='$latest_update_webcam[$j]\n";
  } # else

  ## check skycam file status
  if ($latest_update_skycam[$j] > 0) {
    if ($latest_update_skycam[$j] >= $current_skycam_threshold) {
      ## update is normal
      if ($status_skycam[$j] =~ /good/) {
        $status_skycam_str[$j] = 'Operational';
      } # if
      elsif ($status_skycam[$j] =~ /down/) {
	$status_skycam[$j] = 'good';
        $status_skycam_str[$j] = 'Resume operation';
        $subject_string .= "$location_name_short[$j]: skycam file: $status_skycam_str[$j]; ";
      } # elsif
      else {
	# no match; assume it was down
	print $FH "# debug: unmatch entry for status_skycam[$j] = '$status_skycam[$j]'; assume it's down\n" if exists($options{v});
	$status_skycam[$j] = 'good';
        $status_skycam_str[$j] = 'Resume operation';
        $subject_string .= "$location_name_short[$j]: skycam file: $status_skycam_str[$j]; ";
#	die "# Error: unknow status_skycam[$j] = $status_skycam[$j]\n";
      } # else
      print $FH "# debug: status_skycam_str[$j] = $status_skycam_str[$j]\n" if exists($options{v});
    } # if
    else {
      ## didn't get update for 30+ minutes
      $status_skycam_str[$j] = 'No update since '.epoch_to_datetime($latest_update_skycam[$j]);
      if ($status_skycam[$j] =~ /good/) {
        $subject_string .= "$location_name_short[$j]: skycam file: $status_skycam_str[$j]; ";
      } # if
      elsif ($status_skycam[$j] !~ /down/) {
	## it's not down and unmatched entry
        $subject_string .= "$location_name_short[$j]: skycam file: $status_skycam_str[$j]; ";
      } # elsif
#      else {
#	die "# Error: unknow status_skycam[$j] = $status_skycam[$j]\n";
#      } # else
      $status_skycam[$j] = 'down';
      print $FH "# debug: status_skycam_str[$j] = $status_skycam_str[$j]\n" if exists($options{v});
    } # else
  } # if
  elsif ($j > 0) {
    ##print $FH "# debug: skip skycam for site $location_name_short[$j]\n";
    $status_skycam[$j] = 'good';
    $status_skycam_str[$j] = 'Operational';
  } # elsif
  else {
    die "# Error: invalid value in latest_update_skycam[$j]='$latest_update_skycam[$j]'\n";
  } # else

} # for

print $FH "# debug: subject_string = '$subject_string'\n" if exists($options{v});

if (exists($ARGV[0])) {
  print $FH "# debug: output status file '$ARGV[0]'\n" if exists($options{v});
  output_status_file();
} # if

## email warning message
if (length($subject_string) > 8) {
  email_warning($subject_string);
} # if

## generate status php file
if (exists($options{w})) {
  open (PHP, ">$options{w}") or die "# Error: cannot write to '$options{w}': $?\n";
  print PHP "<?php\n";
  print PHP "?>\n";
  print PHP <<__html1__;
<table border=1 cellpadding=5>
  <tr>
    <td><b>Site</b></td>
    <td><b>Type</b></td>
    <td><b>Status</b></td>
    <td><b>Last update</b></td>
  </tr>
__html1__
  for (my $w = 0; $w <= $#table_name_met; $w++) {
    ## met data
    print PHP "  <tr>\n";
    if ($w == 0) {  ## only MT has sky cam
      print PHP "    <td rowspan=4>$location_name_short[$w]</td>\n";
    } # if
    else {
      print PHP "    <td rowspan=3>$location_name_short[$w]</td>\n";
    } # else
    print PHP "    <td>Met data</td>\n";
    if ($status_met[$w] =~ /good/) {
      print PHP "    <td align=center><img src=\"/images/green_arrow_up_sm.png\"></td>\n";
    } # if
    elsif ($status_met[$w] =~ /down/) {
      print PHP "    <td align=center><img src=\"/images/red_arrow_down_sm.png\"></td>\n";
    } # elsif
    else {
      print PHP "    <td>Error</td>\n";
    } # else
    print PHP "    <td>".epoch_to_datetime($latest_update_met[$w])."</td>\n";
    print PHP "  </tr>\n";

    ## chem data
    print PHP "  <tr>\n";
    print PHP "    <td>Chem data</td>\n";
    if ($status_chem[$w] =~ /good/) {
      print PHP "    <td align=center><img src=\"/images/green_arrow_up_sm.png\"></td>\n";
    } # if
    elsif ($status_chem[$w] =~ /down/) {
      print PHP "    <td align=center><img src=\"/images/red_arrow_down_sm.png\"></td>\n";
    } # elsif
    else {
      print PHP "    <td>Error</td>\n";
    } # else
    print PHP "    <td>".epoch_to_datetime($latest_update_chem[$w])."</td>\n";
    print PHP "  </tr>\n";

    ## web cam file
    print PHP "  <tr>\n";
    print PHP "    <td>Webcam file</td>\n";
    if ($status_webcam[$w] =~ /good/) {
      print PHP "    <td align=center><img src=\"/images/green_arrow_up_sm.png\"></td>\n";
    } # if
    elsif ($status_webcam[$w] =~ /down/) {
      print PHP "    <td align=center><img src=\"/images/red_arrow_down_sm.png\"></td>\n";
    } # elsif
    else {
      print PHP "    <td>Error</td>\n";
    } # else
    print PHP "    <td>".epoch_to_datetime($latest_update_webcam[$w])."</td>\n";
    print PHP "  </tr>\n";

    ## sky cam file
    if ($w == 0) {  ## only MT has sky cam
      print PHP "  <tr>\n";
      print PHP "    <td>Skycam file</td>\n";
      if ($status_skycam[$w] =~ /good/) {
        print PHP "    <td align=center><img src=\"/images/green_arrow_up_sm.png\"></td>\n";
      } # if
      elsif ($status_skycam[$w] =~ /down/) {
        print PHP "    <td align=center><img src=\"/images/red_arrow_down_sm.png\"></td>\n";
      } # elsif
      else {
        print PHP "    <td>Error</td>\n";
      } # else
      print PHP "    <td>".epoch_to_datetime($latest_update_skycam[$w])."</td>\n";
      print PHP "  </tr>\n";
    } # if
  } # for

  print PHP <<__html2__;
</table>
__html2__
  print PHP "<br><center><i>Updated: ".epoch_to_datetime(time())."</i></center><br>\n";
} # if

close $FH;
exit 0;

#------------------------------------
#
# convert epoch to datetime string
#
sub epoch_to_datetime {

  my ($epoch) = @_;

  my ($sec, $min, $hour, $day, $month, $year) = (localtime($epoch))[0,1,2,3,4,5,6];
  my $datetime_str = sprintf "%d/%02d/%02d.%02d:%02d:%02d", $year+1900, $month+1, $day, $hour, $min, $sec;

  return $datetime_str;
} # sub epoch_to_datetime

#------------------------------------
#
# get current skycam threshold
#
sub get_skycam_adjusted_time {

  my ($epoch) = @_;

  my ($sec, $min, $hour, $day, $month, $year) = (localtime($epoch))[0,1,2,3,4,5,6];

  ## assume skycam operate between 6 to midnight
  if ($hour <= 6) {
    my $adj_epoch = timelocal(0, 0, 0, $day, $month, $year);
    print $FH "# debug: adjust sky cam time to ".epoch_to_datetime($adj_epoch)."\n" if exists($options{v});
    return $adj_epoch;
  } # if
  else {
    return $epoch;
  } # else

} # sub get_skycam_adjusted_time

#------------------------------------
#
# output status file
#
sub output_status_file {
  ## rename status file
  my $cmd = "/bin/mv -f $ARGV[0] $ARGV[0].old";
  my $status = system($cmd);
  die "# Error: cannot rename status file with command '$cmd': $?\n" unless $status == 0;

  ## write output to status file
  open (OUT, ">$ARGV[0]") or die "# Error: cannot write to '$ARGV[0]': $?\n";
  print OUT "<?php\n";
  print OUT "// status file -- auto generated by $0 on ".epoch_to_datetime(time())."\n\n";
  print OUT "// status for met data\n";
  for (my $k = 0; $k <= $#status_met; $k++) {
    printf OUT "\$status_met[%d] = '%s';\n", $k+1, $status_met[$k];
  } # for
  print OUT "\n// status for chem data\n";
  for (my $k2 = 0; $k2 <= $#status_chem; $k2++) {
    printf OUT "\$status_chem[%d] = '%s';\n", $k2+1, $status_chem[$k2];
  } # for
  print OUT "\n// status for webcam\n";
  for (my $k3 = 0; $k3 <= $#status_webcam; $k3++) {
    printf OUT "\$status_webcam[%d] = '%s';\n", $k3+1, $status_webcam[$k3];
  } # for
  print OUT "\n// status for skycam\n";
  for (my $k4 = 0; $k4 <= $#status_webcam; $k4++) {
    printf OUT "\$status_skycam[%d] = '%s';\n", $k4+1, $status_skycam[$k4];
  } # for
  print OUT "\n?>\n";
} # sub output_status_file

#------------------------------------
#
# email warning message
#
sub email_warning {
  my ($subject) = @_;
  my $mail_prog = '/bin/mail';
  my $msg = 'H-NET site status as '.epoch_to_datetime(time())."\n\n";

  for (my $i = 0; $i <= $#status_webcam; $i++) {
    $msg .= "$location_name_short[$i]:\t met data:\t$status_met_str[$i]\n";
    $msg .= "$location_name_short[$i]:\t chem data:\t$status_chem_str[$i]\n";
    $msg .= "$location_name_short[$i]:\t webcam file:\t$status_webcam_str[$i]\n";
    if ($i == 0) {
      $msg .= "$location_name_short[$i]:\t skycam file:\t$status_skycam_str[$i]\n";
    } # if
    $msg .= "\n";
  } # for

  my $cmd_mail = "echo \"$msg\" | $mail_prog -s \"$subject\"";

  $cmd_mail .= " $email_list";

  print $FH "# email_list = '$email_list'\n" if exists($options{v});
  print $FH "# email cmd = '$cmd_mail'\n" if exists($options{v});

  if (!exists($options{m})) {
    my $status = system($cmd_mail);
    die "# Error: cannot email the warning message '$msg' to '$email_list': $?\n" unless $status == 0;
  } # if
  else {
    print "# debug: ($subject): '$msg' - not sent via e-mail\n" if exists($options{v});
  } # else
} # sub email_warning


#------------------------------------
#
# usage subroutine
#
sub usage {

  print $FH "Usage: $0 [status_file]\n\n";
  print $FH <<__usage__;
  -d		use database for configuration/status
  -h		print usage (this message)
  -m		skip email warning message
  -o outfile	write output to outfile instead of STDOUT
  -v		verbose output
  -w php_file	generate status php file
__usage__
  exit 1;
} # sub usage
