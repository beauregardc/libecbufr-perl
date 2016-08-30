# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Geo-BUFR-EC.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More qw/no_plan/;
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

ok( not defined $tables->master_version() );
ok( not defined $tables->local_version() );

$tables->cmc();

my $dts = $msg->decode($tables);
ok( defined $dts );

my $nds = $dts->count_datasubset();
print "$nds data subsets\n";
for( my $sno = 0; $sno < $nds; $sno ++ ) {
	$dts->expand_datasubset($sno);
	my $ds = $dts->get_datasubset($sno);
	ok( defined $ds );

	my $dno = 0;
	while( defined($dno = $ds->find_descriptor(20054, $dno+1) ) ) {
		my $d = $ds->get_descriptor($dno);
		my @quals = $d->qualifiers();
		ok( @quals > 0 );
		my @quals = $d->qualifiers(8002);
		ok( @quals == 1 );
		print "qualifier ",$quals[0]->descriptor(), " => ",
			$quals[0]->get(), "\n";
	}
}

exit 0;
