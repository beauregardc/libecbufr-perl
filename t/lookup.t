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

$tables = Geo::BUFR::EC::Tables->new();
ok( defined $tables );
$tables->cmc();

my $e = $tables->lookup(4004);
ok( defined $e );
ok( $e->descriptor() == 4004 );

$e = $tables->lookup($e);
ok( defined $e );
ok( $e->descriptor() == 4004 );

$e = $tables->lookup('0-04-004');
ok( defined $e );
ok( $e->descriptor() == 4004 );

$e = $tables->lookup('ANTENNA ELEVATION');
ok( defined $e );
ok( $e->descriptor() == 2135 );

$e = $tables->lookup(4004, 4005, 4006);
ok( defined $e );
ok( $e->descriptor()==301013 );

exit 0;
