use strict;
use CGI::Wiki::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
}

eval { require Plucene; };
if ( $@ ) {
    plan skip_all => "Plucene not installed";
}

# Strictly speaking we don't need to skip _all_ tests if we don't have
# the modules below.  Revisit this when not in a hurry.
# We only actually need the former for the National Grid tests and the
# latter for the UTM tests.
eval { require Geography::NationalGrid; };
if ( $@ ) { 
    plan skip_all => "Geography::NationalGrid not installed";
}

eval { require Geo::Coordinates::UTM; };
if ( $@ ) { 
    plan skip_all => "Geo::Coordinates::UTM not installed";
}

plan tests => 53;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Config->new(
       vars => {
                 dbtype             => "sqlite",
                 dbname             => "t/node.db",
                 indexing_directory => "t/indexes",
                 script_name        => "wiki.cgi",
                 script_url         => "http://example.com/",
                 site_name          => "Test Site",
                 template_path      => "./templates",
                 use_plucene        => 1,
                 geo_handler        => 1,
               }
);

# First check that British National Grid will accept both OS X/Y and lat/long,
# and will store both however the data was given to it.
my $guide = OpenGuides->new( config => $config );
is( $guide->locator->x_field, "os_x", "correct x field" );
is( $guide->locator->y_field, "os_y", "correct y field" );

OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "Crabtree Tavern",
                              os_x       => 523465,
                              os_y       => 177490,
                              categories => "Pubs",
                            );
my %data = $guide->wiki->retrieve_node( "Crabtree Tavern" );
is( $data{metadata}{os_x}[0], 523465,      "os_x stored correctly" );
is( $data{metadata}{os_y}[0], 177490,      "os_y stored correctly" );
ok( defined $data{metadata}{latitude}[0],  "latitude stored" );
ok( defined $data{metadata}{longitude}[0], "longitude stored" );

OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "El Sombrero",
                              latitude   => 51.368,
                              longitude  => -0.097,
                              categories => "Restaurants",
                            );
%data = $guide->wiki->retrieve_node( "El Sombrero" );
ok( defined $data{metadata}{os_x}[0],      "os_x stored" );
like( $data{metadata}{os_x}[0], qr/^\d+$/,  "...as integer" );
ok( defined $data{metadata}{os_y}[0],      "os_y stored" );
like( $data{metadata}{os_y}[0], qr/^\d+$/,  "...as integer" );
is( $data{metadata}{latitude}[0], 51.368,  "latitude stored correctly" );
is( $data{metadata}{longitude}[0], -0.097, "longitude stored correctly" );

eval {
    local $SIG{__WARN__} = sub { die $_[0]; };
    OpenGuides::Test->write_data(
                                  guide      => $guide,
                                  node       => "Locationless Page 1",
                                );
};
is( $@, "",
    "commit doesn't warn when using BNG and node has no location data" );
%data = $guide->wiki->retrieve_node( "Locationless Page 1" );
ok( !defined $data{metadata}{latitude}[0],  "...and latitude not stored" );
ok( !defined $data{metadata}{longitude}[0], "...nor longitude" );
ok( !defined $data{metadata}{os_x}[0],      "...nor os_x" );
ok( !defined $data{metadata}{os_y}[0],      "...nor os_y" );
ok( !defined $data{metadata}{osie_x}[0],    "...nor osie_x" );
ok( !defined $data{metadata}{osie_y}[0],    "...nor osie_y" );

# Now check Irish National Grid.
$config->geo_handler( 2 );
$guide = OpenGuides->new( config => $config );
is( $guide->locator->x_field, "osie_x", "correct x field" );
is( $guide->locator->y_field, "osie_y", "correct y field" );

OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "I Made This Place Up",
                              osie_x     => 100000,
                              osie_y     => 200000,
                            );
%data = $guide->wiki->retrieve_node( "I Made This Place Up" );
is( $data{metadata}{osie_x}[0], 100000,    "osie_x stored correctly" );
is( $data{metadata}{osie_y}[0], 200000,    "osie_y stored correctly" );
ok( defined $data{metadata}{latitude}[0],  "latitude stored" );
ok( defined $data{metadata}{longitude}[0], "longitude stored" );

OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "Brambles Coffee Shop",
                              latitude   => 54.6434,
                              longitude  => -5.6731,
                             );
%data = $guide->wiki->retrieve_node( "Brambles Coffee Shop" );
ok( defined $data{metadata}{osie_x}[0],     "osie_x stored" );
like( $data{metadata}{osie_x}[0], qr/^\d+$/,  "...as integer" );
ok( defined $data{metadata}{osie_y}[0],     "osie_y stored" );
like( $data{metadata}{osie_y}[0], qr/^\d+$/,  "...as integer" );
is( $data{metadata}{latitude}[0], 54.6434,  "latitude stored correctly" );
is( $data{metadata}{longitude}[0], -5.6731, "longitude stored correctly" );

eval {
    local $SIG{__WARN__} = sub { die $_[0]; };
    OpenGuides::Test->write_data(
                                  guide      => $guide,
                                  node       => "Locationless Page 2",
                                );
};
is( $@, "",
    "commit doesn't warn when using ING and node has no location data" );
%data = $guide->wiki->retrieve_node( "Locationless Page 2" );
ok( !defined $data{metadata}{latitude}[0],  "...and latitude not stored" );
ok( !defined $data{metadata}{longitude}[0], "...nor longitude" );
ok( !defined $data{metadata}{os_x}[0],      "...nor os_x" );
ok( !defined $data{metadata}{os_y}[0],      "...nor os_y" );
ok( !defined $data{metadata}{osie_x}[0],    "...nor osie_x" );
ok( !defined $data{metadata}{osie_y}[0],    "...nor osie_y" );

# Finally check UTM.
$config->geo_handler( 3 );
$config->ellipsoid( "Airy" );
$guide = OpenGuides->new( config => $config );
is( $guide->locator->x_field, "easting", "correct x field" );
is( $guide->locator->y_field, "northing", "correct y field" );

OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "London Aquarium",
                              latitude   => 51.502,
                              longitude  => -0.118,
                            );
%data = $guide->wiki->retrieve_node( "London Aquarium" );
ok( defined $data{metadata}{easting}[0],       "easting stored" );
like( $data{metadata}{easting}[0], qr/^\d+$/,  "...as integer" );
ok( defined $data{metadata}{northing}[0],      "northing stored" );
like( $data{metadata}{northing}[0], qr/^\d+$/, "...as integer" );
is( $data{metadata}{latitude}[0], 51.502,      "latitude stored correctly" );
is( $data{metadata}{longitude}[0], -0.118,     "longitude stored correctly" );

eval {
    local $SIG{__WARN__} = sub { die $_[0]; };
    OpenGuides::Test->write_data(
                                  guide      => $guide,
                                  node       => "Locationless Page 3",
                                );
};
is( $@, "",
    "commit doesn't warn when using UTM and node has no location data" );
%data = $guide->wiki->retrieve_node( "Locationless Page 3" );
ok( !defined $data{metadata}{latitude}[0],  "...and latitude not stored" );
ok( !defined $data{metadata}{longitude}[0], "...nor longitude" );
ok( !defined $data{metadata}{os_x}[0],      "...nor os_x" );
ok( !defined $data{metadata}{os_y}[0],      "...nor os_y" );
ok( !defined $data{metadata}{osie_x}[0],    "...nor osie_x" );
ok( !defined $data{metadata}{osie_y}[0],    "...nor osie_y" );
