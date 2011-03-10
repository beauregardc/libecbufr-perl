use Test::More qw/no_plan/;
BEGIN { use_ok('Geo::BUFR::EC') };

$ENV{BUFR_TABLES} = '/usr/share/libecbufr/';

$tables = Geo::BUFR::EC::Tables->new();
ok( defined $tables );
$tables->cmc();

my $tmpl = Geo::BUFR::EC::Template->new($tables);
ok( defined $tmpl );

# template with a delayed replication of a channel number.
$tmpl->add_DescValue(Geo::BUFR::EC::DescValue->new(101000));
$tmpl->add_DescValue(Geo::BUFR::EC::DescValue->new(31002));

my $d = Geo::BUFR::EC::Descriptor->new($tables,5042);
$d->set(1);
my $v = $d->value();
$tmpl->add_DescValue(
	Geo::BUFR::EC::DescValue->new($d->descriptor(),$v));
$tmpl->finalize();

my $dts = Geo::BUFR::EC::Dataset->new($tmpl);
ok( defined $dts );

my $ds = Geo::BUFR::EC::DataSubset->new($dts);
ok(defined $ds);

my $pos = $ds->find_descriptor(31002);
ok(defined $pos);
my $desc = $ds->get_descriptor($pos);
ok( defined $desc );

# we'll replicate this thing five times.
$desc->set(5);

# expand the replicator factor. Note that there's only
# one datasubset, so we don't bother with the position
# parameter
$dts->expand_datasubset();

# Note that we don't retrieve the datasubset again... the expansion
# affected the working copy. This _would_ play havok with any iteration
# we were doing over the datasubset, however.

# there's more than one way to do this, but we're just going to
# set each replicated channel number (0-05-042) to an increasing
# value.
my $channel = 1;
$pos = 0;
while( defined $pos ) {
	$pos = $ds->find_descriptor(5042, $pos);
	last unless defined $pos;

	$desc = $ds->get_descriptor($pos);
	ok(defined $desc);

	# at least one undef, to test...
	$desc->set(($channel!=3) ? $channel : undef);

	$pos ++;	# start at the next value
	$channel ++;
}

my $message = Geo::BUFR::EC::Message->encode($dts);
ok( defined $message );

my $s = $message->toString();
ok( defined $s );

open (my $fh, '>', 't/encode_delayed.bufr') || die $!;
print $fh $s;
close $fh;

exit 0;
