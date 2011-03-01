# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Geo-BUFR-EC.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
BEGIN { use_ok('Geo::BUFR::EC') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

$ENV{BUFR_TABLES} = '/usr/share/libecbufr/';

my $bulletin = '';
open(my $f, '<', 't/sample.bufr') || die $!;
$bulletin .= $_ while(<$f>);
close $f;

my $msg = Geo::BUFR::EC::Message->fromString($bulletin);
ok( defined $msg );

$tables = Geo::BUFR::EC::Tables->new();
ok( defined $tables );
$tables->cmc();

my $dts = $msg->decode($tables);
ok( defined $dts );

my $ds = $dts->get_datasubset(0);
ok( defined $ds );

my $pos = 0;
my $n = 0;
while(defined $pos) {
	$pos = $ds->find_descriptor(20012, $pos);
	if( defined $pos ) {
		my $desc = $ds->get_descriptor($pos);
		ok( defined $desc );
		my $val = $desc->get() || '<missing>';
		print $desc->descriptor(), " => ", $val, "\n";
		$pos ++;
		$n ++;
	}
}

ok( $n == 8 );
ok( not defined $pos );

done_testing();

exit 0;
