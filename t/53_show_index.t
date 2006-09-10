use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More tests => 17; # 19 when all enabled

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 17
      unless $have_sqlite;

    Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Test->make_basic_config;
    $config->script_name( "wiki.cgi" );
    $config->script_url( "http://example.com/" );
    my $guide = OpenGuides->new( config => $config );
    isa_ok( $guide, "OpenGuides" );
    my $wiki = $guide->wiki;
    isa_ok( $wiki, "Wiki::Toolkit" );

    # Clear out the database from any previous runs.
    foreach my $del_node ( $wiki->list_all_nodes ) {
        print "# Deleting node $del_node\n";
        $wiki->delete_node( $del_node ) or die "Can't delete $del_node";
    }

    $wiki->write_node( "Test Page", "foo", undef,
                       { category => "Alpha" } )
      or die "Couldn't write node";
    $wiki->write_node( "Test Page 2", "foo", undef,
                       { category => "Alpha" } )
      or die "Couldn't write node";

    # Test the normal, HTML version
    my $output = eval {
        $guide->show_index(
                            type          => "category",
                            value         => "Alpha",
                            return_output => 1,
                          );
    };
    is( $@, "", "->show_index doesn't die" );
    like( $output, qr|wiki.cgi\?Test_Page|,
          "...and includes correct links" );
    unlike( $output, qr|<title>\s*-|, "...sets <title> correctly" );

    # Test the RDF version
    $output = $guide->show_index(
                                  type          => "category",
                                  value         => "Alpha",
                                  return_output => 1,
                                  format        => "rdf"
                                );
    like( $output, qr|Content-Type: application/rdf\+xml|,
          "RDF output gets content-type of application/rdf+xml" );
    like( $output, qr|<rdf:RDF|, "Really is rdf" );
    like( $output, qr|<dc:title>Category Alpha</dc:title>|, "Right rdf title" );
    my @entries = ($output =~ /(\<rdf\:li\>)/g);
    is( 2, scalar @entries, "Right number of nodes included in rdf" );

    # Test the RSS version
    $output = eval {
        $guide->show_index(
                            type          => "category",
                            value         => "Alpha",
                            return_output => 1,
                            format        => "rss",
                          );
    };
    is( $@, "", "->show_index doesn't die when asked for rss" );
    like( $output, qr|Content-Type: application/rdf\+xml|,
          "RSS output gets content-type of application/rdf+xml" );
    like( $output, "/\<rdf\:RDF.*?http\:\/\/purl.org\/rss\//s", "Really is rss" );
    #like( $output, qr|<title>Category Alpha</title>|, "Right rss title" );
    @entries = ($output =~ /(\<\/item\>)/g);
    is( 2, scalar @entries, "Right number of nodes included in rss" );

    # Test the Atom version
    $output = eval {
        $guide->show_index(
                            type          => "category",
                            value         => "Alpha",
                            return_output => 1,
                            format        => "atom",
                          );
    };
    is( $@, "", "->show_index doesn't die when asked for atom" );
    like( $output, qr|Content-Type: application/atom\+xml|,
          "Atom output gets content-type of application/atom+xml" );
    like( $output, qr|<feed|, "Really is atom" );
    #like( $output, qr|<title>Category Alpha</title>|, "Right atom title" );
    @entries = ($output =~ /(\<entry\>)/g);
    is( 2, scalar @entries, "Right number of nodes included in atom" );
}
