use Test::More qw/no_plan/;
BEGIN { use_ok('Geo::BUFR::EC') };

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

exit 0;
