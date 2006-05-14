use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use Cwd;
use OpenGuides;
use Test::More tests => 1;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 1
      unless $have_sqlite;

    Wiki::Toolkit::Setup::SQLite::cleardb( { dbname => "t/node.db" } );
    Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Config->new(
           vars => {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_url         => "http://wiki.example.com/",
                     script_name        => "mywiki.cgi",
                     site_name          => "Wiki::Toolkit Test Site",
                     template_path      => cwd . "/templates",
                   }
    );
    eval { require Wiki::Toolkit::Search::Plucene; };
    if ( $@ ) { $config->use_plucene ( 0 ) };

    my $guide = OpenGuides->new( config => $config );

    $guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", undef, { comment => "<myfaketag>" } ) or die "Can't write node";
    my %data = $guide->wiki->retrieve_node( "South Croydon Station" );
    $guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", $data{checksum}, { comment => "<myfaketag>" } ) or die "Can't write node";

    my $output = $guide->list_all_versions(
                                            id => "South Croydon Station",
                                            return_output => 1,
                                          );
    unlike( $output, qr'<myfaketag>', "HTML escaped in comments" );
}

