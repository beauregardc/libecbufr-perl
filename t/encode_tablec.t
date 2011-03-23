use Test::More qw/no_plan/;
BEGIN { use_ok('Geo::BUFR::EC') };

$ENV{BUFR_TABLES} = '/usr/share/libecbufr/';

$tables = Geo::BUFR::EC::Tables->new();
ok( defined $tables );
$tables->cmc();

my $tmpl = Geo::BUFR::EC::Template->new($tables);
ok( defined $tmpl );

# Table C operator
my $ts = 'This is a test';
my $dv = Geo::BUFR::EC::DescValue->new(205000 + length($ts));
ok( defined $dv );
$tmpl->add_DescValue($dv);
$tmpl->finalize();

my $dts = Geo::BUFR::EC::Dataset->new($tmpl);
ok( defined $dts );

$dts->section1()->{master_table_version} = $tables->master_version();

my $ds = Geo::BUFR::EC::DataSubset->new($dts);
ok(defined $ds);

my $desc = $ds->get_descriptor(0);
ok( defined $desc );

$desc->set($ts);

my $message = Geo::BUFR::EC::Message->encode($dts);
ok( defined $message );

my $s = $message->toString();
ok( defined $s );

open (my $fh, '>', 't/encode_tablec.bufr') || die $!;
print $fh $s;
close $fh;

exit 0;
