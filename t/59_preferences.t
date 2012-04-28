use strict;
use JSON;
use OpenGuides;
use OpenGuides::JSON;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

eval { require Test::HTML::Content; };
if ( $@ ) {
    plan skip_all => "Test::HTML::Content not installed";
    exit 0;
}

plan tests => 12;

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

$cookie = OpenGuides::CGI->make_prefs_cookie(
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

# Test JSON version of prefs page.
my $json_writer = OpenGuides::JSON->new( wiki   => $wiki,
                                         config => $config );
delete $ENV{HTTP_COOKIE};
my $output = eval {
    $json_writer->make_prefs_json();
};
ok( !$@, "->make_prefs_json() doesn't die when no cookie set." );
if ( $@ ) { warn "#   Error was: $@"; }
# Need to strip out the Content-Type: header or the decoder gets confused.
$output =~ s/^Content-Type:.*\n//s;
my $parsed = eval {
    local $SIG{__WARN__} = sub { die $_[0]; };
    decode_json( $output );
};
ok( !$@, "...and its output looks like JSON." );
if ( $@ ) { warn "#   Warning was: $@"; }
ok( $parsed->{username}, "...and a username is included in the output" );
#use Data::Dumper; print Dumper $parsed; exit 0;

$ENV{HTTP_COOKIE} = OpenGuides::CGI->make_prefs_cookie( config => $config );
$output = eval {
    $json_writer->make_prefs_json();
};
ok( !$@, "->make_prefs_json() doesn't die when cookie set with all defaults.");
if ( $@ ) { warn "#   Error was: $@"; }
$output =~ s/^Content-Type:.*\n//s;
$parsed = eval {
    local $SIG{__WARN__} = sub { die $_[0]; };
    decode_json( $output );
};
ok( !$@, "...and its output looks like JSON." );
if ( $@ ) { warn "#   Warning was: $@"; }
# We don't get a username set in this case.

$ENV{HTTP_COOKIE} = OpenGuides::CGI->make_prefs_cookie( config => $config,
    username => "Kake" );
$output = eval {
    $json_writer->make_prefs_json();
};
ok( !$@,
    "->make_prefs_json() doesn't die when cookie set with given username.");
if ( $@ ) { warn "#   Error was: $@"; }
$output =~ s/^Content-Type:.*\n//s;
$parsed = eval {
    local $SIG{__WARN__} = sub { die $_[0]; };
    decode_json( $output );
};
ok( !$@, "...and its output looks like JSON." );
if ( $@ ) { warn "#   Warning was: $@"; }
is( $parsed->{username}, "Kake",
    "...and the correct username is included in the output" );

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

