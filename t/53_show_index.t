use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides;
use Test::More tests => 6;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 6
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
                   };
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
    like( $output, qr|Content-Type: text/plain|,
          "RDF output gets content-type of text/plain" );
}
