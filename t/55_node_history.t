use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use Cwd;
use OpenGuides;
use Test::More tests => 2;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 2
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
                     home_name          => "Home",
                   };

    my $guide = OpenGuides->new( config => $config );

    $guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", undef, { comment => "<myfaketag>" } ) or die "Can't write node";
    my %data = $guide->wiki->retrieve_node( "South Croydon Station" );
    $guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", $data{checksum}, { comment => "<myfaketag>" } ) or die "Can't write node";

    my $output = $guide->display_node(
                                       id => "South Croydon Station",
                                       version => 1,
                                       return_output => 1,
                                     );
    like( $output, qr'South_Croydon_Station',
          "node param escaped properly in links in historic view" );
    unlike( $output, qr'South%20Croydon%20Station',
            "...in all links" );
}

