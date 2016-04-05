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
my $dbpass = "worker4iBH";
my $dbhost = "can.cdspk1y1mo9a.us-west-2.rds.amazonaws.com";
my $dbname = "ibreathedb";
my $dbport = "3306";

# DBI handler
my $dbh;
my $sth;
my @row;
my @epochs;
my $epoch;
my $sqlSelect;
my $sqlUpdate;
  
$dbh = DBI->connect("DBI:mysql:$dbname:$dbhost", $dbuser, $dbpass);

$sqlSelect = "SELECT epoch FROM (SELECT DISTINCT epoch FROM ibh_data_year_2014 WHERE redraw = 1 AND o3 IS NOT NULL AND epoch <= 1394493100) AS t1 WHERE t1.epoch NOT IN (SELECT epoch FROM aggregate_o3_epoch) ORDER BY epoch DESC";

$sqlUpdate =  "UPDATE ibh_data_year_2014 SET redraw = 0 WHERE epoch = ?";

$sth = $dbh->prepare($sqlSelect) or die "SQL Error: $DBI::errstr\n";
$sth->execute() or die "SQL Error: $DBI::errstr\n";

while (@row = $sth->fetchrow_array()) {
	push(@epochs,$row[0]);
}

$sth->finish;

$sth = $dbh->prepare($sqlUpdate) or die "Couldn't prepare statement: $DBI::errstr\n";

print "Found " . @epochs . " epochs to process...\n";

foreach $epoch (@epochs) {
	print "=====================\nbeginning epoch $epoch...\n";
        print scalar(localtime($epoch));
	print "\n";
	my $b4_output=`php calculategrid.php $epoch -1 4` or die "Couldn't execute php";
	print "$b4_output";
        my $param_output=`php calculateparamgrid.php $epoch nox -1` or die "Couldn't execute php";
	print "$param_output";
	my $output=`php calculategrid.php $epoch -1 0` or die "Couldn't execute php";
	print "$output";
	if (substr($output,0,length("Contour Saved to file!!")) eq "Contour Saved to file!!") {
		$sth->execute($epoch) or die "SQL Error: $DBI::errstr\n";
	}
};

$dbh->disconnect;
 
