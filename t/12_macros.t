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

    # Clear out the database from any previous runs.
    unlink "t/node.db";
    unlink <t/indexes/*>;
    CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );

    my $config = OpenGuides::Test->make_basic_config;
    my $guide = OpenGuides->new( config => $config );
    my $wiki = $guide->wiki;

    # Test @INDEX_LINK
    $wiki->write_node( "Test 1", "\@INDEX_LINK [[Category Foo]]" )
      or die "Can't write node";
    $wiki->write_node( "Test 2", "\@INDEX_LINK [[Category Bar|Bars]]" )
      or die "Can't write node";

    my $output;
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 1",
                                  );
    like( $output, qr/View all pages in Category Foo/,
          "\@INDEX_LINK has right default link text" );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 2",
                                  );
    like( $output, qr/>Bars<\/a>/, "...and can be overridden" );

    # Test @INDEX_LIST
    $wiki->write_node( "Test 3", "\@INDEX_LIST [[Category Foo]]" )
      or die "Can't write node";
    $wiki->write_node( "Test 4", "\@INDEX_LIST [[Locale Bar]]" )
      or die "Can't write node";
    $wiki->write_node( "Test 5", "\@INDEX_LIST [[Category Nonexistent]]" )
      or die "Can't write node";
    $wiki->write_node( "Test 6", "\@INDEX_LIST [[Locale Nonexistent]]" )
      or die "Can't write node";
    $wiki->write_node( "Wibble", "wibble", undef,
                       {
                         category => "foo",
                         locale   => "bar",
                       }
                     )
      or die "Can't write node";
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 3",
                                  );
    like ( $output, qr|<a href=".*">Wibble</a>|,
           '@INDEX_LIST works for categories' );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 5",
                                  );
    like ( $output, qr|No pages currently in category|,
           "...and fails nicely if no pages in category" );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 4",
                                  );
    like ( $output, qr|<a href=".*">Wibble</a>|,
           '@INDEX_LIST works for locales' );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 6",
                                  );
    like ( $output, qr|No pages currently in locale|,
           "...and fails nicely if no pages in locale" );
}
