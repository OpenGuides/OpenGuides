use strict;
use CGI::Wiki::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides;
use Test::More tests => 2;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 2
      unless $have_sqlite;

    CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Config->new(
           vars => {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_name        => "wiki.cgi",
                     script_url         => "http://example.com/",
                     site_name          => "Test Site",
                     template_path      => "./templates",
                   }
    );
    eval { require CGI::Wiki::Search::Plucene; };
    if ( $@ ) { $config->use_plucene ( 0 ) };
	    
    my $guide = OpenGuides->new( config => $config );
    my $wiki = $guide->wiki;

    # Clear out the database from any previous runs.
    foreach my $del_node ( $wiki->list_all_nodes ) {
        $wiki->delete_node( $del_node ) or die "Can't delete $del_node";
    }

    $wiki->write_node( "Test Page", "#REDIRECT [[Test Page 2]]" )
      or die "Can't write node";
    $wiki->write_node( "Test Page 2", "foo" )
      or die "Can't write node";
    my $output = eval {
        $guide->display_node( id => "Test Page", return_output => 1 );
    };
    is( $@, "", "->display_node doesn't die when page is a redirect" );

    # Old versions of CGI.pm mistakenly print location: instead of Location:
    like( $output,
          qr/[lL]ocation: http:\/\/example.com\/wiki.cgi\?id=Test_Page_2\;oldid=Test_Page/,
          "...and redirects to the right place" );
}
