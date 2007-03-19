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

eval { require Test::HTML::Content; };
if ( $@ ) {
    plan skip_all => "Test::HTML::Content not installed";
    exit 0;
}

plan tests => 4;

my ( $config, $guide, $wiki, $cookie, $output );

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;
Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );

# Make a guide.
$config = OpenGuides::Test->make_basic_config;
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;

# Write a node with location data.
OpenGuides::Test->write_data(
                              guide => $guide,
                              node  => "Red Lion",
                              os_x  => 530000,
                              os_y  => 180000,
                            );

# Maps shouldn't show up if there's no API key.
$config->show_gmap_in_node_display( 1 );
$cookie = OpenGuides::CGI->make_prefs_cookie(
                                              config => $config,
                                              display_google_maps => 1,
                                            );
$ENV{HTTP_COOKIE} = $cookie;

$output = $guide->display_node(
                                id => "Red Lion",
                                return_output => 1,
                              );
$output =~ s/^Content-Type.*[\r\n]+//m;
Test::HTML::Content::no_tag( $output, "div", { id => "map" },
                             "Google map omitted from node if no API key" );

# And they should if there is.
$config->gmaps_api_key( "This is not a real API key." );
$output = $guide->display_node(
                                id => "Red Lion",
                                return_output => 1,
                              );
$output =~ s/^Content-Type.*[\r\n]+//m;
Test::HTML::Content::tag_ok( $output, "div", { id => "map" },
                             "Google map shown on node if we have an API key");

# But not if the user doesn't want them.
$cookie = OpenGuides::CGI->make_prefs_cookie(
                                              config => $config,
                                              display_google_maps => 0,
                                            );
$ENV{HTTP_COOKIE} = $cookie;
$output = $guide->display_node(
                                id => "Red Lion",
                                return_output => 1,
                              );
$output =~ s/^Content-Type.*[\r\n]+//m;
Test::HTML::Content::no_tag( $output, "div", { id => "map" },
                             "...but not if the user turned it off" );

# And not if the admin doesn't want them.
$config->show_gmap_in_node_display( 0 );
$cookie = OpenGuides::CGI->make_prefs_cookie(
                                              config => $config,
                                              display_google_maps => 1,
                                            );
$ENV{HTTP_COOKIE} = $cookie;
$output = $guide->display_node(
                                id => "Red Lion",
                                return_output => 1,
                              );
$output =~ s/^Content-Type.*[\r\n]+//m;
Test::HTML::Content::no_tag( $output, "div", { id => "map" },
                             "...and not if the admin turned it off" );
