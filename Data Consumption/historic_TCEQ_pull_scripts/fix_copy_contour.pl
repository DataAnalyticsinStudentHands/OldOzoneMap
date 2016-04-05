#!/usr/bin/perl
#
# copy contour from previous timestamp
#
# Created: 08/19/2012
# Modified: 08/19/2012
#
# Author: T. Mark Huang
#

use strict;
use Getopt::Std;	# command line option
use Time::Local 'timegm';	# for converting date/time to epoch


my $contour_top_dir = '/mnt/ibreathe/generatedcontour';
my $base_epoch_unit = 300;	# 5 min
my $band = 4;

my %options;            # hash used for command line option
my $FH = *STDOUT;       # used for output redirection

# setup commandline options
getopts("b:ho:v", \%options);

usage() if exists($options{h}) || !(exists($options{o}) ||
        exists($options{v}) || exists($options{b}) ||
        exists($ARGV[0]) );

if (exists($options{o})) {
  open (OUTPUT, ">>$options{o}") or die "Couldn't write to '$options{o}': $!\n";
  $FH = *OUTPUT;
} # if

if ($ARGV[0] !~ /\d+/) {
  print $FH "# Error: epoch time expected (getting '$ARGV[0]')\n";
  usage();
} # if

if (exists($options{b})) {
  $band = $options{b};
} # if

my $dest_epoch = $ARGV[0];
my $src_epoch = $dest_epoch - $base_epoch_unit;
my $src_fname = "$contour_top_dir/".epoch_to_date_str($src_epoch).'/'.$src_epoch."_bs$band.js";
my $dest_fname = "$contour_top_dir/".epoch_to_date_str($dest_epoch).'/'.$dest_epoch."_bs$band.js";

print $FH "# target epoch = $dest_epoch (".epoch_to_datetime($dest_epoch).")\n" if exists($options{v});
print $FH "# src epoch = $src_epoch (".epoch_to_datetime($src_epoch).")\n" if exists($options{v});

print $FH "# debug: dest_fname = '$dest_fname'\n" if exists($options{v});
print $FH "# debug: src_fname = '$src_fname'\n" if exists($options{v});

open(INPUT, "<$src_fname") or
  die "# Error: [$dest_epoch] target source file '$src_fname' not found\n";

my @input_src = <INPUT>;

#print $FH "# debug: length \@input_src = ".scalar(@input_src)."\n" if exists($options{v});

# sample input: contourData1342550700({"status":{
if ($input_src[0] !~ /^contourData\d+\(/) {
  die "# Error: [$dest_epoch] incomplete data in source file '$src_fname': contourData\n";
}
# sample input: "timestamp":1342550700,
elsif ($input_src[0] !~ /"timestamp":\d+/) {
  die "# Error: [$dest_epoch] incomplete data in source file '$src_fname': timestamp\n";
} # if

# sample input: contourData1342550700({"status":{
$input_src[0] =~ s/^contourData$src_epoch\(/contourData$dest_epoch(/;
# sample input: "message":"18 contour lines for 1342550700 (tentative msg)"},
$input_src[0] =~ s/contour lines for $src_epoch \(/contour lines for $dest_epoch (/;
# sample input: "timestamp":1342550700,
$input_src[0] =~ s/"timestamp":$src_epoch,/"timestamp":$dest_epoch,/;


#my $out_file = '/tmp/test.aa.txt';
my $out_file = $dest_fname.".tmp";
open (MYOUTPUT, ">$out_file") or die "# Error: cannot write to output file '$out_file': $?\n";

print $FH "# debug: write to output file '$out_file'\n" if exists($options{v});

print MYOUTPUT $input_src[0];

close MYOUTPUT;

my $mode = 0664;
chmod $mode, $out_file;

close $FH;

#------------------------------------
#
# convert epoch to date string for dir listing
#
sub epoch_to_date_str {

  my ($epoch) = @_;

  my ($sec, $min, $hour, $day, $month, $year) = (localtime($epoch))[0,1,2,3,4,5,6];
  my $date_str = sprintf "%d/%02d/%02d", $year+1900, $month+1, $day;

  return $date_str;
} # sub epoch_to_date_str


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

  print $FH "Usage: $0 epoch\n";
  print $FH <<__usage__;

  -b band	band schema (default 4)
  -h		print usage (this message)
  -o outfile	write output to outfile instead of STDOUT
  -v		verbose output
__usage__
  exit 1;

} # sub usage
