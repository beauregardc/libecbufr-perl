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

$tables = Geo::BUFR::EC::Tables->new();
ok( defined $tables );
$tables->cmc();

my $tmpl = Geo::BUFR::EC::Template->new($tables);
ok( defined $tmpl );

# **Hour,minute,second
# 301013 004004 004005 004006
$tmpl->add_DescValue(Geo::BUFR::EC::DescValue->new(301013));
$tmpl->finalize();

# we're going to build a message with several datasubsets containing different
# h/m/s values...
my $dts = Geo::BUFR::EC::Dataset->new($tmpl);
ok( defined $dts );

my $s1 = $dts->section1();
ok( defined $s1 );

my $now = time();
my @t = gmtime($now);
@{$s1}{qw/year month second minute hour day/}
	= ($t[5]+1900, $t[4]+1, @t[0 .. 3]);

for( my $i = 0; $i < 4; $i ++, $now += 12 ) {
	my $ds = Geo::BUFR::EC::DataSubset->new($dts);
	ok(defined $ds);

	@t = gmtime($now);

	# FIXME: we could probably do this nicer if we exposed more
	# of the decoding functions in the API...
	for( my $dno = 0; $dno < $ds->count_descriptor(); $dno ++ ) {
		my $d = $ds->get_descriptor($dno);
		ok( defined $d );
		next unless $d->is_table_b();

		if( $d->descriptor() == 4004 ) {
			# hour
			$d->set( $t[2] );
		} elsif( $d->descriptor() == 4005 ) {
			# minute
			$d->set( $t[1] );
		} elsif( $d->descriptor() == 4006 ) {
			# second
			$d->set( $t[0] );
		}
	}
}

my $message = Geo::BUFR::EC::Message->encode($dts);
ok( defined $message );

my $s = $message->toString();
ok( defined $s );

open (my $fh, '>', 't/encoded.bufr') || die $!;
print $fh $s;
close $fh;

done_testing();
exit 0;
