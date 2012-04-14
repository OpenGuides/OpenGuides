use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };

if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

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

    OpenGuides::Test::refresh_db();

my $config = OpenGuides::Test->make_basic_config;
my $guide = OpenGuides->new( config => $config );
my $wiki = $guide->wiki;

# If we have a google API key and node maps are enabled, we should see the
# checkbox for this pref.
$config->gmaps_api_key( "This is not a real API key." );
$config->show_gmap_in_node_display( 1 );

my $cookie = OpenGuides::CGI->make_prefs_cookie(
                                                 config => $config,
                                                 display_google_maps => 1,
                                               );
$ENV{HTTP_COOKIE} = $cookie;
Test::HTML::Content::tag_ok( get_output($wiki, $config),
  "input", { type => "checkbox", name => "display_google_maps" },
  "Node map preference checkbox shown when we have a GMaps API key." );

# But not if the node map is globally disabled
$config->show_gmap_in_node_display( 0 );
Test::HTML::Content::no_tag( get_output($wiki, $config),
  "input", { type => "checkbox", name => "display_google_maps" },
  "...but not when node maps are globally disabled." );

# Now test with Leaflet enabled and no Google API key.
$config->gmaps_api_key( "" );
$config->show_gmap_in_node_display( 1 );
$config->use_leaflet( 1 );

my $cookie = OpenGuides::CGI->make_prefs_cookie(
                                                 config => $config,
                                                 display_google_maps => 1,
                                               );
$ENV{HTTP_COOKIE} = $cookie;
Test::HTML::Content::tag_ok( get_output($wiki, $config),
  "input", { type => "checkbox", name => "display_google_maps" },
  "Node map preference checkbox shown when we're using Leaflet." );

$config->show_gmap_in_node_display( 0 );
Test::HTML::Content::no_tag( get_output($wiki, $config),
  "input", { type => "checkbox", name => "display_google_maps" },
  "...but not when node maps are globally disabled." );

sub get_output {
    my ($wiki, $config) = @_;

    return OpenGuides::Template->output(
        wiki         => $wiki,
        config       => $config,
        template     => "preferences.tt",
        noheaders    => 1,
        vars         => {
                          not_editable => 1,
                          show_form    => 1
                        },
    );
}

