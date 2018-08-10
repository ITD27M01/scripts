#!/usr/bin/perl -w
use strict;
use warnings;
use SNMP;
use Socket;
use lib "/usr/lib/nagios/plugins";
use utils qw(%ERRORS);
use Getopt::Long;

# LOAD MIBS AND INIT SNMP
&SNMP::addMibDirs("/usr/share/snmp/mibs/");
&SNMP::loadModules("ALL");
&SNMP::initMib();
# VARIABLES
my $comm = 'public';
my $sver = '2c';
my $AS = 1;
my $count;
my $peerip;
my $oktet;
my $substr = '';
my $dest = '0';
my $sess;
my %snmpparms;
my $arg;
my $vb;
my $var;
my $opts;
my $errnum = $ERRORS{'OK'};

sub usage {
  printf "\nMissing arguments!\n";
  printf "\n";
  printf "checks operation of the EIGRP protocol and list of neighbors\n";
  printf "usage: \n";
  printf "check_eigrp.pl -H hostipaddress -n neighbors -a EIGRP AS number [-C community] [-v]\n";
  printf "\n\n";
  exit $ERRORS{"UNKNOWN"};
}

$opts = GetOptions("community=s",\$comm,
                     "hostipaddress=s",\$dest,
                     "asnumber=i",\$AS,
                     "neighbors=i",\$count);
if ($opts == 0)
{
        &usage;
}

## SET OID
my $peeripoid = "1.3.6.1.4.1.9.9.449.1.4.1.1.3.0.$AS";
my $peercount = "1.3.6.1.4.1.9.9.449.1.2.1.1.2.0.$AS";
## SET PARAMETERS FOR SNMP SESSION
$snmpparms{Community} = $comm;
$snmpparms{Version} = $sver;
$snmpparms{UseSprintValue} = '1';
$snmpparms{DestHost} = inet_ntoa(inet_aton($dest));
## NEW SNMP SESSION
$sess = SNMP::Session->new(%snmpparms);
## GET NEIGHBORS COUNT VALUE
$vb = SNMP::Varbind->new([$peercount,'']);
$peercount = $sess->get($vb);
## CHECK FOR ERRORS AND GET NEIGHBORS IP VALUE
if ($sess->{ErrorNum}) {
        print "ERROR \"$sess->{ErrorStr}\" querying $dest.\n";
        exit $ERRORS{'CRITICAL'};
}
else {
	if ( $peercount =~ /^No/ ) {
		print "ERROR \"$peercount\" querying $dest.\n";
		exit $ERRORS{'UNKNOWN'};
	}
	else {
		if ( $peercount != $count ) {
			print "WARNING: The number of neighbors has changed. Total neighbors is $peercount. Should be $count.\n";
			$errnum = $ERRORS{'WARNING'};
		}
		if ( $peercount < 2 ) {
			print "I have $peercount EIGRP neighbor:\n";
		}
		else {
			print "I have $peercount EIGRP neighbors:\n";
		}
		my $i;
		my $j;
		for ( $i = 0; $i < $peercount; $i++ ) {
			$vb = SNMP::Varbind->new(["$peeripoid.$i",'']);
			$peerip = $sess->get($vb);
			for ( $j =1; $j < 4; $j++) {
				$peerip =~ s/ /./;
			}
			$peerip =~ s/"//g;
			for ( $j=0; $j < 4; $j++ ) {
				$oktet = substr($peerip, 3*$j, 2);
				$oktet = hex($oktet);
				$substr = "$substr.$oktet";
			}
			$substr =~ s/.//;
			print "\t",$substr,"\n";
			$substr = '';
		}
	}
}
exit $errnum;
