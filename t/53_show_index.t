use strict;
use CGI::Wiki::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More tests => 6;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 6
      unless $have_sqlite;

    CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Test->make_basic_config;
    $config->script_name( "wiki.cgi" );
    $config->script_url( "http://example.com/" );
    my $guide = OpenGuides->new( config => $config );
    isa_ok( $guide, "OpenGuides" );
    my $wiki = $guide->wiki;
    isa_ok( $wiki, "CGI::Wiki" );

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

    $output = $guide->show_index(
                                  type          => "category",
                                  value         => "Alpha",
                                  return_output => 1,
                                  format        => "rdf"
                                );
    like( $output, qr|Content-Type: application/rdf\+xml|,
          "RDF output gets content-type of application/rdf+xml" );
}
