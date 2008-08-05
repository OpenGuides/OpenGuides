use strict;
use OpenGuides;
use OpenGuides::Test;
use Test::More;
use Wiki::Toolkit::Setup::SQLite;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed - no database to test with";
    exit 0;
}

plan tests => 5;

my ( $config, $guide, $wiki, $cookie, $output );

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;
Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );

# Make a guide.
$config = OpenGuides::Test->make_basic_config;
$guide = OpenGuides->new( config => $config );

# Write a node.
OpenGuides::Test->write_data(
                              guide => $guide,
                              node  => "Red Lion",
                            );

# Make sure analytics stuff only shows up if we want it to.
$output = $guide->display_node(
                                id => "Red Lion",
                                return_output => 1,
                              );
unlike( $output, qr/ga.js/, "Google analytics omitted by default" );

$config->google_analytics_key( "" );
$output = $guide->display_node(
                                id => "Red Lion",
                                return_output => 1,
                              );
unlike( $output, qr/ga.js/, "...also if analytics key is blank" );

$config->google_analytics_key( 0 );
$output = $guide->display_node(
                                id => "Red Lion",
                                return_output => 1,
                              );
unlike( $output, qr/ga.js/, "...also if analytics key is zero" );

$config->google_analytics_key( "ThisIsNotAKey" );
$output = $guide->display_node(
                                id => "Red Lion",
                                return_output => 1,
                              );
like( $output, qr/ga.js/, "does show up if key is provided" );
like( $output, qr/ThisIsNotAKey/, "...correct key" );
