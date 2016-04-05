#!/usr/bin/perl

#
# Push data_extractor raw data file to database
#
# Created: 09/02/2011
# Modified: 09/02/2011
#
# Author: T. Mark Huang
#
#

use strict;
use Getopt::Std;	# command line option
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
  my $table_base = $table_prefix.'data_year_';
  my $txn_tbl_base = $table_prefix.'txn_year_';
  my $table;

my %inst_mapping;		# hash for instrument mapping
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
  $counter{'row'} = 0;		# no of rows (5 min per row)
  $counter{'entry'} = 0;	# no of entries (rows x sites)
  $counter{'new'} = 0;		# no of new data
  $counter{'update'} = 0;	# no of updates/changes
  $counter{'LST'} = 0;		# no of LST
  $counter{'LIM'} = 0;		# no of LIM
  $counter{'QAS'} = 0;		# no of QAS

my $more_debug = 0;	# more debug message if $more_debug = 1

my %options;		# hash used for command line option
my $FH = *STDOUT;	# used for output redirection

# setup commandline options
getopts("dFhNo:Tt:v", \%options);

usage() if exists($options{h}) || !(exists($options{o}) ||
	exists($options{d}) || exists($options{F}) || exists($options{v}) ||
	exists($options{T}) || exists($options{t}) || exists($options{N}) ||
	exists($ARGV[0]) );

if (exists($options{o})) {
  open (OUTPUT, ">>$options{o}") or die "Couldn't write to '$options{o}': $!\n";
  $FH = *OUTPUT;
} # if

if (exists($options{d})) {
  print $FH "Connecting to the database '$dbname'\n" if exists($options{v});
  $dbh = DBI->connect("DBI:mysql:$dbname:$dbhost", $dbuser, $dbpass) ||
      die "# Error: Could not connect to database '$dbname': $?\n";
  DBI->trace(1) if exists($options{v}) && $more_debug;
} # if

