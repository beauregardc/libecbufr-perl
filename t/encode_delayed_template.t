# see encode_delayed.t for the basics of what we're trying here

use Test::More qw/no_plan/;
BEGIN { use_ok('Geo::BUFR::EC') };

$ENV{BUFR_TABLES} = '/usr/share/libecbufr/';

$tables = Geo::BUFR::EC::Tables->new();
ok( defined $tables );
$tables->cmc();

my $tmpl = Geo::BUFR::EC::Template->new($tables);
ok( defined $tmpl );

# simple Table D operator with containing a delayed replication of
# a single Table B value.
my $dv = Geo::BUFR::EC::DescValue->new('3-21-012');
ok( defined $dv );
$tmpl->add_DescValue($dv);
$tmpl->finalize();

my $dts = Geo::BUFR::EC::Dataset->new($tmpl);
ok( defined $dts );

$dts->section1()->{master_table_version} = $tables->master_version();

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

# easier than remembering what 2135 means...
my $e = $tables->lookup('ANTENNA ELEVATION');
ok( defined $e );

my $elev = 1;
$pos = 0;
while( defined $pos ) {
	$pos = $ds->find_descriptor($e->descriptor(), $pos);
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

exit 0;
