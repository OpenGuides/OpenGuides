use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };

if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with. ($error)";
}

plan tests => 15;

SKIP: {
    # Clear out the database from any previous runs.
    OpenGuides::Test::refresh_db();

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

    # Test @MAP_LINK
    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test 1",
                                  content => "\@MAP_LINK [[Category Foo]]",
                                  return_output => 1,
                                );
    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test 2",
                                  content => "\@MAP_LINK [[Category Foo|Map]]",
                                  return_output => 1,
                                );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 1",
                                  );
    like( $output, qr/View map of pages in Category Foo/,
          "\@MAP_LINK has right default link text" );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 2",
                                  );
    like( $output, qr/>Map<\/a>/, "...and can be overridden" );

    # Test @RANDOM_PAGE_LINK
    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test Random",
                                  content => "\@RANDOM_PAGE_LINK",
                                  return_output => 1,
                                );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test Random",
                                  );
    like( $output, qr/View a random page on this guide/,
          "\@RANDOM_PAGE_LINK has right default link text" );

    # Not sure yet how to let people override link text in the above.  TODO.

    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test Random",
                                  content => "\@RANDOM_PAGE_LINK "
                                             . "[[Category Pubs]]",
                                  return_output => 1,
                                );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test Random",
                                  );
    like( $output, qr/View a random page in Category Pubs/,
          "\@RANDOM_PAGE_LINK has right default link text for categories" );
    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test Random",
                                  content => "\@RANDOM_PAGE_LINK "
                                             . "[[Category Pubs|Random pub]]",
                                  return_output => 1,
                                );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test Random",
                                  );
    like( $output, qr/>Random pub<\/a>/, "...and can be overridden" );

    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test Random",
                                  content => "\@RANDOM_PAGE_LINK "
                                             . "[[Locale Fulham]]",
                                  return_output => 1,
                                );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test Random",
                                  );
    like( $output, qr/View a random page in Locale Fulham/,
          "\@RANDOM_PAGE_LINK has right default link text for categories" );
    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test Random",
                                  content => "\@RANDOM_PAGE_LINK "
                                             . "[[Locale Fulham|"
                                             . "Random thing in Fulham]]",
                                  return_output => 1,
                                );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test Random",
                                  );
    like( $output, qr/>Random thing in Fulham<\/a>/,
          "...and can be overridden" );

    # Test @INCLUDE_NODE
    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test 1",
                                  content => "Hello, I am Test 1!\r\n"
                                             . "\@INCLUDE_NODE [[Test 2]]",
                                  return_output => 1,
                                );
    OpenGuides::Test->write_data(
                                  guide   => $guide,
                                  node    => "Test 2",
                                  content => "Hello, I am Test 2!",
                                  return_output => 1,
                                );
    $output = $guide->display_node(
                                    return_output => 1,
                                    id            => "Test 1",
                                  );
    like( $output, qr/Hello, I am Test 1!/,
          "Node with \@INCLUDE_NODE has its own content" );
    like( $output, qr/Hello, I am Test 2!/,
          "...and the included content" );
}
