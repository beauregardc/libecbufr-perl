# see encode_delayed.t for the basics of what we're trying here

use Test::More;
BEGIN { use_ok('Geo::BUFR::EC') };

$ENV{BUFR_TABLES} = '/usr/share/libecbufr/';

$tables = Geo::BUFR::EC::Tables->new();
ok( defined $tables );
$tables->cmc();

my $tmpl = Geo::BUFR::EC::Template->new($tables);
ok( defined $tmpl );

# simple Table D operator with containing a delayed replication of
# a single Table B value.
$tmpl->add_DescValue(Geo::BUFR::EC::DescValue->new(321012));
$tmpl->finalize();

my $dts = Geo::BUFR::EC::Dataset->new($tmpl);
ok( defined $dts );

my $ds = Geo::BUFR::EC::DataSubset->new($dts);
ok(defined $ds);

# find the replication factor... we've only got one to worry about
my $pos = $ds->find_descriptor(31001);
ok(defined $pos);
my $desc = $ds->get_descriptor($pos);
ok( defined $desc );

# we'll replicate this thing eight times.
$desc->set(8);

# expand the replicator factor.
$dts->expand_datasubset();

my $elev = 1;
$pos = 0;
while( defined $pos ) {
	$pos = $ds->find_descriptor(2135, $pos);
	last unless defined $pos;

	$desc = $ds->get_descriptor($pos);
	ok(defined $desc);

	$desc->set($elev);

	$pos ++;	# start at the next value
	$elev ++;
}

my $message = Geo::BUFR::EC::Message->encode($dts);
ok( defined $message );

my $s = $message->toString();
ok( defined $s );

open (my $fh, '>', 't/encode_delayed_template.bufr') || die $!;
print $fh $s;
close $fh;

done_testing();
exit 0;
