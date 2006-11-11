use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

plan tests => ( 9 );

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 9
        unless $have_sqlite;

    Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Config->new(
        vars => {
                    dbtype             => "sqlite",
                    dbname             => "t/node.db",
                    indexing_directory => "t/indexes",
                    script_url         => "http://wiki.example.com/",
                    script_name        => "mywiki.cgi",
                    site_name          => "Wiki::Toolkit Test Site",
                    default_city       => "London",
                    default_country    => "United Kingdom",
                    ping_services      => ""
                }
    );
    my $guide = OpenGuides->new( config => $config );

    ok($guide, "Made the guide OK");

    # Check for the plugin
    my @plugins = @{ $guide->wiki->{_registered_plugins} };
    is( scalar @plugins, 2, "Two plugins to start" );


    # Now with the plugin
    $config = OpenGuides::Config->new(
        vars => {
                    dbtype             => "sqlite",
                    dbname             => "t/node.db",
                    indexing_directory => "t/indexes",
                    script_url         => "http://wiki.example.com/",
                    script_name        => "mywiki.cgi",
                    site_name          => "Wiki::Toolkit Test Site",
                    default_city       => "London",
                    default_country    => "United Kingdom",
                    ping_services      => "pingerati,geourl,FOOOO"
                }
    );
    $guide = OpenGuides->new( config => $config );

    ok($guide, "Made the guide OK");

    my @plugins = @{ $guide->wiki->{_registered_plugins} };
    is( scalar @plugins, 3, "Has plugin now" );
    ok( $plugins[2]->isa( "Wiki::Toolkit::Plugin" ), "Right plugin" );
    ok( $plugins[2]->isa( "Wiki::Toolkit::Plugin::Ping" ), "Right plugin" );

    # Check it has the right services registered
    my %services = $plugins[2]->services;
    my @snames = sort keys %services;
    is( scalar @snames, 2, "Has 2 services as expected" );
    is( @snames[0], "geourl", "Right service" );
    is( @snames[1], "pingerati", "Right service" );
}
