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

my $s1 = $msg->section1();
ok( defined $s1 );

print "Section 1 keys are:", join(', ', keys(%{$s1})), "\n";

printf "Message from %04d-%02d-%02d %02d:%02d:%02d\n",
	@{$s1}{qw/year month day hour minute second/};

$tables = Geo::BUFR::EC::Tables->new();
ok( defined $tables );

ok( not defined $tables->master_version() );
ok( not defined $tables->local_version() );

$tables->cmc();

ok( defined $tables->master_version() );
ok( $tables->master_version() > 12 );

# default libecbufr tables have no local descriptors
ok( not defined $tables->local_version() );

print "Table versions: master=", $tables->master_version(), "\n";

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

exit 0;
