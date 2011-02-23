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

my $nds = $dts->count_datasubset();
print "$nds data subsets\n";
for( my $sno = 0; $sno < $nds; $sno ++ ) {
	my $ds = $dts->get_datasubset($sno);
	ok( defined $ds );
	my $nd = $ds->count_descriptor();
	print "$nd descriptors in datasubset $sno\n";
	for( my $dno = 0; $dno < $nd; $dno ++ ) {
		my $d = $ds->get_descriptor($dno);
		ok( defined $d );

		my $e = $tables->lookup($d->descriptor());
		# if it wasn't in the tables, we couldn't decode
		ok( defined $e || !($d->is_table_b() || $d->is_table_d()) );

		my $val = $d->get();
		print $d->descriptor(), ': ',
			(defined($val) ? $val : '<no value>'),
			' (', $d->flags(), ')',
			;

		if( defined $e ) {
			if( $e->isa('Geo::BUFR::EC::Tables::Entry::B') ) {
				print '  ', $e->unit();
			} elsif( $e->isa('Geo::BUFR::EC::Tables::Entry::D') ) {
				print '  ', length($e->descriptors()), ' descriptors';
			}
		}

		print "\n";
	}
}

done_testing();

exit 0;