for (my $v = 0; $v <= $#ARGV; $v++) {
  my $input_file = $ARGV[$v];

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

  # check for accounting file
  die "Error: CSV file '$input_file' not found.\n" if ! -e $input_file;

  print $FH "Using file '$input_file' as input\n" if exists($options{v});

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
  if ($line =~ /Date,Time,/i) {
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
  else {
    die "# Error: expecting header line, but got '$line'\n"
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
        if (exists($options{F})) {
	  ## drop data table
          print $FH "# debug: dropping table '$table_name'\n" if exists($options{v});
          eval { $dbh->do("DROP TABLE IF EXISTS $table_name"); };
          print $FH "# warning: Dropping table (if exists) $table_name failed: $@\n" if $@;

	  ## drop trasaction table
          print $FH "# debug: dropping table '$txn_tbl_name'\n" if exists($options{v});
          eval { $dbh->do("DROP TABLE IF EXISTS $txn_tbl_name"); };
          print $FH "# warning: Dropping table (if exists) $txn_tbl_name failed: $@\n" if $@;
        } # if

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
) TYPE=MyISAM";

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
  PRIMARY KEY (`uid`)
) TYPE=MyISAM";

        eval { $dbh->do($sql2); };
        die "# Error: cannot create transaction table '$txn_tbl_name': $@\n" if $@;

	my %sql_hash;

        $sql_hash{'select'} = "SELECT * FROM $table_name WHERE epoch=? AND siteID=?;";
	$dbh_hash{'select'} = $dbh->prepare_cached($sql_hash{'select'});
  	die "# Error: cannot prepare_cached sql statement '$sql_hash{'select'}': $@\n" unless defined $dbh_hash{'select'};
	print $FH "# debug: prepare_cached select SQL statement '$sql_hash{'select'}'\n" if exists($options{v});

        $sql_hash{'insert'} = "INSERT INTO $table_name (epoch, siteID, $inst_type, $inst_type"."_flag) VALUES (?, ?, ?, ?);";
	$dbh_hash{'insert'} = $dbh->prepare_cached($sql_hash{'insert'});
  	die "# Error: cannot prepare_cached sql statement '$sql_hash{'insert'}': $@\n" unless defined $dbh_hash{'insert'};
	print $FH "# debug: prepare_cached insert SQL statement '$sql_hash{'insert'}'\n" if exists($options{v});

        $sql_hash{'insert_flag'} = "INSERT INTO $table_name (epoch, siteID, $inst_type"."_flag) VALUES (?, ?, ?);";
	$dbh_hash{'insert_flag'} = $dbh->prepare_cached($sql_hash{'insert_flag'});
  	die "# Error: cannot prepare_cached sql statement '$sql_hash{'insert_flag'}': $@\n" unless defined $dbh_hash{'insert_flag'};
	print $FH "# debug: prepare_cached insert_flag SQL statement '$sql_hash{'insert_flag'}'\n" if exists($options{v});

        $sql_hash{'update'} = "UPDATE $table_name SET $inst_type=?, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
	$dbh_hash{'update'} = $dbh->prepare_cached($sql_hash{'update'});
  	die "# Error: cannot prepare_cached sql statement '$sql_hash{'update'}': $@\n" unless defined $dbh_hash{'update'};
	print $FH "# debug: prepare_cached update SQL statement '$sql_hash{'update'}'\n" if exists($options{v});

        $sql_hash{'update_null'} = "UPDATE $table_name SET $inst_type=NULL, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
	$dbh_hash{'update_null'} = $dbh->prepare_cached($sql_hash{'update_null'});
  	die "# Error: cannot prepare_cached sql statement '$sql_hash{'update_null'}': $@\n" unless defined $dbh_hash{'update_null'};
	print $FH "# debug: prepare_cached update_null SQL statement '$sql_hash{'update_null'}'\n" if exists($options{v});

	if (!exists($options{N})) {
          $sql_hash{'txn_new'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
	  $dbh_hash{'txn_new'} = $dbh->prepare_cached($sql_hash{'txn_new'});
  	  die "# Error: cannot prepare_cached sql statement '$sql_hash{'txn_new'}': $@\n" unless defined $dbh_hash{'txn_new'};
	  print $FH "# debug: prepare_cached tnx_new SQL statement '$sql_hash{'txn_new'}'\n" if exists($options{v});
	} # if

        $sql_hash{'txn_change'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, old_value, old_flag, update_epoch) VALUES (?, ?, ?, ?, ?, ?, ?);";
	$dbh_hash{'txn_change'} = $dbh->prepare_cached($sql_hash{'txn_change'});
  	die "# Error: cannot prepare_cached sql statement '$sql_hash{'txn_change'}': $@\n" unless defined $dbh_hash{'txn_change'};
	print $FH "# debug: prepare_cached tnx_change SQL statement '$sql_hash{'txn_change'}'\n" if exists($options{v});
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
	print $FH "# debug:   mismatched raw '$tmp_list[0] $tmp_list[1]' ($my_epoch) ; site = $site_list[$w] ; raw date = '$tmp_list[$w]'\n" if exists($options{v});
      } # else

      if (exists($options{d})) {
	if (length($flag) > 0) {
          #$sql_hash{'select'} = "SELECT * FROM $table_name WHERE epoch=? AND siteID=?;";
	  eval { $dbh_hash{'select'}->execute($my_epoch, $site_list[$w]); };
          print $FH "# warning: cannot execute select statement with epoch=$my_epoch and site=$site_list[$w]: $@\n" if $@;
	  my $my_ref = $dbh_hash{'select'}->fetchrow_hashref;

	  if ($$my_ref{'epoch'} > 0) {
	    my $old_value = $$my_ref{$inst_type};
	    my $old_flag = $$my_ref{$inst_type.'_flag'};
	    my $update_this = 0;
	    print $FH "# debug:   checking epoch='$$my_ref{'epoch'}' and site='$$my_ref{'siteID'}': $inst_type='$$my_ref{$inst_type}'  $inst_type"."_flag='$$my_ref{$inst_type.'_flag'}'\n" if exists($options{v}) && $more_debug;
	    $update_this ++ if $flag ne $$my_ref{$inst_type.'_flag'};
	    $update_this ++ if length($value) > 0 && $value != $$my_ref{$inst_type};
	    if ($update_this > 0) {
	      if (length($value) > 0) {
	        print $FH "# debug:   update entry for epoch=$my_epoch and site=$site_list[$w]: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v});
                #$sql_hash{'update'} = "UPDATE $table_name SET $inst_type=?, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
	        eval { $dbh_hash{'update'}->execute($value, $flag, $my_epoch, $site_list[$w]); };
                print $FH "# warning: cannot execute update statement for epoch=$my_epoch and site=$site_list[$w]: $inst_type='$value' and $inst_type"."_flag='$flag': $@\n" if $@;
	      } # if
	      else {
	        print $FH "# debug:   update entry for epoch=$my_epoch and site=$site_list[$w]: $inst_type=NULL and $inst_type"."_flag='$flag'\n" if exists($options{v});
                #$sql_hash{'update_null'} = "UPDATE $table_name SET $inst_type=NULL, $inst_type"."_flag=? WHERE epoch=? AND siteID=?;";
	        eval { $dbh_hash{'update_null'}->execute($flag, $my_epoch, $site_list[$w]); };
                print $FH "# warning: cannot execute update_null statement for epoch=$my_epoch and site=$site_list[$w]: $inst_type=NULL and $inst_type"."_flag='$flag': $@\n" if $@;
	      } # else

	      if ($$my_ref{$inst_type.'_flag'} eq 'T') {	# if flag was 'LST'; treat as new update
		if (!exists($options{N})) {
	          ## insert transcation for new data
	          print $FH "# debug:   insert new transaction for epoch=$my_epoch and site=$site_list[$w]: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v});
	          #$sql_hash{'txn_new'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
	          eval { $dbh_hash{'txn_new'}->execute($my_epoch, $site_list[$w], $inst_type, 'N', $download_epoch); };
                  print $FH "# warning: cannot execute insert new transaction statement for epoch=$my_epoch and site=$site_list[$w]: $inst_type \@ ".epoch_to_datetime($download_epoch)." ($download_epoch): $@\n" if $@;
		} # if
		$counter{'new'} ++;
	      } # if
	      else {						# if flag was not 'LST'
	        ## insert transcation for changed data
	        print $FH "# debug:   update transcation for epoch=$my_epoch and site=$site_list[$w]: $inst_type=$$my_ref{$inst_type} and $inst_type"."_flag='$$my_ref{$inst_type.'_flag'}' \@ ".epoch_to_datetime($download_epoch)." ($download_epoch)\n" if exists($options{v});
                #$sql_hash{'txn_change'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, old_value, old_flag, update_epoch) VALUES (?, ?, ?, ?, ?, ?, ?);";
	        eval { $dbh_hash{'txn_change'}->execute($my_epoch, $site_list[$w], $inst_type, 'U', $$my_ref{$inst_type}, $$my_ref{$inst_type.'_flag'}, $download_epoch); };
                print $FH "# warning: cannot execute insert update transaction statement for epoch=$my_epoch and site=$site_list[$w]: $inst_type=$$my_ref{$inst_type} and $inst_type"."_flag='$$my_ref{$inst_type.'_flag'}' \@ ".epoch_to_datetime($download_epoch)." ($download_epoch): $@\n" if $@;
		$counter{'update'} ++;
	      } # else
	    } # if
	    else {
	      print $FH "# debug:   no change in value, skip update for epoch=$my_epoch and site=$site_list[$w]: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v});
	    } # else
	  } # if
	  else {
	    if (length($value) > 0) {
	      ## insert new data
	      print $FH "# debug:   insert entry for epoch=$my_epoch and site=$site_list[$w]: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v});
	      #$sql_hash{'insert'} = "INSERT INTO $table_name (epoch, siteID, $inst_type, $inst_type"."_flag) VALUES (?, ?, ?, ?);";
	      eval { $dbh_hash{'insert'}->execute($my_epoch, $site_list[$w], $value, $flag); };
              print $FH "# warning: cannot execute insert statement for epoch=$my_epoch and site=$site_list[$w]: $inst_type='$value' and $inst_type"."_flag='$flag': $@\n" if $@;

	      if (!exists($options{N})) {
	        ## insert transcation for new data
	        print $FH "# debug:   insert new transaction for epoch=$my_epoch and site=$site_list[$w]: $inst_type='$value' and $inst_type"."_flag='$flag'\n" if exists($options{v});
	        #$sql_hash{'txn_new'} = "INSERT INTO $txn_tbl_name (epoch, siteID, inst, state, update_epoch) VALUES (?, ?, ?, ?, ?);";
	        eval { $dbh_hash{'txn_new'}->execute($my_epoch, $site_list[$w], $inst_type, 'N', $download_epoch); };
                print $FH "# warning: cannot execute insert new transaction statement for epoch=$my_epoch and site=$site_list[$w]: $inst_type \@ ".epoch_to_datetime($download_epoch)." ($download_epoch): $@\n" if $@;
	      } # if
	      $counter{'new'} ++;
	    } # if
	    else {
	      ## no value, only flag
	      print $FH "# debug:   insert entry for epoch=$my_epoch and site=$site_list[$w]: $inst_type"."_flag='$flag'\n" if exists($options{v});
	      #$sql_hash{'insert_flag'} = "INSERT INTO $table_name (epoch, siteID, $inst_type"."_flag) VALUES (?, ?, ?);";
	      eval { $dbh_hash{'insert_flag'}->execute($my_epoch, $site_list[$w], $flag); };
              print $FH "# warning: cannot execute insert_flag statement for epoch=$my_epoch and site=$site_list[$w]: $inst_type"."_flag='$flag': $@\n" if $@;
	    } # else
	  } # else
	} # if
      } # if
      $counter{'entry'} ++;
    } # for

    if (exists($options{d})) {
      my $success = 1;
      #$success &&= $dbh_insertion->execute($tmp_list[0], $tmp_list[1], $tmp_list[2], $tmp_list[3]);
      #my $result = ($success ? $dbh->commit : $dbh->rollback);
      unless ($success) {
        die "# Error: cannot finish insertion for '$line': " . $dbh->errstr;
      }
    } # if

    $prev_table_name = $table_name;
    $counter{'row'} ++;
  } # while

  close INPUT;

  print $FH "# debug: $input_file: ROWs=$counter{'row'} ; Entries=$counter{'entry'} ; New=$counter{'new'} ; Update=$counter{'update'}\n";
} # for

close $FH;

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

  -d		push into database
  -F		don't drop table before creating one
  -h		print usage (this message)
  -N		skip recroding new transcation (will record change/update)
  -o outfile	write output to outfile instead of STDOUT
  -t epoch	overwrite raw data download time; default: extract from file name or use current time
  -T		force using current time as data download time
  -v		verbose output
__usage__
  exit 1;

} # sub usage
