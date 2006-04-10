use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides;
use Test::More tests => 7;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 5
      unless $have_sqlite;

    Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Config->new(
           vars => {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_name        => "wiki.cgi",
                     script_url         => "http://example.com/",
                     site_name          => "Test Site",
                     template_path      => "./templates",
                     home_name          => "Home",
                   }
    );
    eval { require Wiki::Toolkit::Search::Plucene; };
    if ( $@ ) { $config->use_plucene ( 0 ) };

    my $guide = OpenGuides->new( config => $config );
    isa_ok( $guide, "OpenGuides" );
    my $wiki = $guide->wiki;
    isa_ok( $wiki, "Wiki::Toolkit" );
    $wiki->write_node( "Test Page", "foo", undef, { source => "alternate.cgi?Test_Page" } );
    my $output = eval {
        $guide->display_node( id => "Test Page", return_output => 1 );
    };
    is( $@, "", "->display_node doesn't die" );

    like( $output, qr{\<a.*?\Qhref="alternate.cgi?id=Test_Page;action=edit">Edit this page</a>\E}, "...and edit link is redirected to source URL" );
    $config->home_name( "My Home Page" );
    $output = $guide->display_node( return_output => 1 );
    like( $output, qr/My Home Page/, "...and defaults to the home node, and takes notice of what we want to call it" );
    like( $output, qr{\Q<a href="wiki.cgi?action=edit;id=My_Home_Page">Edit this page</a>\E}, "...and home page has an edit link" );
    my %tt_vars = $guide->display_node( return_tt_vars => 1 );
    ok( defined $tt_vars{recent_changes}, "...and recent_changes is set for the home node even if we have changed its name" );
}
