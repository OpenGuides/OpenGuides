use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides;
use Test::More tests => 5;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 5
      unless $have_sqlite;

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
    my $guide = OpenGuides->new( config => $config );
    isa_ok( $guide, "OpenGuides" );
    my $wiki = $guide->wiki;
    isa_ok( $wiki, "CGI::Wiki" );
    $wiki->write_node( "Test Page", "foo" );
    my $output = eval {
        $guide->display_node( id => "Test Page", return_output => 1 );
    };
    is( $@, "", "->display_node doesn't die" );

    $config->{_}->{home_name} = "My Home Page";
    $output = $guide->display_node( return_output => 1 );
    like( $output, qr/My Home Page/, "...and defaults to the home node, and takes notice of what we want to call it" );
    my %tt_vars = $guide->display_node( return_tt_vars => 1 );
    ok( defined $tt_vars{recent_changes}, "...and recent_changes is set for the home node even if we have changed its name" );
}
