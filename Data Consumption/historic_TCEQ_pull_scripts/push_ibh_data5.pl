#!/usr/bin/perl

#
# Push data_extractor raw data file to database, with state for input files
#
# Created: 09/02/2011
# Modified: 07/21/2012
#
# Author: T. Mark Huang
#
#

use strict;
use Getopt::Std;	# command line option
use File::Path qw(make_path);
use DBI; 		# use dbi for database connection
#use Time::localtime;	# for converting epoch time
use Time::Local 'timegm';	# for converting date/time to epoch

# change these variables for different cluster

  # database user id
  my $dbuser = "ibhworker";

  # database password
  my $dbpass = "*****";

  # database hosting machine name
  my $dbhost = "localhost";

  # database name
  my $dbname = "ibreathedb";

  # DBI handler
  my $dbh;

  # table name
  my $table_prefix = 'ibh_';
  ##my $table_prefix = 'ibhtest_';
  my $table_base = $table_prefix.'data_year_';
  my $txn_tbl_base = $table_prefix.'txn_year_';
  my $table;

  my $state_dir = '/mnt/ibreathe/TCEQ/state';	# top level state dir
  my $state_file_prefix = 'ibh_state';		# file name pattern: 'yyyy/yyyy-mm/$state_file_prefix.yyyy-mm-dd.txt'
  my %state_file_hash;				# hash for state files
  my %state_hash;				# hash for storing state of data files
  my %path_hash;				# hash for storing path of input file

  my %changed_epoch_hash;			# hash for epoch of changed data
  my $no_affected_epoch = 6;			# no of epoch got affected
  my $counter_regen0 = 0;			# no of data point regenerated for band schema 0
  my $counter_regen4 = 0;			# no of data point regenerated for band schema 4

  my $grid_gen_script = '/var/www/html/test/ozonemaps/api/tools/calculategrid.php';		# grid / contour generating script

my %inst_mapping;				# hash for instrument mapping
  $inst_mapping{'o3'} = 44201;
  $inst_mapping{'temp'} = 62101;
  $inst_mapping{'windspd'} = 61103;
  $inst_mapping{'winddir'} = 61104;
  $inst_mapping{'humid'} = 62201;
  $inst_mapping{'pm25'} = 88502;
  $inst_mapping{'solar'} = 63301;

  $inst_mapping{44201} = 'o3';
  $inst_mapping{62101} = 'temp';
  $inst_mapping{61103} = 'windspd';
  $inst_mapping{61104} = 'winddir';
  $inst_mapping{62201} = 'humid';
  $inst_mapping{88502} = 'pm25';
  $inst_mapping{63301} = 'solar';

my %flag_mapping;	# mapping for flag abbreviation
  $flag_mapping{'OK'} = 'K';
  $flag_mapping{'NA'} = 'N';
  $flag_mapping{'LST'} = 'T';
  $flag_mapping{'LIM'} = 'L';
  $flag_mapping{'PMA'} = 'P';
  $flag_mapping{'CAL'} = 'C';
  $flag_mapping{'SPN'} = 'H';
  $flag_mapping{'SPZ'} = 'Q';
  $flag_mapping{'QAS'} = 'A';
  $flag_mapping{'QRE'} = 'R';
  $flag_mapping{'AQI'} = 'V';
  $flag_mapping{'MAL'} = 'B';
  $flag_mapping{'NOL'} = 'O';
  $flag_mapping{'FEW'} = 'F';
  $flag_mapping{'NEG'} = 'E';
  $flag_mapping{'MUL'} = 'U';
  $flag_mapping{'NOD'} = 'D';

my %skip_site;		# sites to be skipped
  $skip_site{6600} = 1;		# Houston Kinder Morgan NE C6600
  $skip_site{6601} = 1;		# Houston Kinder Morgan SW C6601
  $skip_site{6602} = 1;		# CAPCOG Hutto College Street C6602

my %counter;		# counter for number of entries, updates
  $counter{'total_row'} = 0;	# no of rows (5 min per row)
  $counter{'total_entry'} = 0;	# no of entries (rows x sites)
  $counter{'total_new'} = 0;	# no of new data
  $counter{'total_update'} = 0;	# no of updates/changes
  $counter{'total_file'} = 0;	# no of input files
  $counter{'total_file_seen'} = 0;	# no of input files that was processed before
  $counter{'total_file_valid'} = 0;	# no of input files with valid data
  $counter{'LST'} = 0;		# no of LST
  $counter{'LIM'} = 0;		# no of LIM
  $counter{'QAS'} = 0;		# no of QAS

my $more_debug = 0;	# more debug message if $more_debug = 1
my $db_trace = 0;	# show databae trace info if $db_trace = 1

my %options;		# hash used for command line option
my $FH = *STDOUT;	# used for output redirection

# setup commandline options
getopts("DdFghNo:s:STt:v", \%options);

usage() if exists($options{h}) || !(exists($options{o}) ||
	exists($options{D}) || exists($options{d}) || exists($options{v}) ||
	exists($options{T}) || exists($options{t}) || exists($options{N}) ||
	exists($options{F}) || exists($options{s}) || exists($options{S}) ||
	exists($options{g}) || 
	exists($ARGV[0]) );

if (exists($options{o})) {
  open (OUTPUT, ">>$options{o}") or die "Couldn't write to '$options{o}': $!\n";
  $FH = *OUTPUT;
} # if

if (exists($options{s})) {
  $state_dir = $options{s};
  print $FH "# debug: overwrite state dir with '$state_dir'\n" if exists($options{v});
} # if
else {
  print $FH "# debug: use state dir '$state_dir'\n" if exists($options{v});
} # else

if (exists($options{D})) {
  $more_debug = 1;
  print $FH "# debug: turn on 'more_debug' .......\n" if exists($options{v});
} # if

