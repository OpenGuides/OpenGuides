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
} else {
    plan tests => 2;

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

    # Set up CGI parameters ready for a node write.
    # Most of these are in here to avoid uninitialised value warnings.
    my $q = CGI->new;
    $q->param( -name => "content", -value => "foo" );
    $q->param( -name => "categories", -value => "" );
    $q->param( -name => "locales", -value => "" );
    $q->param( -name => "phone", -value => "" );
    $q->param( -name => "fax", -value => "" );
    $q->param( -name => "website", -value => "" );
    $q->param( -name => "hours_text", -value => "" );
    $q->param( -name => "address", -value => "" );
    $q->param( -name => "postcode", -value => "" );
    $q->param( -name => "map_link", -value => "" );
    $q->param( -name => "os_x", -value => "532125" );
    $q->param( -name => "os_y", -value => "165504" );
    $q->param( -name => "username", -value => "Kake" );
    $q->param( -name => "comment", -value => "foo" );
    $q->param( -name => "edit_type", -value => "Minor tidying" );
    $ENV{REMOTE_ADDR} = "127.0.0.1";

    # Write a node.
    my $output = $guide->commit_node(
                                      return_output => 1,
                                      id => "Test Page",
                                      cgi_obj => $q,
                                    );

    # Read it.
    my %data = $guide->wiki->retrieve_node( "Test Page" );
    my $lat = $data{metadata}{latitude}[0];
    unlike( $lat, qr/d/,
        "lat not stored in dms format even if prefs set to display that way" );

    # Look at it, check the distance search form has unmunged lat/long.
    $output = $guide->display_node(
                                    return_output => 1,
                                    id => "Test Page",
                                  );
    unlike( $output, qr/name="lat"\svalue="[-0-9]*d/,
            "lat in non-dms format in distance search form" );
}