#!/usr/bin/perl

#
# Push data_extractor raw data file to database, with state for input files
#
# Created: 09/02/2011
# Modified: 01/06/2015
#
# Author: Jeff Williams
#
# Updated: 12/11/2013
# Change for TCEQ push data
# Updated: 01/06/2015
# Change for year 2015
# Updated: 01/11/2016
# Change for year 2016
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
my $startTime;
my $timeout;

$timeout = 90;
$startTime = time();
  
$dbh = DBI->connect("DBI:mysql:$dbname:$dbhost", $dbuser, $dbpass);

$sqlSelect = "SELECT epoch FROM ibh_data_year_2016 WHERE redraw = 1 AND o3_flag IS NOT NULL GROUP BY epoch ORDER BY epoch DESC";

$sqlUpdate =  "UPDATE ibh_data_year_2016 SET redraw = 0 WHERE epoch = ?";

$sth = $dbh->prepare($sqlSelect) or die "SQL Error: $DBI::errstr\n";
$sth->execute() or die "SQL Error: $DBI::errstr\n";

while (@row = $sth->fetchrow_array()) {
	push(@epochs,$row[0]);
}

$sth->finish;

$sth = $dbh->prepare($sqlUpdate) or die "Couldn't prepare statement: $DBI::errstr\n";

print "Found " . @epochs . " epochs to process...\n";

foreach $epoch (@epochs) {
	if ((time()-$startTime) < (60*13)) {
		print "=====================\nbeginning epoch $epoch...\n";
		print scalar(localtime($epoch));
		print "\n";
		my $b0_output=timeout_command($timeout,qq(php calculategrid.php $epoch -1 0)) or die "Couldn't execute php";
		print "$b0_output";
        	my $param_output=timeout_command($timeout,qq(php calculateparamgrid.php $epoch nox -1)) or die "Couldn't execute php";
		print "$param_output";
		my $b4_output=timeout_command($timeout,qq(php calculategrid.php $epoch -1 4)) or die "Couldn't execute php";
		print "$b4_output";
		if (substr($b0_output,0,length("Contour Saved to file!!")) eq "Contour Saved to file!!") {
			$sth->execute($epoch) or die "SQL Error: $DBI::errstr\n";
		}
	}
};

$dbh->disconnect;

sub timeout_command {
        my $timeout = (shift);
        my @command = @_;
        undef $@;
        my $pid;
        my $return  = eval {
                $pid = open(CMD, '-|', @command) || return "couldn't run @command: $!\n";
                local($SIG{ALRM}) = sub {die "timeout";};
                alarm($timeout);
                my $response;
                print "<$pid> @command\n";
                while(<CMD>) {
                        $response .= $_;
                }
                close(CMD) || warn $! ?  "Couldn't close execution of @command: $!\n" : "Exit status $? from @command";
                $response;
        };
        alarm(0);
        if ($@) {
                kill(3, $pid) || warn "couldn't kill $pid: $!";
                return  "TIMEOUT!!! [killed pid $pid]\n";
        }
        return $return;
}