if (exists($options{d})) {
  print $FH "Connecting to the database '$dbname'\n" if exists($options{v});
  $dbh = DBI->connect("DBI:mysql:$dbname:$dbhost", $dbuser, $dbpass) ||
      die "# Error: Could not connect to database '$dbname': $?\n";
  DBI->trace(1) if exists($options{v}) && $more_debug && $db_trace;
} # if

FILE_LOOP: for (my $v = 0; $v <= $#ARGV; $v++) {
  my $input_file = $ARGV[$v];
  my $input_filename = $input_file;
  $input_filename =~ s/^.*\///;			# remvoe path
  my $input_filename_wo_gz = $input_filename;
  $input_filename_wo_gz =~ s/.gz$//;		# remove tailing .gz
  print $FH "# debug: file name = '$input_filename'\n" if exists($options{v});

  my $input_path = $input_file;
  if ($input_file =~ /\//) {
    $input_path =~ s/^(.*)\/.*/$1/;
  } # if
  else {
    $input_path = './';
  } # else
  $path_hash{$input_path} = 1;

  my $input_file_date;				# data date of input file (part of input file name)
  my $state_file;				# state file name

  if ($input_filename =~ /^\w+\.(\d{4}-\d{2})\.\d{9,10}/) {
    # sample input: o3.2011-05.1314818815.txt.gz
    $input_file_date = $1.'-01';		# monthly data: use 1st day of month
    $state_file = "$state_dir/".substr($input_file_date,0,4)."/$input_file_date/$state_file_prefix.".$input_file_date.'.txt';
    print $FH "# debug:   state_file = '$state_file'\n" if exists($options{v});
  } # if
  elsif ($input_filename =~ /^\w+\.(\d{4}-\d{2}-\d{2})\.\d+d/) {
    # sample input: o3.2011-10-22.2d.1319500501.txt
    $input_file_date = $1;
    $state_file = "$state_dir/".substr($input_file_date,0,4).'/'.substr($input_file_date,0,7)."/$state_file_prefix.".$input_file_date.'.txt';
    print $FH "# debug:   state_file = '$state_file'\n" if exists($options{v});
  } # elsif
  else {
    # mismatch/unknown date
    $input_file_date = 'unknown';
    $state_file = "$state_dir/$state_file_prefix.unknown.txt";
    print $FH "# debug:   state_file = '$state_file'\n" if exists($options{v});
  } # else

  $counter{'total_file'} ++;

  # check state
  if (! exists($options{F})) {

    # check if state file has been read
    if (! exists($state_file_hash{$input_file_date})) {
      # read state file
      if ( -e $state_file ) {
        open(STATE, "<$state_file") or warn "# Warning: cannot open state file '$state_file': $?\n";
        while (my $line = <STATE>) {
          next if $line =~ /^#/;
          next if $line =~ /^\s+$/;
          chomp($line);
          my @tmp_list = split /,/, $line;
          my $filename = $tmp_list[0];
          $filename =~ s/^.*\///;		# remove path

          if (length($tmp_list[1]) > 0) {
            $state_hash{$filename} = $tmp_list[1];
          } # if
          else {
            $state_hash{$filename} = 1;
          } # else
        } # while
        close STATE;
        $state_file_hash{$input_file_date} = 1;
      } # if
    } # if
    
    if (exists($state_hash{$input_filename_wo_gz})) {
      print $FH "# debug: skipping input file '$input_file' which was processed at ".
	epoch_to_datetime($state_hash{$input_filename_wo_gz}).
	" ($state_hash{$input_filename_wo_gz})\n" if exists($options{v});
      $counter{'total_file_seen'} ++;
      next;
    } # if
  } # if
  else {
    print $FH "# debug: skipping checking state for input file '$input_file'\n" if exists($options{v});
  } # else

  my $inst_id;		# instrument ID
  my $inst_type;	# instrument type
  my $inst_unit;	# instrument unit
  my $time_base;	# time base

  my @header_list;	# list for header (w/ instrument id removed)
  my @site_list;	# list for sites listed in the header
  my @action_list;	# list for action for $site_list[$i]: action/push if = 1;
  my %site_hash;	# hash for seen sites
  my %CPU_usage;	# CPU usage

  my $table_name;	# data table name
  my $prev_table_name;	# record previous table name

  my $download_epoch;	# raw data file download epoch time; set by file name, options{t} or current time
  my $txn_tbl_name;	# transaction table name

  my %dbh_hash;		# hash for DB handlers;

  # reset counter
  $counter{'row'} = 0;		# no of rows (5 min per row)
  $counter{'entry'} = 0;	# no of entries (rows x sites)
  $counter{'new'} = 0;		# no of new data
  $counter{'update'} = 0;	# no of updates/changes

  # check for accounting file
  die "Error: CSV file '$input_file' not found.\n" if ! -e $input_file;

  print $FH "# debug: Using file '$input_file' as input\n" if exists($options{v});

  # read in the accounting file
  if ($input_file !~ /gz$/) {
    open(INPUT,"$input_file") || die "Could not open file '$input_file': $?\n";
  } # if
  else {
    open(INPUT,"gzip -dc $input_file |") || die "Could not unpack file '$input_file': $?\n";
  } # else

  # set download epoch time
  if ($input_file =~ /\.(\d{9,10}).txt$/ || $input_file =~ /\.(\d{9,10}).txt.gz$/) {
    $download_epoch = $1;
    print $FH "# debug: data download epoch time is extracted from file name '$input_file' and set to ".epoch_to_datetime($download_epoch)." ($download_epoch)\n" if exists($options{v});
    ##print $FH "# debug: data download epoch time is extracted from file name '$input_file' and set to ".epoch_to_GMT_datetime($download_epoch)." GMT ($download_epoch)\n" if exists($options{v});
  } # if
  else {
    $download_epoch = time();
    print $FH "# debug: data download epoch time is set with current time to ".epoch_to_datetime($download_epoch)." ($download_epoch)\n" if exists($options{v});
  } # else
  if (exists($options{T})) {
    $download_epoch = time();
    print $FH "# debug: data download epoch time is overwritten (T) with current time to ".epoch_to_datetime($download_epoch)." ($download_epoch)\n" if exists($options{v});
  } # if
  elsif (exists($options{t})) {
    $download_epoch = $options{t};
    print $FH "# debug: data download epoch time is overwritten with options (t) to ".epoch_to_datetime($download_epoch)." ($download_epoch)\n" if exists($options{v});
  } # if

  my $line;		# input line

  while ($line = <INPUT>) {
    last if $line =~ /Date,Time/i;	# break out while loop when reaching header
    last if $line =~ /^## time spent/;	# break out while loop when reaching end of file download
    next if $line !~ /Parameter ID/ && $line !~ /Parameter Units/ && $line !~ /Time base/;	# skip until see 
    chomp($line);
    $line =~ s/^\s+//;			# remove leading blanks
    my @tmp_list = split /\s+/, $line;
    if ($line =~ /Parameter ID/i) {
      $inst_id = $tmp_list[2];
      if (exists($inst_mapping{$inst_id})) {
        $inst_type = $inst_mapping{$inst_id};
        print $FH "# debug: found instrument ($inst_id) = '$inst_type'\n" if exists($options{v});
      } # if
      else {
        die "# Error: cannot find matching instrument id ($inst_id)\n";
      } # else
    } # if
    elsif ($line =~ /Parameter Units/i) {
      $inst_unit = $tmp_list[2];
      print $FH "# debug: found instrument unit = '$inst_unit'\n" if exists($options{v});
    } # elsif
    elsif ($line =~ /Time base/i) {
      $time_base = $tmp_list[2];
      print $FH "# debug: found time base = '$time_base'\n" if exists($options{v});
    } # elsif
  } # while

  chomp($line);
  if ($line =~ /^\s+Date,Time,/i) {
    $line =~ s/^\s+//;		# remove leading blanks
    $line =~ s/\s+$//;		# remove tailing blanks
    my @tmp_list = split/,/, $line;
    for (my $j = 2; $j <= $#tmp_list; $j++) {
      if ($tmp_list[$j] =~ /^C(\d+)_(\d+)_(\d+)$/) {		# C8_62201_1
	my $tmp_site = $1;
	my $tmp_inst_id = $2;
	my $tmp_id = $3;

	if ($tmp_inst_id != $inst_id) {
	  die "# Error: mismatch instrument id ($tmp_inst_id != $inst_id) in header '$tmp_list[$j]'\n";
	} # if

	$site_list[$j] =  $tmp_site;
	$header_list[$j] = 'C'.$tmp_site.'_'.$tmp_id;
	if (! exists($site_hash{$tmp_site})) {			# set action
	  $site_hash{$tmp_site} = 1;
	} # if
	else {
	  $site_hash{$tmp_site} ++;
	} # else
	if (! exists($skip_site{$tmp_site})) {
	  $action_list[$j] = $site_hash{$tmp_site};
	} # if
	else {
	  $action_list[$j] = $site_hash{$tmp_site} * -1;
	} # else
      } # if
      elsif ($tmp_list[$j] =~ /^C(\d+)_(\d+)$/) {		# C8_1
	my $tmp_site = $1;
	my $tmp_id = $2;

	$site_list[$j] = $tmp_site;
	$header_list[$j] = 'C'.$tmp_site.'_'.$tmp_id;
	if (! exists($site_hash{$tmp_site})) {			# set action
	  $site_hash{$tmp_site} = 1;
	} # if
	else {
	  $site_hash{$tmp_site} ++;
	} # else
	if (! exists($skip_site{$tmp_site})) {
	  $action_list[$j] = $site_hash{$tmp_site};
	} # if
	else {
	  $action_list[$j] = $site_hash{$tmp_site} * -1;
	} # else
      } # elsif
      else {
	die "# Error: unknown header format '$tmp_list[$j]' in '$line'\n";
      } # else
    } # for
  } # if
  elsif ($line =~ /# time spent/) {
    warn "# Error: expecting header line containing 'Date,Time', but reaching end of download '$line'; skip processing '$input_file'\n";
    save_input_file_state($state_file, $input_file, $input_filename_wo_gz);
    next FILE_LOOP;
  } # elsif
  else {
    # input line does not match '/Date,Time,/', check if the file is download completely
    my $last_line;
    while ($last_line = <INPUT>) {
      if ($last_line =~ /# time spent/) {
	last;
      } # if
    } # while
    
    if ($last_line !~ /# time spent/) {
      chomp($last_line);
      warn "# Warn: input file '$input_file' was not download completely (last line = '$last_line'); skip processing ...\n";
      next FILE_LOOP;
    } # if
    else {
      warn "# Error: expecting header line containing 'Date,Time', but got '$line'; skip processing '$input_file'\n";
      save_input_file_state($state_file, $input_file, $input_filename_wo_gz);
      next FILE_LOOP;
    } # else
  } # else

  if (exists($options{v}) && $more_debug) {
    print $FH "# debug: header list: ".(keys %site_hash)." sites\n";
#    foreach my $s (sort { $a <=> $b } keys %site_hash) {
#      print $FH "# debug:    header site [$s] : $site_hash{$s}\n";
#    } # foreach
    for (my $k = 2; $k <= $#header_list; $k++) {
      print $FH "# debug:    header [$k] = '$header_list[$k]' : $action_list[$k]\n";
    } # for
  } # if

  while ($line = <INPUT>) {
    next if $line =~ /^\s+$/;		# skip blank line
    next if $line =~ /CPU Usage/;	# skip header

    chomp($line);
    $line =~ s/^\s+//;			# remove leading blanks
    $line =~ s/\s+$//;			# remove tailing blanks

    if ($line =~ /User:/) {
      # sample input: "User: 7.69    System: 0.97     Child_User: 7.58     Child_System: 2.88"
      my @tmp_list = split /\s+/, $line;
      $CPU_usage{'User'} = $tmp_list[1];
      $CPU_usage{'System'} = $tmp_list[3];
      $CPU_usage{'Child_User'} = $tmp_list[5];
      $CPU_usage{'Child_System'} = $tmp_list[7];
      next;
    } # if
    elsif ($line =~ /Total CPU time/) {
      # sample input: "Total CPU time: 19.12 seconds"
      my @tmp_list = split /\s+/, $line;
      $CPU_usage{'Total_CPU_time'} = $tmp_list[3];
      next;
    } # elsif
    elsif ($line =~ /Total CPU charge/) {
      # sample input: "Total CPU charge: $1.27"
      my @tmp_list = split /\s+/, $line;
      $CPU_usage{'Total_CPU_charge'} = $tmp_list[3];
      $CPU_usage{'Total_CPU_charge'} =~ s/^\$//;	# remove '$' sign
      last;
    } # elsif
    elsif ($line =~ /^References/) {
      # sample input: "References"
      print $FH "# Warning: no CPU time info; got '$line' instead\n" if exists($options{v});
      last;
    } # elsif

    my @tmp_list = split /,/, $line;

#    if (exists($options{v})) {
#      print $FH "# debug: line = '$line'\n";
#      for (my $i = 0; $i <= $#tmp_list; $i++) {
#        print $FH "# debug:    item[$i] = '$tmp_list[$i]'\n";
#      } # for
#    } # if

    ## convert date/time to epoch
    my ($year, $month, $day, $hour, $min, $sec);

    if ($tmp_list[0] =~ /(\d{2})-(\d{2})-(\d{4})/) {	# MM-DD-YYYY
      $month = $1;
      $day = $2;
      $year = $3;
    } # if
    elsif ($tmp_list[0] =~ /(\d{4})(\d{2})(\d{2})/) {	# YYYYMMDD
      $year = $1;
      $month = $2;
      $day = $3;
    } # elsif
    else {
      die "# Error: unmatched date format '$tmp_list[0]' for line '$line'\n";
    } # else

    if ($tmp_list[1] =~ /(\d{2}):(\d{2})/) {		# hh:mm
      $hour = $1;
      $min = $2;
    } # if
    elsif ($tmp_list[1] =~ /(\d{2})(\d{2})/) {		# hhmm
      $hour = $1;
      $min = $2;
    } # if
    else {
      die "# Error: unmatched time format '$tmp_list[1]' for line '$line'\n";
    } # else

    $sec = 0;

    my $my_epoch = timegm($sec,$min,$hour,$day,$month-1,$year); 

    print $FH "# debug: '$tmp_list[0] $tmp_list[1]' ==> epoch = $my_epoch\n" if exists($options{v}) && $more_debug;

    $table_name = $table_base.$year;
    print $FH "# debug: table_name = '$table_name';  prev_table_name = '$prev_table_name'\n" if exists($options{v}) && $more_debug;
    $txn_tbl_name = $txn_tbl_base.$year;
    print $FH "# debug: txn_tbl_name = '$txn_tbl_name'\n" if exists($options{v}) && $more_debug;

    if ($prev_table_name ne $table_name) {
      if (exists($options{d})) {
	# set up table and create SQL commands
	set_table_sql_cmd($table_name, $txn_tbl_name, $year, $inst_type, \%dbh_hash);
      } # if
    } # if
    else {
      print $FH "# debug: same table name = '$table_name'\n" if exists($options{v}) && $more_debug;
    } # else


    for (my $w = 2; $w <=$#tmp_list; $w++) {
      next if $action_list[$w] != 1;		# skip site <> 1; skip sites 603_2, 603_3 and 600*

      my $flag_raw;		# unabbreviated/mapped flag (3 char)
      my $flag;			# mapped flag (1 char)
      my $value;		# final value)

      if ($tmp_list[$w] =~ /^[-+]?[0-9]*\.?[0-9]+$/) {
	$flag = 'K';
	$value = $tmp_list[$w];
	print $FH "# debug:   raw '$tmp_list[0] $tmp_list[1]' ($my_epoch) ; site = $site_list[$w] ; value = '$tmp_list[$w]'\n" if exists($options{v}) && $more_debug;
      } # if
      elsif ($tmp_list[$w] =~ /^([-+]?[0-9]*\.?[0-9]+)\s+\[(\w+)\]$/) {
	$value = $1;
	$flag_raw = $2;
	if (exists($flag_mapping{$flag_raw})) {
	  $flag = $flag_mapping{$flag_raw};
	} # if
	else {
	  die "# Error: cannot find flag mapping for '$flag' @ line '$line'\n";
	} # else
	print $FH "# debug:   raw '$tmp_list[0] $tmp_list[1]' ($my_epoch) ; site = $site_list[$w] ; value = '$value' w/ flag='$flag_raw'\n" if exists($options{v}) && $more_debug;
      } # elsif
      elsif ($tmp_list[$w] =~ /^LST$/) {
	$value = '';
	$flag_raw = $tmp_list[$w];
	$flag = $flag_mapping{'LST'};
	print $FH "# debug:   raw '$tmp_list[0] $tmp_list[1]' ($my_epoch) ; site = $site_list[$w] ; flag = '$tmp_list[$w]'\n" if exists($options{v}) && $more_debug;
      } # elsif
      else {
	print $FH "# Warning:   mismatched raw '$tmp_list[0] $tmp_list[1]' ($my_epoch) ; site = $site_list[$w] ; raw date = '$tmp_list[$w]'\n" if exists($options{v});
      } # else

      ## push/update data/flag into database
      if (exists($options{d})) {
	push_data_into_database($my_epoch, $site_list[$w], $inst_type, $value, $flag, $download_epoch, \%dbh_hash);
      } # if
      $counter{'entry'} ++;
      $counter{'total_entry'} ++;
    } # for

#    if (exists($options{d})) {
#      my $success = 1;
#      #$success &&= $dbh_insertion->execute($tmp_list[0], $tmp_list[1], $tmp_list[2], $tmp_list[3]);
#      #my $result = ($success ? $dbh->commit : $dbh->rollback);
#      unless ($success) {
#        die "# Error: cannot finish insertion for '$line': " . $dbh->errstr;
#      }
#    } # if

    $prev_table_name = $table_name;
    $counter{'row'} ++;
    $counter{'total_row'} ++;
  } # while

  ## clean up DB handle for cached statements
  foreach my $kk (keys %dbh_hash) {
    print $FH "# debug:    finish db handle for '$kk' statement\n" if exists($options{v}) && $more_debug;
    my $rc = $dbh_hash{$kk}->finish();
  } # foreach

  close INPUT;

  $counter{'total_file_valid'} ++ if $counter{'row'} > 0;

#  if ($counter{'row'} > 0 || exists($options{v})) {
    print $FH '['.epoch_to_datetime(time()).'] '.
	"  Summary: $input_file: ROWs=$counter{'row'} ; Entries=$counter{'entry'} ; New=$counter{'new'} ; Update=$counter{'update'}\n";
#  } # if

  save_input_file_state($state_file, $input_file, $input_filename_wo_gz);
} # for

