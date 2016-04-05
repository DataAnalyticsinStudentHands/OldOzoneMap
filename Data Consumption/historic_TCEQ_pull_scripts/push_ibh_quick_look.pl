#!/usr/bin/perl

#
# Push quick_look raw data file to database, with state for input files
#
# Created: 07/21/2011
# Modified: 09/05/2012
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

# from package: libtimedate-perl (Ubuntu) or perl-TimeDate (Centos/EPEL)
use Date::Parse;

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
  my $state_file_prefix = 'ibh_ql_state';	# file name pattern: 'yyyy/yyyy-mm/$state_file_prefix.yyyy-mm-dd.txt'
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

my %flag_mapping;	# mapping for flag abbreviation (http://www.tceq.state.tx.us/cgi-bin/compliance/monops/daily_info.pl?nodata)
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
getopts("DdFghNo:Rs:STt:v", \%options);

usage() if exists($options{h}) || !(exists($options{o}) ||
	exists($options{D}) || exists($options{d}) || exists($options{v}) ||
	exists($options{T}) || exists($options{t}) || exists($options{N}) ||
	exists($options{F}) || exists($options{s}) || exists($options{S}) ||
	exists($options{g}) || exists($options{R}) || 
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

  if ($input_filename =~ /^\w+\.(\d{4}-\d{2}-\d{2})\.\d{6}\.\d+h/) {
    # sample input: o3.2012-07-20.211527.3h.1342840527.txt
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

  my $base_epoch;	# base epoch time for data (basically 00:00 CST of reporting day)
  my $report_epoch;	# epoch time of "quick look" page gnerated
  my @time_label;	# list of time label at top of table

#----

  my @header_list;	# list for header (w/ instrument id removed)
  my @site_list;	# list for sites listed in the header
  my @action_list;	# list for action for $site_list[$i]: action/push if = 1;
  my %site_hash;	# hash for seen sites

  my $table_name;	# data table name
  my %hash_table_name;	# hash for table name

  my $download_epoch;	# raw data file download epoch time; set by file name, options{t} or current time
  my $txn_tbl_name;	# transaction table name

  my %dbh_hash;		# hash for DB handlers;

  # reset counter
  $counter{'row'} = 0;		# no of rows (5 min per row)
  $counter{'entry'} = 0;	# no of entries (rows x sites)
  $counter{'new'} = 0;		# no of new data
  $counter{'update'} = 0;	# no of updates/changes

  # check for accounting file
  die "Error: input file '$input_file' not found.\n" if ! -e $input_file;

  print $FH "# debug: Using file '$input_file' as input\n" if exists($options{v});

  # read in the accounting file
  if ($input_file !~ /gz$/) {
    open(INPUT,"$input_file") || die "Could not open file '$input_file': $?\n";
  } # if
  else {
    open(INPUT,"gzip -dc $input_file |") || die "Could not unpack file '$input_file': $?\n";
  } # else

  # set download epoch time
  #   sample input: o3.2012-07-20.211527.3h.1342840527.txt
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

#------------------------------

    while ($line = <INPUT>) {
      last if $line =~ /Report generated: /;    # skip everything up till "Report generated: "
      if ($line=~ /^## time spent/) {
	# go to next file when reaching end of file download
	warn "# Warn: expecting line containing 'Report generated', but reaching end of download '$line'; skip processing '$input_file'\n";
	save_input_file_state($state_file, $input_file, $input_filename_wo_gz);
	next FILE_LOOP;
      } # if
    } # while

    ## need sanity check if we process a file that didn't finish download

    chomp($line);
    my ($year,$month,$day,$hour,$min,$sec,$tzone);

    # get date time
    #   Report generated: Monday August 15, 2011 12:00:01 CST
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

      if (exists($options{R})) {
	print $FH "# debug: (-R) overwrite download_epoch ($download_epoch) with report_epoch ($report_epoch)\n" if exists($options{v});
	$download_epoch = $report_epoch;
      } # if
    } # if
    #     Report generated: Monday August 15, 2011
    #                   00:00:01 CST
    elsif ($line =~ /Report generated:\s+\w+\s+(\w+)\s+(\d+),\s+(\d+)/) {
      $month = $1;
      $day = $2;
      $year = $3;
      $line = <INPUT>;          # read another line
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

        if (exists($options{R})) {
	  print $FH "# debug: (-R) overwrite download_epoch ($download_epoch) with report_epoch ($report_epoch)\n" if exists($options{v});
	  $download_epoch = $report_epoch;
        } # if
      } # if
      elsif ($line =~ /\s+(-\d+):(\d+):(\d+)\s+(\w+)/) {
        $hour = $1;
        $min = $2;
        $sec = $3;
        $tzone = $4;

        $month = substr($month,0,3);
        $report_epoch = str2time("$day $month $year 00:$min:$sec $tzone");
	$report_epoch += $hour * 60 * 60;
        $base_epoch = str2time("$day $month $year 00:00:00 $tzone");
        print $FH "# debug: date/time => $year / $month / $day,  $hour:$min:$sec $tzone\n" if exists($options{v});
        print $FH "# report_epoch: $report_epoch\n" if exists($options{v});
        print $FH "# base_epoch: $base_epoch\n" if exists($options{v});

        if (exists($options{R})) {
	  print $FH "# debug: (-R) overwrite download_epoch ($download_epoch) with report_epoch ($report_epoch)\n" if exists($options{v});
	  $download_epoch = $report_epoch;
        } # if
      } # elsif
      else {
        die "# Error: cannot parse date/time from '$line' for '$input_file'\n";
      } # else
    } # elsif
    #     Report generated: Wednesday September 05,
    #                 2012 00:00:17 CST
    elsif ($line =~ /Report generated:\s+\w+\s+(\w+)\s+(\d+),/) {
      $month = $1;
      $day = $2;
      $line = <INPUT>;          # read another line
      chomp($line);
      if ($line =~ /\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\w+)/) {
        $year = $1;
        $hour = $2;
        $min = $3;
        $sec = $4;
        $tzone = $5;

        $month = substr($month,0,3);
        $report_epoch = str2time("$day $month $year $hour:$min:$sec $tzone");
        $base_epoch = str2time("$day $month $year 00:00:00 $tzone");
        print $FH "# debug: date/time => $year / $month / $day,  $hour:$min:$sec $tzone\n" if exists($options{v});
        print $FH "# report_epoch: $report_epoch\n" if exists($options{v});
        print $FH "# base_epoch: $base_epoch\n" if exists($options{v});

        if (exists($options{R})) {
	  print $FH "# debug: (-R) overwrite download_epoch ($download_epoch) with report_epoch ($report_epoch)\n" if exists($options{v});
	  $download_epoch = $report_epoch;
        } # if
      } # if
      elsif ($line =~ /\s+(\d+)\s+(-\d+):(\d+):(\d+)\s+(\w+)/) {
        $year = $1;
        $hour = $2;
        $min = $3;
        $sec = $4;
        $tzone = $5;

        $month = substr($month,0,3);
        $report_epoch = str2time("$day $month $year 00:$min:$sec $tzone");
	$report_epoch += $hour * 60 * 60;
        $base_epoch = str2time("$day $month $year 00:00:00 $tzone");
        print $FH "# debug: date/time => $year / $month / $day,  $hour:$min:$sec $tzone\n" if exists($options{v});
        print $FH "# report_epoch: $report_epoch\n" if exists($options{v});
        print $FH "# base_epoch: $base_epoch\n" if exists($options{v});

        if (exists($options{R})) {
	  print $FH "# debug: (-R) overwrite download_epoch ($download_epoch) with report_epoch ($report_epoch)\n" if exists($options{v});
	  $download_epoch = $report_epoch;
        } # if
      } # elsif
      else {
        die "# Error: cannot parse date/time from '$line' for '$input_file'\n";
      } # else
    } # elsif
    else {
      ## need sanity check if input file is not downloaded completely
      die "# Error: cannot parse date/time from '$line' for '$input_file'\n";
    } # else

    # Read next line for instrument info
    while ($line = <INPUT>) {
      if ($line =~ /EPA parameter\s+(\d+)\s+measured in\s+(.*)\./) {
	$inst_id = $1;
	$inst_unit = $2;
        if (exists($inst_mapping{$inst_id})) {
          $inst_type = $inst_mapping{$inst_id};
          print $FH "# debug: found instrument ($inst_id) = '$inst_type'\n" if exists($options{v});
        } # if
        else {
          die "# Error: cannot find matching instrument id ($inst_id)\n";
        } # else
        print $FH "# debug: found instrument unit = '$inst_unit'\n" if exists($options{v});
	last;
      } # if
    } # while

    ## again sanity check if input file is not downloaded completely

    # skip till separator line
    while ($line = <INPUT>) {
      last if $line =~ /--------+----/; # skip everything up till table separtor line
    } # while

    #-----------------
    #
    # now good stuff (data table); first get header (timestamps)
    #
    my $counter = 0;
    my $counter_QAS = 0;
    #my %tmp_hash;                      # temp hash for Ozone data
    my $header = 0;                     # no header yet

    while (my $line = <INPUT>) {
      next if $line =~/----+----/;              # skip separator
      chomp($line);
      last if $line =~ /^\s*$/;
      $line =~ s/^\s+//;                        # remove leading blanks
      $line =~ s/\s+$//;                        # remove tailing blanks

      #
      # split input line
      #
      my @tmp_list = split /\|/, $line; # split line that separated by '|'

      # get header / time
      if ($header == 0) {
        for (my $i = 3; $i <= $#tmp_list; $i++) {
          next if ($tmp_list[$i] =~ /\[.*\]/);
          my $tmp_str = $tmp_list[$i];
          $tmp_str =~ s/\s+//g;                 # remove blanks
          next if length($tmp_str) <= 0;        # skip empty block
          #print $FH "# debug: date/time str = '$day $month $year $tmp_str:00 $tzone'\n" if exists($options{v});
          my $tmp_epoch = str2time("$day $month $year $tmp_str:00 $tzone");
          #print $FH "# debug: tmp_epoch = '$tmp_epoch'\n" if exists($options{v});
          push(@time_label, $tmp_epoch);

	  if (exists($options{d})) {
	    my ($sec, $min, $hour, $day, $month, $year) = (gmtime($tmp_epoch))[0,1,2,3,4,5,6];
	    $year += 1900;
	    print $FH "# debug: gmtime for '$tmp_epoch' is $year/".($month+1)."/$day $hour:$min:$sec\n" if exists($options{v}) && $more_debug;
	    $table_name = $table_base.$year;
	    $txn_tbl_name = $txn_tbl_base.$year;
	    if (!exists($hash_table_name{$table_name})) {
	      $hash_table_name{$table_name} = 1;
	      print $FH "# debug: table_name = '$table_name'\n" if exists($options{v}) && $more_debug;
	      print $FH "# debug: txn_tbl_name = '$txn_tbl_name'\n" if exists($options{v}) && $more_debug;
	      # set up table and create SQL commands
	      set_table_sql_cmd($table_name, $txn_tbl_name, $year, $inst_type, \%dbh_hash);
	    } # if
	  } # if
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

      #--------------------
      #
      # now processing data (data table: content)
      #
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

      last if $tmp_site =~ /CAMS/;                      # reaching the end of data table
      last if $tmp_list[3] =~ /CAMS/;                   # reaching the end of data table (bad case: " | | Region | [269]CAMS |")

      last if $tmp_site =~ /^## time spent/;		# break out while loop when reaching end of file download

      print $FH "# debug: site id = $tmp_site\n" if exists($options{v});
      print $FH "# debug: tmp_list items = $#tmp_list / $#time_label\n" if exists($options{v}) && $more_debug;

      if ($#tmp_list <= ($#time_label + 6)) {
        #
        # normal table layout
        #

        for (my $n = 0; $n <= $#time_label; $n++) {
          my $tmp_value = $tmp_list[$n+3];
	  my $flag;
	  my $value;
          $tmp_value =~ s/\s+//g;                       # remove blanks

          if (length($tmp_value) > 0) {
            print $FH "# debug:   site $tmp_site : [".epoch_to_datetime($time_label[$n])."] = '$tmp_value'\n" if exists($options{v}) && $more_debug;

	    ## push/update data/flag into database
	    if (exists($options{d})) {
	      push_data_into_database($time_label[$n], $tmp_site, $inst_type, $tmp_value, $download_epoch, \%dbh_hash);
	    } # if
	    $counter{'entry'} ++;
	    $counter{'total_entry'} ++;

          } # if
          else {
            print $FH "# debug: continuous missing data: site[$tmp_site] '$tmp_value' \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v}) && $more_debug;
          } # else
        } # for
	$counter{'row'} ++;
	$counter{'total_row'} ++;
      } # if
      elsif ($#tmp_list <= ($#time_label + 8)) {
        # extra stuff
        $tmp_site = $tmp_list[3];
        $tmp_site =~ s/\s+//g;                  # remove blanks
        if ($tmp_site =~ /\[\d+\]/) {
          $tmp_site =~ s/\[\d+\]//;
        } # if

        my $offset = 0;
        for (my $n = 0; $n <= $#time_label; $n++) {
          my $tmp_value = $tmp_list[$n+4+$offset];

          if ($tmp_value =~ /\[\d+\]/ || $tmp_value =~ /^\s+$/) {
            $tmp_value = $tmp_list[$n+5+$offset];               # use next value
            $tmp_value =~ s/\[\d+\]//;
            $offset ++;
          } # if

          $tmp_value =~ s/\s+//g;                       # remove blanks
          if (length($tmp_value) > 0) {
            print $FH "## debug:   site $tmp_site : [".epoch_to_datetime($time_label[$n])."] = '$tmp_value'\n" if exists($options{v}) && $more_debug;

	    ## push/update data/flag into database
	    if (exists($options{d})) {
	      push_data_into_database($time_label[$n], $tmp_site, $inst_type, $tmp_value, $download_epoch, \%dbh_hash);
	    } # if
          } # if
          else {
              print $FH "## debug: continuous missing data: site[$tmp_site] '$tmp_value' \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v}) && $more_debug;
          } # else
        } # for
	$counter{'row'} ++;
	$counter{'total_row'} ++;
      } # elsif
      else {
        # lots of extra stuff

        # get regular stuff first
        for (my $n = 0; $n <= $#time_label; $n++) {
          my $tmp_value = $tmp_list[$n+3];
          $tmp_value =~ s/\s+//g;                       # remove blanks
          if (length($tmp_value) > 0) {
            print $FH "### debug:   site $tmp_site : [".epoch_to_datetime($time_label[$n])."] = '$tmp_value'\n" if exists($options{v}) && $more_debug;

	    ## push/update data/flag into database
	    if (exists($options{d})) {
	      push_data_into_database($time_label[$n], $tmp_site, $inst_type, $tmp_value, $download_epoch, \%dbh_hash);
	    } # if
	    $counter{'entry'} ++;
	    $counter{'total_entry'} ++;
          } # if
          else {
              print $FH "### debug: continuous missing data: site[$tmp_site] '$tmp_value' \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v}) && $more_debug;
          } # else
          #push(@time_label, $tmp_epoch);
        } # for

        # get reset of lines
        my $base_offset = $#time_label + 6;
        my $tmp_site_pov = $tmp_list[$base_offset + $#time_label + 1];
        $tmp_site_pov =~ s/\s+//g;
        $tmp_site =~ s/_\d+$/_$tmp_site_pov/;
        print $FH "# debug: new site id = $tmp_site / $tmp_site_pov\n" if exists($options{v});

        for (my $n = 0; $n <= $#time_label; $n++) {
          my $tmp_value = $tmp_list[$n+$base_offset];
          $tmp_value =~ s/\s+//g;                       # remove blanks
          if (length($tmp_value) > 0) {
            print $FH "#### debug:   site $tmp_site : [".epoch_to_datetime($time_label[$n])."] = '$tmp_value'\n" if exists($options{v}) && $more_debug;

	    ## push/update data/flag into database
	    if (exists($options{d})) {
	      push_data_into_database($time_label[$n], $tmp_site, $inst_type, $tmp_value, $download_epoch, \%dbh_hash);
	    } # if
	    $counter{'entry'} ++;
	    $counter{'total_entry'} ++;
          } # if
          else {
              print $FH "#### debug: continuous missing data: site[$tmp_site] '$tmp_value' \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v}) && $more_debug;
          } # else
        } # for

        # get reset of lines
        my $base_offset = $#time_label*2 + 8;
        my $tmp_site_pov = $tmp_list[$base_offset + $#time_label + 1];
        $tmp_site_pov =~ s/\s+//g;
        $tmp_site =~ s/_\d+$/_$tmp_site_pov/;
        print $FH "# debug: new site id = $tmp_site / $tmp_site_pov\n" if exists($options{v});

        for (my $n = 0; $n <= $#time_label; $n++) {
          my $tmp_value = $tmp_list[$n+$base_offset];
          $tmp_value =~ s/\s+//g;                       # remove blanks
          if (length($tmp_value) > 0) {
            print $FH "##### debug:   site $tmp_site : [".epoch_to_datetime($time_label[$n])."] = '$tmp_value'\n" if exists($options{v}) && $more_debug;

	    ## push/update data/flag into database
	    if (exists($options{d})) {
	      push_data_into_database($time_label[$n], $tmp_site, $inst_type, $tmp_value, $download_epoch, \%dbh_hash);
	    } # if
	    $counter{'entry'} ++;
	    $counter{'total_entry'} ++;
          } # if
          else {
              print $FH "##### debug: continuous missing data: site[$tmp_site] '$tmp_value' \@ ".epoch_to_datetime($report_epoch)." ($report_epoch) for ".epoch_to_datetime($time_label[$n])." ($time_label[$n])\n" if exists($options{v}) && $more_debug;
          } # else
        } # for

	$counter{'row'} ++;
	$counter{'total_row'} ++;
      } # elsif

    } # while

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
  $sql_hash{'select2'.'_'.$year} = "SELECT epoch, siteID, $inst_type, $inst_type"."_flag, (SELECT MAX(update_epoch) FROM $txn_tbl_name b WHERE b.epoch=? AND b.siteID=? AND b.inst='$inst_type') AS update_epoch FROM $table_name a WHERE a.epoch=? AND a.siteID=?;";
  $dbh_hash_ptr->{'select2'.'_'.$year} = $dbh->prepare_cached($sql_hash{'select2'.'_'.$year});
  die "# Error: cannot prepare_cached sql statement '".$sql_hash{'select2'.'_'.$year}."': $@\n" unless defined $dbh_hash_ptr->{'select2'.'_'.$year};
  print $FH "# debug: prepare_cached select SQL statement '".$sql_hash{'select2'.'_'.$year}."'\n" if exists($options{v}) && $more_debug;

  ## inser data and flag into data table
  $sql_hash{'insert'.'_'.$year} = "INSERT INTO $table_name (epoch, siteID, $inst_type, $inst_type"."_flag) VALUES (?, ?, ?, ?);";
  $dbh_hash_ptr->{'insert'.'_'.$year} = $dbh->prepare_cached($sql_hash{'insert'.'_'.$year});
  die "# Error: cannot prepare_cached sql statement '".$sql_hash{'insert'.'_'.$year}."': $@\n" unless defined $dbh_hash_ptr->{'insert'.'_'.$year};
  print $FH "# debug: prepare_cached insert SQL statement '".$sql_hash{'insert'.'_'.$year}."'\n" if exists($options{v}) && $more_debug;

  ## inser flag only into data table
  $sql_hash{'insert_flag'.'_'.$year} = "INSERT INTO $table_name (epoch, siteID, $inst_type"."_flag) VALUES (?, ?, ?);";
  $dbh_hash_ptr->{'insert_flag'.'_'.$year} = $dbh->prepare_cached($sql_hash{'insert_flag'.'_'.$year});
  die "# Error: cannot prepare_cached sql statement '".$sql_hash{'insert_flag'.'_'.$year}."': $@\n" unless defined $dbh_hash_ptr->{'insert_flag'.'_'.$year};
  print $FH "# debug: prepare_cached insert_flag SQL statement '".$sql_hash{'insert_flag'.'_'.$year}."'\n" if exists($options{v}) && $more_debug;

  ## update data and flag in data table
  $sql_hash{'update'.'_'.$year} = "UPDATE $table_name SET $inst_type=?, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
  $dbh_hash_ptr->{'update'.'_'.$year} = $dbh->prepare_cached($sql_hash{'update'.'_'.$year});
  die "# Error: cannot prepare_cached sql statement '".$sql_hash{'update'.'_'.$year}."': $@\n" unless defined $dbh_hash_ptr->{'update'.'_'.$year};
  print $FH "# debug: prepare_cached update SQL statement '".$sql_hash{'update'.'_'.$year}."'\n" if exists($options{v}) && $more_debug;

  ## update null (missing) data in data table
  $sql_hash{'update_null'.'_'.$year} = "UPDATE $table_name SET $inst_type=NULL, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
  $dbh_hash_ptr->{'update_null'.'_'.$year} = $dbh->prepare_cached($sql_hash{'update_null'.'_'.$year});
  die "# Error: cannot prepare_cached sql statement '".$sql_hash{'update_null'.'_'.$year}."': $@\n" unless defined $dbh_hash_ptr->{'update_null'.'_'.$year};
  print $FH "# debug: prepare_cached update_null SQL statement '".$sql_hash{'update_null'.'_'.$year}."'\n" if exists($options{v}) && $more_debug;

  if (!exists($options{N})) {
    ## insert transaction data (new) into transaction table
    $sql_hash{'txn_new'.'_'.$year} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
    $dbh_hash_ptr->{'txn_new'.'_'.$year} = $dbh->prepare_cached($sql_hash{'txn_new'.'_'.$year});
    die "# Error: cannot prepare_cached sql statement '".$sql_hash{'txn_new'.'_'.$year}."': $@\n" unless defined $dbh_hash_ptr->{'txn_new'.'_'.$year};
    print $FH "# debug: prepare_cached tnx_new SQL statement '".$sql_hash{'txn_new'.'_'.$year}."'\n" if exists($options{v}) && $more_debug;
  } # if

  ## insert transcation data (changes) into transaction table
  $sql_hash{'txn_change'.'_'.$year} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, old_value, old_flag, update_epoch) VALUES (?, ?, ?, ?, ?, ?, ?);";
  $dbh_hash_ptr->{'txn_change'.'_'.$year} = $dbh->prepare_cached($sql_hash{'txn_change'.'_'.$year});
  die "# Error: cannot prepare_cached sql statement '".$sql_hash{'txn_change'.'_'.$year}."': $@\n" unless defined $dbh_hash_ptr->{'txn_change'.'_'.$year};
  print $FH "# debug: prepare_cached tnx_change SQL statement '".$sql_hash{'txn_change'.'_'.$year}."'\n" if exists($options{v}) && $more_debug;

} # sub set_table_sql_cmd

#------------------------------------
#
# push data into database
#
sub push_data_into_database {
  my ($my_epoch, $siteID, $inst_type, $raw_value, $download_epoch, $dbh_hash_ptr) = @_;

  my $value;		# value
  my $flag;		# flag -- processed
  my ($sec, $min, $hour, $day, $month, $year) = (gmtime($my_epoch))[0,1,2,3,4,5,6];
  $year += 1900;

  if ($raw_value =~ /^[-+]?[0-9]*\.?[0-9]+$/) {
    $flag = 'K';
    $value = $raw_value;
    print $FH "# debug:   raw '$raw_value' ($my_epoch) ; site = $siteID ; value = '$value' ; flag = '$flag'\n" if exists($options{v}) && $more_debug;
  } # if
  elsif ($raw_value =~ /[A-Z]{3}/) {
    $value = '';
    if (exists($flag_mapping{$raw_value})) {
      $flag = $flag_mapping{$raw_value};
      print $FH "# debug:   raw '$raw_value' ($my_epoch) ; site = $siteID ; value = '$value' ; flag = '$flag'\n" if exists($options{v}) && $more_debug;
    } # if
    else {
      $flag = '';
      print $FH "# Error: mismatch flag:  raw '$raw_value' ($my_epoch) ; site = $siteID ; value = '$value'\n" if exists($options{v}) && $more_debug;
    } # else
  } # if

	if (length($flag) > 0) {
          #$sql_hash{'select2'} = "SELECT epoch, siteID, $inst_type, $inst_type"."_flag, (SELECT MAX(update_epoch) FROM $txn_tbl_name b WHERE b.epoch=? AND b.siteID=? AND b.inst='$inst_type') AS update_epoch FROM $table_name a WHERE a.epoch=? AND a.siteID=?;";
	  eval { $dbh_hash_ptr->{'select2'.'_'.$year}->execute($my_epoch, $siteID, $my_epoch, $siteID); };
          print $FH "# Warning: cannot execute select2 statement with epoch=$my_epoch and site=$siteID: $@\n" if $@;
	  my $my_ref = $dbh_hash_ptr->{'select2'.'_'.$year}->fetchrow_hashref;

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
		## skip entry if new data with flag "LST", "LIM", "NOD"
	        if ($flag ne $flag_mapping{'LST'} && $flag ne $flag_mapping{'LIM'} && $flag ne $flag_mapping{'NOD'}) {
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
	        eval { $dbh_hash_ptr->{'update'.'_'.$year}->execute($value, $flag, $my_epoch, $siteID); };
                print $FH "# Warning: cannot execute update statement for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag': $@\n" if $@;
	      } # if
	      else {
	        print $FH "# debug:   Update entry for epoch=$my_epoch and site=$siteID: $inst_type=NULL and $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
                #$sql_hash{'update_null'} = "UPDATE $table_name SET $inst_type=NULL, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
	        eval { $dbh_hash_ptr->{'update_null'.'_'.$year}->execute($flag, $my_epoch, $siteID); };
                print $FH "# Warning: cannot execute update_null statement for epoch=$my_epoch and site=$siteID: $inst_type=NULL and $inst_type"."_flag='$flag': $@\n" if $@;
	      } # else

	      ##if (length($$my_ref{$inst_type.'_flag'}) <= 0 || $$my_ref{$inst_type.'_flag'} eq 'T') {	# if previous flag is empty or was 'LST'; treat as new update
	      if (length($old_flag) <= 0 || $old_flag eq 'T') {		# if previous flag was empty or 'LST'; treat as new update
		if (!exists($options{N})) {
	          ## insert transcation for new data
	          print $FH "# debug:   Insert new transaction for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag' (was '$old_flag')\n" if exists($options{v}) && $more_debug;
	          #$sql_hash{'txn_new'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
	          eval { $dbh_hash_ptr->{'txn_new'.'_'.$year}->execute($my_epoch, $siteID, $inst_type, 'N', $download_epoch); };
                  print $FH "# Warning: cannot execute insert new transaction statement for epoch=$my_epoch and site=$siteID: $inst_type \@ ".epoch_to_datetime($download_epoch)." ($download_epoch): $@\n" if $@;
		} # if
		$counter{'new'} ++;
		$counter{'total_new'} ++;
	      } # if
	      else {						# if flag was not empty or 'LST'
	        ## insert transcation for changed data
	        print $FH "# debug:   Update transcation for epoch=$my_epoch and site=$siteID: $inst_type=$$my_ref{$inst_type} and $inst_type"."_flag='$$my_ref{$inst_type.'_flag'}' (was '$old_value' with '$old_flag')\@ ".epoch_to_datetime($download_epoch)." ($download_epoch)\n" if exists($options{v}) && $more_debug;
                #$sql_hash{'txn_change'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, old_value, old_flag, update_epoch) VALUES (?, ?, ?, ?, ?, ?, ?);";
	        eval { $dbh_hash_ptr->{'txn_change'.'_'.$year}->execute($my_epoch, $siteID, $inst_type, 'U', $$my_ref{$inst_type}, $$my_ref{$inst_type.'_flag'}, $download_epoch); };
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
	      eval { $dbh_hash_ptr->{'insert'.'_'.$year}->execute($my_epoch, $siteID, $value, $flag); };
              print $FH "# Warning: cannot execute insert statement for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag': $@\n" if $@;

	      if (!exists($options{N})) {
	        ## insert transcation for new data
	        print $FH "# debug:   Insert new transaction for epoch=$my_epoch and site=$siteID: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
	        #$sql_hash{'txn_new'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
	        eval { $dbh_hash_ptr->{'txn_new'.'_'.$year}->execute($my_epoch, $siteID, $inst_type, 'N', $download_epoch); };
                print $FH "# Warning: cannot execute insert new transaction statement for epoch=$my_epoch and site=$siteID: $inst_type \@ ".epoch_to_datetime($download_epoch)." ($download_epoch): $@\n" if $@;
	      } # if
	      $counter{'new'} ++;
	      $counter{'total_new'} ++;
	    } # if
	    else {
	      ## no value, only flag
	      print $FH "# debug:   Insert entry for epoch=$my_epoch and site=$siteID: $inst_type"."_flag='$flag'\n" if exists($options{v}) && $more_debug;
	      #$sql_hash{'insert_flag'} = "INSERT INTO $table_name (epoch, siteID, $inst_type"."_flag) VALUES (?, ?, ?);";
	      eval { $dbh_hash_ptr->{'insert_flag'.'_'.$year}->execute($my_epoch, $siteID, $flag); };
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
  -R		use report generate time as data download time
  -s statedir	state dir name (overwrite default)
  -S		skip recording state of pushed data files
  -T		force using current time as data download time
  -v		verbose output

__usage__
  exit 1;

} # sub usage
