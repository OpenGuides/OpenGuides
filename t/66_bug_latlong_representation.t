use strict;
use CGI;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::CGI;
use OpenGuides;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
}

eval { require Geo::Coordinates::UTM; };
if ( $@ ) { 
    plan skip_all => "Geo::Coordinates::UTM not installed";
}

plan tests => 4;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = Config::Tiny->new;
$config->{_} = {
                 dbtype             => "sqlite",
                 dbname             => "t/node.db",
                 indexing_directory => "t/indexes",
                 script_name        => "wiki.cgi",
                 script_url         => "http://example.com/",
                 site_name          => "Test Site",
                 template_path      => "./templates",
                 home_name          => "Home",
                 geo_handler        => 3, # Test w/ UTM - nat grids use X/Y
                 ellipsoid          => "Airy",
               };

# Plucene is the recommended searcher now.
eval { require CGI::Wiki::Search::Plucene; };
unless ( $@ ) {
    $config->{_}{use_plucene} = 1;
}

my $guide = OpenGuides->new( config => $config );

# Set preferences to have lat/long displayed in deg/min/sec.
my $cookie = OpenGuides::CGI->make_prefs_cookie(
    config                     => $config,
    username                   => "Kake",
    include_geocache_link      => 1,
    preview_above_edit_box     => 1,
    latlong_traditional        => 1,  # this is the important bit
    omit_help_links            => 1,
    show_minor_edits_in_rc     => 1,
    default_edit_type          => "tidying",
    cookie_expires             => "never",
    track_recent_changes_views => 1,
);
$ENV{HTTP_COOKIE} = $cookie;

write_data(
            guide      => $guide,
            node       => "Test Page",
            latitude   => 51.368,
            longitude  => -0.0973,
          );

my %data = $guide->wiki->retrieve_node( "Test Page" );
my $lat = $data{metadata}{latitude}[0];
unlike( $lat, qr/d/,
    "lat not stored in dms format even if prefs set to display that way" );

# Check the distance search form has unmunged lat/long.
my $output = $guide->display_node(
                                   return_output => 1,
                                   id => "Test Page",
                                 );
unlike( $output, qr/name="latitude"\svalue="[-0-9]*d/,
        "latitude in non-dms format in distance search form" );

# Now write a node with no location data, and check that it doesn't
# claim to have any when we display it.
eval {
    local $SIG{__WARN__} = sub { die $_[0]; };
    write_data(
                guide      => $guide,
                node       => "Locationless Page",
              );
};
is( $@, "",
    "commit doesn't warn when prefs say dms format and node has no loc data" );

$output = $guide->display_node(
                                return_output => 1,
                                id => "Locationless Page",
                              );
unlike( $output, qr/latitude:/i,
        "node with no location data doesn't display a latitude" );



sub write_data {
    my %args = @_;
    
    # Set up CGI parameters ready for a node write.
    # Most of these are in here to avoid uninitialised value warnings.
    my $q = CGI->new( "" );
    $q->param( -name => "content", -value => "foo" );
    $q->param( -name => "categories", -value => $args{categories} || "" );
    $q->param( -name => "locales", -value => "" );
    $q->param( -name => "phone", -value => "" );
    $q->param( -name => "fax", -value => "" );
    $q->param( -name => "website", -value => "" );
    $q->param( -name => "hours_text", -value => "" );
    $q->param( -name => "address", -value => "" );
    $q->param( -name => "postcode", -value => "" );
    $q->param( -name => "map_link", -value => "" );
    $q->param( -name => "os_x", -value => $args{os_x} || "" );
    $q->param( -name => "os_y", -value => $args{os_y} || "" );
    $q->param( -name => "osie_x", -value => $args{osie_x} || "" );
    $q->param( -name => "osie_y", -value => $args{osie_y} || "" );
    $q->param( -name => "latitude", -value => $args{latitude} || "" );
    $q->param( -name => "longitude", -value => $args{longitude} || "" );
    $q->param( -name => "username", -value => "Kake" );
    $q->param( -name => "comment", -value => "foo" );
    $q->param( -name => "edit_type", -value => "Normal edit" );
    $ENV{REMOTE_ADDR} = "127.0.0.1";
    
    $args{guide}->commit_node(
                               return_output => 1,
                               id => $args{node},
                               cgi_obj => $q,
                             );
}
