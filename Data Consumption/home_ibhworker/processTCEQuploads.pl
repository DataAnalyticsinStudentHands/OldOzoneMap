#!/usr/bin/perl

#
# Push data_extractor raw data file to database, with state for input files
#
# Created: 09/02/2011
# Modified: 07/21/2012
#
# Author: Jeff Williams
#
# Updated: 12/11/2013
# Change for TCEQ push data
#
#
#

use strict;
use Getopt::Std;	# command line option
use DBI; 		# use dbi for database connection
use File::Copy;

my $dbuser = "ibhworker";
my $dbpass = "*****";
my $dbhost = "can.cdspk1y1mo9a.us-west-2.rds.amazonaws.com";
my $dbname = "ibreathedb";
my $dbport = "3306";

# DBI handler
my $dbh;
my $sqlPush;
my $sqlProcess;

$dbh = DBI->connect("DBI:mysql:$dbname:$dbhost", $dbuser, $dbpass);

$sqlPush = "
LOAD DATA LOCAL INFILE ?
INTO TABLE ibh_tceq_push
FIELDS TERMINATED BY '|'
LINES TERMINATED BY '\n'
(siteID, timeStamp, param, poc, method, units, value, flag, verified, slope, intercept, sample)
SET filename = ?, processed = 0;";

$sqlProcess =  "CALL processTCEQData(?);";

my @files = </home/tceq/uploads/*.tems>;

my $file;
my $fileName;
my $fileDir;
my $archiveDir = "/home/ibhworker/mnt/tcequploads/processed/";

my $start_run;
my $end_run;
my $run_time;

foreach $file (@files) {

    #get path information
    ($fileDir,$fileName) = $file =~ m|^(.*[/\\])([^/\\]+?)$|;

    #insert raw data into ibh_tceq_push
    $dbh->prepare($sqlPush)->execute($file, substr($file, index(".tems", $file)-24, 14));

    #process newly inserted data in database...
    $start_run = time();
    $dbh->prepare($sqlProcess)->execute(substr($file, index(".tems", $file)-24, 14));
    $end_run = time();
    $run_time = $end_run - $start_run;

    #debug status
    print "sqlProcess completed $fileName - time $run_time seconds;\n";

    #if archive dir doesn't exist then create it
    if (not -d $archiveDir) {
        mkdir $archiveDir;
    };
    #move proccessed files to archive directory
    move($file, $archiveDir . $fileName) || die "Failed to move files: $!";
};

$dbh->disconnect;

my $output=`perl processRedraws.pl` or die "Couldn't execute php";
print $output;
