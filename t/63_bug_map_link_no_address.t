use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use Cwd;
use OpenGuides;
use Test::More tests => 1;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 1
      unless $have_sqlite;

    CGI::Wiki::Setup::SQLite::cleardb( { dbname => "t/node.db" } );
    CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = Config::Tiny->new;
    $config->{_} = {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_url         => "http://wiki.example.com/",
                     script_name        => "mywiki.cgi",
                     site_name          => "CGI::Wiki Test Site",
                     template_path      => cwd . "/templates",
                   };

    my $guide = OpenGuides->new( config => $config );

    $guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", undef, { map_link => "http://www.streetmap.co.uk/newmap.srf?x=532804&y=164398&z=1" } ) or die "Couldn't write node";

    my $output = $guide->display_node(
                                       id => "South Croydon Station",
                                       return_output => 1,
                                     );
    like( $output, qr/Map:/, "map link included when no address" );
}

