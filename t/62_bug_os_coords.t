use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use Cwd;
use OpenGuides::Template;
use OpenGuides::Utils;
use Test::More tests => 2;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 2
      unless $have_sqlite;

    CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = Config::Tiny->new;
    $config->{_} = {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_url         => "http://example.com/",
                     script_name        => "wiki.cgi",
                     site_name          => "Test Site",
                     template_path      => cwd . "/templates",
                   };

    my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

    my $q = CGI->new;
    $q->param( -name => "os_x", -value => "123456 " );
    $q->param( -name => "os_y", -value => "654321 " );
    $q->param( -name => "categories", -value => "" ); #avoid uninit val warning
    $q->param( -name => "locales", -value => "" );    #avoid uninit val warning

    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
        wiki    => $wiki,
        config  => $config,
        cgi_obj => $q,
    );

    is( $metadata_vars{os_x}, "123456", "trailing space stripped from os_x" );
    is( $metadata_vars{os_y}, "654321", "trailing space stripped from os_y" );
}
