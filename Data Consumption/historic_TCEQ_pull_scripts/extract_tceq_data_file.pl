#!/usr/bin/perl
#
# extract data from screen dump files of data download page on TCEQ internal web site
#
#   http://163.234.120.84/cgi-bin/dataout.pl?cams=35&start_month=4&start_day=28&start_year=2009&end_day=4&database=5m&time_format=UTC&format=comma&include44201=on
#

use strict;
use Getopt::Std;
use POSIX;
use File::Path;
use Time::Local;

my $CAMS_geo_file = 'CAMS.Houston.geo.csv';
my (%CAMS_lat, %CAMS_lon);	# CAMS lat/lon

my %options;			# cmd line options
my $FH = *STDOUT;		# file handler for output

# set command line options
getopts("hHGo:O:v", \%options);

# print usage if needed
usage() if exists($options{h}) || !(exists($options{H}) ||
	exists($options{o}) || exists($options{O}) || exists($options{v}) ||
	exists($options{G}) ||
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
} # while
close CAMS;

#
# read all input directories
#
for (my $v = 0; $v <= $#ARGV; $v++) {
  $ARGV[$v] =~ s/\/$//;		# remove tailing '/'

  print "## processing $ARGV[$v]\n" if exists($options{v}) && exists($options{o});
  print $FH "## processing $ARGV[$v]\n" if exists($options{v});

  my %hash_date_time;		# hash for date time index
  my %hash_epoch;		# hash for epoch time
  my %hash_site_id;		# hash for site id

  opendir (DIR, $ARGV[$v]) or die "#Error: cannot open directory '$ARGV[$v]': $?\n";
  my @files = readdir(DIR);
  foreach my $f (@files) {
    next if $f =~ /^\.+$/;

    print "# debug: processing $ARGV[$v]/$f\n" if exists($options{v});
    my $CAM_id = $f;
    $CAM_id =~ s/CAMS\.(\d+)\.txt/$1/;
    print "# debug: CAM_id = $CAM_id\n" if exists($options{v});

    open (INPUT, "<$ARGV[$v]/$f") or die "# Error: cannot open input file '$ARGV[$v]/$f': $?\n";

    while (my $line = <INPUT>) {
      last if $line =~ /Date,Time,/;	# skip everything up till "Date,Time,"
    } # while

    # now good stuff
    my $counter = 0;
    my $counter_QAS = 0;
    my %tmp_hash;	# temp hash for Ozone data

    while (my $line = <INPUT>) {
      chomp($line);
      last if $line =~ /^\s*$/;
      $line =~ s/^\s+//;		# remove leading blanks
      $line =~ s/\s+$//;		# remove tailing blanks
      my @tmp_list = split /,/, $line;	# split CSV

      if ($tmp_list[2] =~ /\[.*\]/) {	# skip QAS state
	$counter_QAS++;
	next;
      } # if

      my $key_date_time = "$tmp_list[0],$tmp_list[1]";
      $hash_date_time{$key_date_time} = 1;

      my ($month,$day,$year) = split /\//, $tmp_list[0];
      my ($hours,$min,$sec) = split /:/, $tmp_list[1];
      $month = $month/1 - 1;		# month: 0..11
      my $epoch = timegm($sec,$min,$hours,$day,$month,$year);
      $hash_epoch{$epoch} = 1;
      
      $tmp_hash{$epoch} = $tmp_list[2];

      $counter++;
      #print $FH "# input data [$counter]/$epoch: '$line'\n" if exists($options{v});
    } # while

    
    print $FH "## end of file '$f': has $counter lines of data and $counter_QAS in QAS\n" if exists($options{v});

    $hash_site_id{$CAM_id} = \%tmp_hash if $counter > 0;

    close INPUT;
  } # foreach

  my $CFH = *STDOUT;		# file handler for output
  if (exists($options{O})) {
    open (CSVOUTPUT, ">$options{O}") or die "Couldn't write to '$options{O}': $?\n";
    $CFH = *CSVOUTPUT;
  } # if

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
} # for

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
  print $FH "Usage: $0 [options] data_dir\n";
  print $FH <<__usage__;
  -h	    	print usage
  -H	    	print 2nd header with local date time (instead of epoch time)
  -G	    	print 2nd header with GMT date time (instead of epoch time)
  -o outfile	write message/log to outfile instead of STDOUT
  -O CSVfile	write output to CSVfile instead of STDOUT
  -v		verbose output
__usage__
  exit; 
} # sub usage