# generate grid / contour
if (exists($options{g})) {
  my $no_keys = scalar keys %changed_epoch_hash;
  if ($no_keys >= 1) {
    # update affected epoch with $no_affected_epoch * 300 sec
    foreach my $this_epoch (sort keys %changed_epoch_hash) {
      for (my $t=1; $t <= $no_affected_epoch; $t++) {
	my $new_epoch = $this_epoch + $t*300;
	if (! exists($changed_epoch_hash{$new_epoch})) {
	  $changed_epoch_hash{$new_epoch} = 0;
	} # if
	$changed_epoch_hash{$new_epoch} ++;
	print $FH "# debug:   adding affected epoch for $this_epoch ($t): $new_epoch\n" if exists($options{v});
      } # for
    } # foreach

    # now running grid / contour generation
    foreach my $that_epoch (sort keys %changed_epoch_hash) {
      print $FH "# debug: generate grid/contour for $that_epoch (". epoch_to_datetime($that_epoch) .") ...\n" if exists($options{v});
      #my $result1 = system("/usr/bin/php $grid_gen_script", "$that_epoch", '-1', '4');
      #my $result1 = system("/usr/bin/php $grid_gen_script $that_epoch -1 4 | tee -a /tmp/debug4.txt");
      my $result1 = system("/usr/bin/php $grid_gen_script $that_epoch -1 4");
      if ($result1 != 0) {
	print $FH "# debug:   bad return ($result1) from '$grid_gen_script $that_epoch -1 4'\n" if exists($options{v});
      } # if
      else {
        $counter_regen4 ++;
      } # else
      #my $result0 = system("/usr/bin/php $grid_gen_script", "$that_epoch", '-1', '0');
      #my $result0 = system("/usr/bin/php $grid_gen_script $that_epoch -1 0 | tee -a /tmp/debug0.txt");
      my $result0 = system("/usr/bin/php $grid_gen_script $that_epoch -1 0");
      if ($result0 != 0) {
	print $FH "# debug:   bad return ($result0) from '$grid_gen_script $that_epoch -1 0'\n" if exists($options{v});
      } # if
      else {
        $counter_regen0 ++;
      } # else
    } # foreach
  } #if
} # if


