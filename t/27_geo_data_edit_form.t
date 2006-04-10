use strict;
use Wiki::Toolkit::Setup::SQLite;
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
    exit 0;
}

eval { require Test::HTML::Content; };
if ( $@ ) {
    plan skip_all => "Test::HTML::Content not installed";
    exit 0;
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

plan tests => 18;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Test->make_basic_config;
$config->use_plucene( 1 );

# British National Grid guides should have os_x/os_y fields.
my $guide = OpenGuides->new( config => $config );
my $wiki = $guide->wiki;
# Write some data.
OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "Crabtree Tavern",
                              os_x       => 523465,
                              os_y       => 177490,
                              categories => "Pubs",
                            );
my %data = $guide->wiki->retrieve_node( "Crabtree Tavern" );
# Set up the coord_field vars.
my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
    wiki     => $wiki,
    config   => $config,
    metadata => $data{metadata},
);
my $output = OpenGuides::Template->output(
                                           wiki     => $wiki,
                                           config   => $config,
                                           template => "edit_form.tt",
                                           vars     => \%metadata_vars,
                                         );
# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;
Test::HTML::Content::tag_ok( $output, "input", { name => "os_x" },
                             "BNG defaults to 'os_x' input box..." );
Test::HTML::Content::tag_ok( $output, "input", { name  => "os_x",
                                                 value => 523465 },
                             "...with correct value..." );
Test::HTML::Content::tag_ok( $output, "input", { name => "os_y" },
                             "...and 'os_y' input box" );
Test::HTML::Content::tag_ok( $output, "input", { name  => "os_y",
                                                 value => 177490 },
                             "...with correct value..." );
# Use a regex; Test::HTML::Content can't do this yet I think (read docs, check)
like( $output, qr|OS\sX\scoordinate:|s,
      "...'OS X coordinate:' label included" );
like( $output, qr|OS\sY\scoordinate:|s,
      "...'OS Y coordinate:' label included" );

# Irish National Grid guides should have osie_x/osie_y fields.
$config->geo_handler( 2 );
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;
# Write some data.
OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "I Made This Place Up",
                              osie_x     => 100000,
                              osie_y     => 200000,
                            );
%data = $guide->wiki->retrieve_node( "I Made This Place Up" );
# Set up the coord_field vars.
%metadata_vars = OpenGuides::Template->extract_metadata_vars(
    wiki     => $wiki,
    config   => $config,
    metadata => $data{metadata},
);
$output = OpenGuides::Template->output(
                                        wiki     => $wiki,
                                        config   => $config,
                                        template => "edit_form.tt",
                                        vars     => \%metadata_vars,
                                      );
$output =~ s/^Content-Type.*[\r\n]+//m;
Test::HTML::Content::tag_ok( $output, "input", { name => "osie_x" },
                             "ING defaults to 'osie_x' input box..." );
Test::HTML::Content::tag_ok( $output, "input", { name  => "osie_x",
                                                 value => 100000 },
                             "...with correct value..." );
Test::HTML::Content::tag_ok( $output, "input", { name => "osie_y" },
                             "...and 'osie_y' input box" );
Test::HTML::Content::tag_ok( $output, "input", { name  => "osie_y",
                                                 value => 200000 },
                             "...with correct value..." );
like( $output, qr|Irish\sNational\sGrid\sX\scoordinate:|s,
      "...'Irish National Grid X coordinate:' label included" );
like( $output, qr|Irish\sNational\sGrid\sY\scoordinate:|s,
      "...'Irish National Grid Y coordinate:' label included" );

# UTM guides should have lat/long fields.
$config->geo_handler( 3 );
$config->ellipsoid( "Airy" );
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;
# Write some data.
OpenGuides::Test->write_data(
                              guide     => $guide,
                              node      => "London Aquarium",
                              latitude  => 51.502,
                              longitude => -0.118,
                            );
%data = $guide->wiki->retrieve_node( "London Aquarium" );
# Set up the coord_field vars.
%metadata_vars = OpenGuides::Template->extract_metadata_vars(
    wiki     => $wiki,
    config   => $config,
    metadata => $data{metadata},
);
$output = OpenGuides::Template->output(
                                        wiki     => $wiki,
                                        config   => $config,
                                        template => "edit_form.tt",
                                        vars     => \%metadata_vars,
                                      );
$output =~ s/^Content-Type.*[\r\n]+//m;
Test::HTML::Content::tag_ok( $output, "input", { name => "latitude" },
                             "UTM defaults to 'latitude' input box..." );
Test::HTML::Content::tag_ok( $output, "input", { name  => "latitude",
                                                 value => 51.502 },
                             "...with correct value..." );
Test::HTML::Content::tag_ok( $output, "input", { name => "longitude" },
                             "...and 'longitude' input box" );
Test::HTML::Content::tag_ok( $output, "input", { name  => "longitude",
                                                 value => -0.118 },
                             "...with correct value..." );
like( $output, qr|Latitude \(decimal\):|s,
      "...'Latitude (decimal):' label included" );
like( $output, qr|Longitude \(decimal\):|s,
      "...'Longitude (decimal):' label included" );
