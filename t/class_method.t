use Test::More qw/no_plan/;
BEGIN { use_ok('Geo::BUFR::EC') };

is( Geo::BUFR::EC::Descriptor::is_descriptor(1009), 1 );
is( Geo::BUFR::EC::Descriptor::is_descriptor(500000), 0 );

is( Geo::BUFR::EC::Descriptor::is_qualifier(1009), 1 );
is( Geo::BUFR::EC::Descriptor::is_qualifier(16009), 0 );

is( Geo::BUFR::EC::Descriptor::is_local(1009), 0 );
is( Geo::BUFR::EC::Descriptor::is_local(1196), 1 );

is( Geo::BUFR::EC::Descriptor::is_table_b(1009), 1 );
is( Geo::BUFR::EC::Descriptor::is_table_b(201002), 0 );

is( Geo::BUFR::EC::Descriptor::is_table_c(1009), 0 );
is( Geo::BUFR::EC::Descriptor::is_table_c(201002), 1 );

is( Geo::BUFR::EC::Descriptor::is_replicator(101001), 1 );
is( Geo::BUFR::EC::Descriptor::is_replicator(201002), 0 );

is( sprintf('%01d-%02d-%03d',Geo::BUFR::EC::Descriptor::to_fxy(101001)), '1-01-001' );

exit 0;
