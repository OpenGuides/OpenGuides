local $^W = 1;
use strict;
use vars qw( $num_tests );
BEGIN { $num_tests = 2; }
use Test::More tests => $num_tests;

use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::Utils;
use OpenGuides::Template;

eval { require DBD::SQLite; };
my $run_tests = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite needed to run these tests", $num_tests
      unless $run_tests;

    # Ensure the test database is set up.
    CGI::Wiki::Setup::SQLite::setup( "t/sqlite.62.db" );

    my $config = Config::Tiny->new;
    $config->{_} = {
                     dbtype             => "sqlite",
                     dbname             => "t/sqlite.62.db",
                     indexing_directory => "t/index.62/",
                     script_name        => "wiki.cgi",
                     script_url         => "http://example.com/",
                     site_name          => "Test Site",
                     template_path      => "./templates",
                   };
    my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

    my $q = CGI->new;
    $q->param( -name => "os_x", -value => "123456 " );
    $q->param( -name => "os_y", -value => "654321 " );
    $q->param( -name => "categories", -value => "" ); # avoid uninit val warning
    $q->param( -name => "locales", -value => "" );    # avoid uninit val warning

    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
        wiki    => $wiki,
        config  => $config,
        cgi_obj => $q,
    );

    is( $metadata_vars{os_x}, "123456", "trailing space stripped from os_x" );
    is( $metadata_vars{os_y}, "654321", "trailing space stripped from os_y" );
}
