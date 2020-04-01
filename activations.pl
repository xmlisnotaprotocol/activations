#!/usr/bin/perl
#
# PoC Script to go out on the net to the IBM POD site and tally up activations for a given i or p Series machine
# Chris-R rutherfc@gmail.com
# v1.0 9/9/2011
# v2.0 	1/4/2020 update for perl 5 no subsciprts starting at 1 and changes to www-912.ibm.com/pod/pod
#
# todo - add logic for processor deactivation - who uses that? IBM dont even publish the code on the pod site ;)
# perhaps start with the machines base config from IBM
#
use LWP::UserAgent;
$ua = LWP::UserAgent->new;
$ua->agent("mozilla 8.0");
# $ua->proxy(['http'], 'http://proxy:8080/'); # proxy support
$ua->timeout(10);
use HTTP::Request::Common qw(POST);
if ($#ARGV != 2) {
print "usage: $0 MODEL XX XXXXX e.g $0 9119 83 9f6bf\n";
exit;
}
($model, $serial1, $serial2) = @ARGV;

##### main #####
get('http://www-912.ibm.com/pod/pod',"$serial2.htm");
html2txt("$serial2.htm","$serial2.txt");
total("$serial2.txt");
exit;
################
sub get # fakes a mozilla browser, fills in the CGI form and snags the returned page to a local html file
{
	my $req = (POST $_[0],
	["system_type" => $model,
	"system_serial_number1" => $serial1,
	"system_serial_number2" => $serial2 ]);
	$request = $ua->request($req);
	$activations = $request->content;
	open(POD,">$_[1]");
	print POD $activations;
	close(POD);
}

sub html2txt # strips out the crap and converts the table to a local txt file to parse
{
	open(HTML,"<$_[0]");
	open(TXT,">$_[1]");
	while (<HTML>) {
		if (/<\/table>/) {$f = 0;};
		if (/<th>Posted Date \(MM/) {$f = 1;}; # find top of table
		if ($f == 1) {
			# poor mans HTML::TableExtract - excuse my sed like perl....
			s/\x09//g;
			s/\n//g;
			s/\<.tr\>/\n/g; # swap rows for CR
			s/\<.td\>/,/g;  # swap divs for commas
			s/<[^>][^>]*>/ /g; # remove tags
			s/ //g;
			print TXT $_;
		#print $_ ; # debug
		};
	};
	close(TXT);
	close(HTML);
}
sub total # totals up the de/activations to get totals
{
	open(TXT,"<$_[0]");
	$[ = 0; $\ = "\n";# set array base & output record separator
	while (<TXT>) {
		($code,$hex,$date) = split(',', $_, -1);
		#print 'CODE='.$code.'HEX='.$hex.'DATE='.$date ; # debug
		if (/POD/) {
			$p = int(substr($hex, 25, 3));
			print $p . ' processors activated on ' . $date;
			$pt = $pt + $p;
		};
		if (/MOD/) {
			$r = int(substr($hex, 23, 5));
			print $r . ' GB memory activated on ' . $date;
			$rt = $rt + $r;
		};
		if (/RMEM/) {
			$r = int(substr($hex, 25, 3));
			print $r . ' GB memory activated on ' . $date;
			$rt = $rt - $r;
		};
	};
	print '================';
	print 'TOTAL CPU=' . $pt . ' RAM=' . $rt*1024 . 'MB (' . $rt . 'GB)';
	close(TXT);
}
