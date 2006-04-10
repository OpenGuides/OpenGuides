use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

plan tests => 2;

# Clear out the database from any previous runs.
unlink "t/node.db";

my $config = OpenGuides::Test->make_basic_config;
$config->force_wgs84 (1);

my $guide = OpenGuides->new( config => $config );

my ($longitude, $latitude) = (0, 0);

my ($wgs_long, $wgs_lat) = OpenGuides::Utils->get_wgs84_coords(
                                                    longitude => $longitude,
                                                    latitude => $latitude,
                                                    config => $config);

is( $wgs_long, $longitude,
    "get_wgs84_coords returns the original longitude when force_wgs84 is on");
is( $wgs_lat, $latitude,
    "get_wgs84_coords returns the original latitude when force_wgs84 is on");