if ($counter{'total_row'} > 0 || $counter{'total_file'} != $counter{'total_file_seen'} || exists($options{v})) {
  my $path_str;
  foreach my $k (sort keys %path_hash) {
    $path_str .= "'$k',";
  } # foreach
  $path_str =~ s/,$//;		# remove tailing comma

  my $msg = 
  	'['.epoch_to_datetime(time()).'] Total: '.
	"$path_str : ".
	"$counter{'total_file'} files ($counter{'total_file_valid'} valid, $counter{'total_file_seen'} seen) : ".
	"ROWs=$counter{'total_row'} ; Entries=$counter{'total_entry'} ; New=$counter{'total_new'} ; Update=$counter{'total_update'}";
  if (exists($options{g})) {
    my $no_keys = scalar keys %changed_epoch_hash;
    $msg .= " ; Regen=$no_keys ; band0=$counter_regen0 ; band4=$counter_regen4";
  } # if
  print $FH "$msg\n";
} # if

close $FH;

#------------------------------------
#
# set table and sql commands
#
sub set_table_sql_cmd {
  my ($table_name, $txn_tbl_name, $year, $inst_type, $dbh_hash_ptr) = @_;

  # create a new data table for new year
  my $sql = "
CREATE TABLE IF NOT EXISTS `$table_name` (
  `epoch` INT UNSIGNED NOT NULL,
  `siteID` SMALLINT UNSIGNED NOT NULL,
  `o3` DECIMAL(8,5) DEFAULT NULL,
  `o3_flag` VARCHAR(1) DEFAULT NULL,
  `temp` DECIMAL(8,5) DEFAULT NULL,
  `temp_flag` VARCHAR(1) DEFAULT NULL,
  `windspd` DECIMAL(8,5) DEFAULT NULL,
  `windspd_flag` VARCHAR(1) DEFAULT NULL,
  `winddir` DECIMAL(8,5) DEFAULT NULL,
  `winddir_flag` VARCHAR(1) DEFAULT NULL,
  `humid` DECIMAL(8,5) DEFAULT NULL,
  `humid_flag` VARCHAR(1) DEFAULT NULL,
  `pm25` DECIMAL(8,5) DEFAULT NULL,
  `pm25_flag` VARCHAR(1) DEFAULT NULL,
  `solar` DECIMAL(8,5) DEFAULT NULL,
  `solar_flag` VARCHAR(1) DEFAULT NULL,
  PRIMARY KEY (`epoch`, `siteID`)
) ENGINE=MyISAM
PARTITION BY RANGE ( epoch ) (";

  for (my $m = 1; $m <= 5; $m++) {
#	  $sql .= "
#  PARTITION m$m VALUES LESS THAN (".timegm(0,0,0,1,$m,$year).'),';
	  $sql .= "
  PARTITION m$m VALUES LESS THAN (unix_timestamp('$year-".($m*2+1)."-1')),";
  } # for
  $sql .= "
  PARTITION m6 VALUES LESS THAN MAXVALUE
);";

  print $FH "# debug: SQL command sql='$sql'\n" if exists($options{v}) && $more_debug;

  eval { $dbh->do($sql); };
  die "# Error: cannot create data table '$table_name': $@\n" if $@;

  # create a new transaction table for new year
  my $sql2 = "
CREATE TABLE IF NOT EXISTS `$txn_tbl_name` (
  `uid` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `epoch` INT UNSIGNED NOT NULL,
  `siteID` SMALLINT UNSIGNED NOT NULL,
  `inst` VARCHAR(7) NOT NULL,
  `state` VARCHAR(1) NOT NULL,
  `old_value` DECIMAL(8,5) DEFAULT NULL,
  `old_flag` VARCHAR(1) DEFAULT NULL,
  `update_epoch` int UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`uid`),
  INDEX (`epoch`, `siteID`, `inst`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1
PARTITION BY HASH(uid)
PARTITIONS 6;";

  print $FH "# debug: SQL command sql2='$sql2'\n" if exists($options{v}) && $more_debug;

  eval { $dbh->do($sql2); };
  die "# Error: cannot create transaction table '$txn_tbl_name': $@\n" if $@;

  my %sql_hash;

#        $sql_hash{'select'} = "SELECT * FROM $table_name WHERE epoch=? AND siteID=?;";
#	$dbh_hash_ptr->{'select'} = $dbh->prepare_cached($sql_hash{'select'});
#  	die "# Error: cannot prepare_cached sql statement '$sql_hash{'select'}': $@\n" unless defined $dbh_hash_ptr->{'select'};
#	print $FH "# debug: prepare_cached select SQL statement '$sql_hash{'select'}'\n" if exists($options{v}) && $more_debug;

  ## select related data from data table, and update_epoch from transaction table
  $sql_hash{'select2'} = "SELECT epoch, siteID, $inst_type, $inst_type"."_flag, (SELECT MAX(update_epoch) FROM $txn_tbl_name b WHERE b.epoch=? AND b.siteID=? AND b.inst='$inst_type') AS update_epoch FROM $table_name a WHERE a.epoch=? AND a.siteID=?;";
  $dbh_hash_ptr->{'select2'} = $dbh->prepare_cached($sql_hash{'select2'});
  die "# Error: cannot prepare_cached sql statement '$sql_hash{'select2'}': $@\n" unless defined $dbh_hash_ptr->{'select2'};
  print $FH "# debug: prepare_cached select SQL statement '$sql_hash{'select2'}'\n" if exists($options{v}) && $more_debug;

  ## inser data and flag into data table
  $sql_hash{'insert'} = "INSERT INTO $table_name (epoch, siteID, $inst_type, $inst_type"."_flag) VALUES (?, ?, ?, ?);";
  $dbh_hash_ptr->{'insert'} = $dbh->prepare_cached($sql_hash{'insert'});
  die "# Error: cannot prepare_cached sql statement '$sql_hash{'insert'}': $@\n" unless defined $dbh_hash_ptr->{'insert'};
  print $FH "# debug: prepare_cached insert SQL statement '$sql_hash{'insert'}'\n" if exists($options{v}) && $more_debug;

  ## inser flag only into data table
  $sql_hash{'insert_flag'} = "INSERT INTO $table_name (epoch, siteID, $inst_type"."_flag) VALUES (?, ?, ?);";
  $dbh_hash_ptr->{'insert_flag'} = $dbh->prepare_cached($sql_hash{'insert_flag'});
  die "# Error: cannot prepare_cached sql statement '$sql_hash{'insert_flag'}': $@\n" unless defined $dbh_hash_ptr->{'insert_flag'};
  print $FH "# debug: prepare_cached insert_flag SQL statement '$sql_hash{'insert_flag'}'\n" if exists($options{v}) && $more_debug;

  ## update data and flag in data table
  $sql_hash{'update'} = "UPDATE $table_name SET $inst_type=?, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
  $dbh_hash_ptr->{'update'} = $dbh->prepare_cached($sql_hash{'update'});
  die "# Error: cannot prepare_cached sql statement '$sql_hash{'update'}': $@\n" unless defined $dbh_hash_ptr->{'update'};
  print $FH "# debug: prepare_cached update SQL statement '$sql_hash{'update'}'\n" if exists($options{v}) && $more_debug;

  ## update null (missing) data in data table
  $sql_hash{'update_null'} = "UPDATE $table_name SET $inst_type=NULL, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
  $dbh_hash_ptr->{'update_null'} = $dbh->prepare_cached($sql_hash{'update_null'});
  die "# Error: cannot prepare_cached sql statement '$sql_hash{'update_null'}': $@\n" unless defined $dbh_hash_ptr->{'update_null'};
  print $FH "# debug: prepare_cached update_null SQL statement '$sql_hash{'update_null'}'\n" if exists($options{v}) && $more_debug;

  if (!exists($options{N})) {
    ## insert transaction data (new) into transaction table
    $sql_hash{'txn_new'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
    $dbh_hash_ptr->{'txn_new'} = $dbh->prepare_cached($sql_hash{'txn_new'});
    die "# Error: cannot prepare_cached sql statement '$sql_hash{'txn_new'}': $@\n" unless defined $dbh_hash_ptr->{'txn_new'};
    print $FH "# debug: prepare_cached tnx_new SQL statement '$sql_hash{'txn_new'}'\n" if exists($options{v}) && $more_debug;
  } # if

  ## insert transcation data (changes) into transaction table
  $sql_hash{'txn_change'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, old_value, old_flag, update_epoch) VALUES (?, ?, ?, ?, ?, ?, ?);";
  $dbh_hash_ptr->{'txn_change'} = $dbh->prepare_cached($sql_hash{'txn_change'});
  die "# Error: cannot prepare_cached sql statement '$sql_hash{'txn_change'}': $@\n" unless defined $dbh_hash_ptr->{'txn_change'};
  print $FH "# debug: prepare_cached tnx_change SQL statement '$sql_hash{'txn_change'}'\n" if exists($options{v}) && $more_debug;

} # sub set_table_sql_cmd

#------------------------------------
#
# push data into database
#
sub push_data_into_database {
  my ($my_epoch, $siteID, $inst_type, $value, $flag, $download_epoch, $dbh_hash_ptr) = @_;

	if (length($flag) > 0) {
          #$sql_hash{'select2'} = "SELECT epoch, siteID, $inst_type, $inst_type"."_flag, (SELECT MAX(update_epoch) FROM $txn_tbl_name b WHERE b.epoch=? AND b.siteID=? AND b.inst='$inst_type') AS update_epoch FROM $table_name a WHERE a.epoch=? AND a.siteID=?;";
	  eval { $dbh_hash_ptr->{'select2'}->execute($my_epoch, $siteID, $my_epoch, $siteID); };
          print $FH "# Warning: cannot execute select2 statement with epoch=$my_epoch and site=$siteID: $@\n" if $@;
	  my $my_ref = $dbh_hash_ptr->{'select2'}->fetchrow_hashref;

	  if ($$my_ref{'epoch'} > 0) {
		## existing record
	    my $old_value = $$my_ref{$inst_type};
	    my $old_flag = $$my_ref{$inst_type.'_flag'};
	    my $update_this = 0;
	    print $FH "# debug:   checking epoch='$$my_ref{'epoch'}' and site='$$my_ref{'siteID'}': $inst_type='$$my_ref{$inst_type}'  $inst_type"."_flag='$$my_ref{$inst_type.'_flag'}' update_epoch='$$my_ref{'update_epoch'}'\n" if exists($options{v}) && $more_debug;

	    ## there is some data already
	    if ($$my_ref{'update_epoch'} > 0) {
	      # check if data is newer
	      if ($$my_ref{'update_epoch'} < $download_epoch) {
		## skip entry if new data with flag "LST"
	        if ($flag ne $flag_mapping{'LST'}) {
	          $update_this ++ if $flag ne $$my_ref{$inst_type.'_flag'};
	          $update_this ++ if length($value) > 0 && $value != $$my_ref{$inst_type};
		} # if
	      } # if
	      else {
	        print $FH "# debug:   skipping older data : epoch='$$my_ref{'epoch'}' and site='$$my_ref{'siteID'}': $inst_type='$$my_ref{$inst_type}'  $inst_type"."_flag='$$my_ref{$inst_type.'_flag'}'  update_epoch='$$my_ref{'update_epoch'}'\n" if exists($options{v}) && $more_debug;
	      } # else
	    } # if
	    ## this is a new entry
	    else {
	      $update_this ++ if $flag ne $$my_ref{$inst_type.'_flag'};
	      $update_this ++ if length($value) > 0 && $value != $$my_ref{$inst_type};
	    } # else

	    ## now update data in database
	    if ($update_this > 0) {
	      if (length($value) > 0) {
	        print $FH "# debug:   Update entry for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
                #$sql_hash{'update'} = "UPDATE $table_name SET $inst_type=?, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
	        eval { $dbh_hash_ptr->{'update'}->execute($value, $flag, $my_epoch, $siteID); };
                print $FH "# Warning: cannot execute update statement for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag': $@\n" if $@;
	      } # if
	      else {
	        print $FH "# debug:   Update entry for epoch=$my_epoch and site=$siteID: $inst_type=NULL and $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
                #$sql_hash{'update_null'} = "UPDATE $table_name SET $inst_type=NULL, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
	        eval { $dbh_hash_ptr->{'update_null'}->execute($flag, $my_epoch, $siteID); };
                print $FH "# Warning: cannot execute update_null statement for epoch=$my_epoch and site=$siteID: $inst_type=NULL and $inst_type"."_flag='$flag': $@\n" if $@;
	      } # else

	      ##if (length($$my_ref{$inst_type.'_flag'}) <= 0 || $$my_ref{$inst_type.'_flag'} eq 'T') {	# if previous flag is empty or was 'LST'; treat as new update
	      if (length($old_flag) <= 0 || $old_flag eq 'T') {		# if previous flag was empty or 'LST'; treat as new update
		if (!exists($options{N})) {
	          ## insert transcation for new data
	          print $FH "# debug:   Insert new transaction for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag' (was '$old_flag')\n" if exists($options{v}) && $more_debug;
	          #$sql_hash{'txn_new'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
	          eval { $dbh_hash_ptr->{'txn_new'}->execute($my_epoch, $siteID, $inst_type, 'N', $download_epoch); };
                  print $FH "# Warning: cannot execute insert new transaction statement for epoch=$my_epoch and site=$siteID: $inst_type \@ ".epoch_to_datetime($download_epoch)." ($download_epoch): $@\n" if $@;
		} # if
		$counter{'new'} ++;
		$counter{'total_new'} ++;
	      } # if
	      else {						# if flag was not empty or 'LST'
	        ## insert transcation for changed data
	        print $FH "# debug:   Update transcation for epoch=$my_epoch and site=$siteID: $inst_type=$$my_ref{$inst_type} and $inst_type"."_flag='$$my_ref{$inst_type.'_flag'}' (was '$old_value' with '$old_flag')\@ ".epoch_to_datetime($download_epoch)." ($download_epoch)\n" if exists($options{v}) && $more_debug;
                #$sql_hash{'txn_change'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, old_value, old_flag, update_epoch) VALUES (?, ?, ?, ?, ?, ?, ?);";
	        eval { $dbh_hash_ptr->{'txn_change'}->execute($my_epoch, $siteID, $inst_type, 'U', $$my_ref{$inst_type}, $$my_ref{$inst_type.'_flag'}, $download_epoch); };
                print $FH "# Warning: cannot execute insert update transaction statement for epoch=$my_epoch and site=$siteID: $inst_type=$$my_ref{$inst_type} and $inst_type"."_flag='$$my_ref{$inst_type.'_flag'}' \@ ".epoch_to_datetime($download_epoch)." ($download_epoch): $@\n" if $@;
		$counter{'update'} ++;
		$counter{'total_update'} ++;
	      } # else

	      # save epoch of changed data
	      save_changed_epoch($my_epoch, $inst_type);
	    } # if
	    else {
	      print $FH "# debug:   no change in value or older data, skip update for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
	    } # else
	  } # if
	  else {
	    if (length($value) > 0) {
	      ## insert new data
	      print $FH "# debug:   Insert entry for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
	      #$sql_hash{'insert'} = "INSERT INTO $table_name (epoch, siteID, $inst_type, $inst_type"."_flag) VALUES (?, ?, ?, ?);";
	      eval { $dbh_hash_ptr->{'insert'}->execute($my_epoch, $siteID, $value, $flag); };
              print $FH "# Warning: cannot execute insert statement for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag': $@\n" if $@;

	      if (!exists($options{N})) {
	        ## insert transcation for new data
	        print $FH "# debug:   Insert new transaction for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
	        #$sql_hash{'txn_new'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
	        eval { $dbh_hash_ptr->{'txn_new'}->execute($my_epoch, $siteID, $inst_type, 'N', $download_epoch); };
                print $FH "# Warning: cannot execute insert new transaction statement for epoch=$my_epoch and site=$siteID: $inst_type \@ ".epoch_to_datetime($download_epoch)." ($download_epoch): $@\n" if $@;
	      } # if
	      $counter{'new'} ++;
	      $counter{'total_new'} ++;
	    } # if
	    else {
	      ## no value, only flag
	      print $FH "# debug:   Insert entry for epoch=$my_epoch and site=$siteID: $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
	      #$sql_hash{'insert_flag'} = "INSERT INTO $table_name (epoch, siteID, $inst_type"."_flag) VALUES (?, ?, ?);";
	      eval { $dbh_hash_ptr->{'insert_flag'}->execute($my_epoch, $siteID, $flag); };
              print $FH "# Warning: cannot execute insert_flag statement for epoch=$my_epoch and site=$siteID: $inst_type"."_flag='$flag': $@\n" if $@;
	    } # else
	  } # else
	} # if
} # sub push_data_into_database

#------------------------------------
#
# save input file state
#
sub save_input_file_state {
  my ($state_file, $input_file, $input_filename) = @_;

  # save state
  if (! exists($options{S})) {
    # check output dir
    my $out_dir = $state_file;
    $out_dir =~ s/\/$state_file_prefix.*$//;
    if (! -d $out_dir) {
      print $FH "# debug:  dir/path of state file '$out_dir' not exist; mkdir $out_dir ...\n" if exists($options{v});
      make_path($out_dir, {error => \my $err} );
      if (@$err) {
	warn "# Error: cannot make path '$out_dir' for state file '$state_file' ... \n";
	if (exists($options{v}) && $more_debug) {
	  for my $diag (@$err) {
	    my ($dir, $message) = %$diag;
	    if ($dir eq '') {
	      print "# Error:   problem on making path '$out_dir': $message\n";
	    } # if
	    else {
	      print "# Error:   problem on making path '$out_dir', while creating directory '$dir': $message\n";
	    } # else
	  } # for
        } # if
      } # if
    } # if

    open (STATEOUT, ">>$state_file") or warn "# Warning: cannot write to state file '$state_file': $?\n";
    my $tmp_epoch = time();
    print STATEOUT "$input_file,$tmp_epoch\n";
    print $FH "# debug: save state '$input_file,$tmp_epoch'\n" if exists($options{v});
    close STATEOUT;

    # save current file to state
    $state_hash{$input_filename} = $tmp_epoch;
  } # if
  else {
    print $FH "# debug: skip saving state for '$input_file'\n" if exists($options{v});
  } # else
} # sub save_input_file_state

#------------------------------------
#
# record epoch of changed data
#
sub save_changed_epoch  {
  my ($changed_epoch, $inst_type) = @_;
  #if ($inst_type =~ /o3/ || $inst_type =~ /windspd/ || $inst_type =~ /windspd/) {
  if ($inst_type =~ /o3/) {
    if (!exists($changed_epoch_hash{$changed_epoch})) {
      $changed_epoch_hash{$changed_epoch} = 0;
    } # if
    $changed_epoch_hash{$changed_epoch} ++;
  } # if
} # sub save_changed_epoch

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
# convert epoch to GMT datetime string
#
sub epoch_to_GMT_datetime {

  my ($epoch) = @_;

  my ($sec, $min, $hour, $day, $month, $year) = (gmtime($epoch))[0,1,2,3,4,5,6];
  my $GMT_datetime_str = sprintf "%d/%02d/%02d.%02d:%02d:%02d", $year+1900, $month+1, $day, $hour, $min, $sec;

  return $GMT_datetime_str;
} # sub epoch_to_GMT_datetime

#------------------------------------
#
# usage subroutine
#
sub usage {

  print $FH "Usage: $0 input_files ...\n";
  print $FH <<__usage__;

  -D		turn on more debugging info
  -d		push into database
  -F		force data file push (skip checking state)
  -g		trigger grid generation / contour plotting procedure
  -h		print usage (this message)
  -N		skip recroding new transcation (will record change/update)
  -o outfile	write output to outfile instead of STDOUT
  -t epoch	overwrite raw data download time; default: extract from file name or use current time
  -s statedir	state dir name (overwrite default)
  -S		skip recording state of pushed data files
  -T		force using current time as data download time
  -v		verbose output

__usage__
  exit 1;

} # sub usage
