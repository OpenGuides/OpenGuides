use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More tests => 26;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 26
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


    # Add 3 different pages, one of which with two versions
    $wiki->write_node( "Test Page", "foo", undef,
                       { category => "Alpha", lat=>"" } )
      or die "Couldn't write node";
    $wiki->write_node( "Test Page 2", "foo2", undef,
                       { category => "Alpha", lat=>"22.22" } )
      or die "Couldn't write node";
    $wiki->write_node( "Test Page 3", "foo33", undef,
                       { category => "Alpha" } )
      or die "Couldn't write node";
    $wiki->write_node( "Category Foo", "foo", undef,
                       { category => "Categories", lat=>"-8.77" } )
      or die "Couldn't write category";
    $wiki->write_node( "Locale Bar", "foo", undef,
                       { category => "Locales", lat=>"8.22" } )
      or die "Couldn't write locale";
    my %data = $wiki->retrieve_node( "Locale Bar" );
    $wiki->write_node( "Locale Bar", "foo version 2", $data{checksum},
                       { category => "Locales", lat=>"8.88" } )
      or die "Couldn't write locale for the 2nd time";


    # Try without search parameters
    my %ttvars = eval {
           $guide->show_missing_metadata( return_tt_vars=> 1 );
    };
    my @nodes;
    is( $@, "", "->show_missing_metadata doesn't die" );

    is( scalar @{$ttvars{'nodes'}}, 0, "No nodes when no search params" );
    is( $ttvars{'done_search'}, 0, "Didn't search" );


    # Now try searching for those without lat
    %ttvars = eval {
           $guide->show_missing_metadata(
                                    metadata_type => 'lat',
                                    return_tt_vars => 1 
            );
    };

    @nodes = sort {$a->{'name'} cmp $b->{'name'}} @{$ttvars{'nodes'}};
    is( scalar @nodes, 2, "Two without / with empty lat" );
    is( $ttvars{'done_search'}, 1, "Did search" );
    is( $nodes[0]->{'name'}, "Test Page", "Right nodes" );
    is( $nodes[1]->{'name'}, "Test Page 3", "Right nodes" );


    # Now try searching for those without lat=22.22
    %ttvars = eval {
           $guide->show_missing_metadata(
                                    metadata_type => 'lat',
                                    metadata_value => '22.22',
                                    return_tt_vars => 1 
            );
    };

    @nodes = sort {$a->{'name'} cmp $b->{'name'}} @{$ttvars{'nodes'}};
    is( scalar @nodes, 4, "Four without that lat" );
    is( $ttvars{'done_search'}, 1, "Did search" );
    is( $nodes[0]->{'name'}, "Category Foo", "Right nodes" );
    is( $nodes[1]->{'name'}, "Locale Bar", "Right nodes" );
    is( $nodes[2]->{'name'}, "Test Page", "Right nodes" );
    is( $nodes[3]->{'name'}, "Test Page 3", "Right nodes" );


    # Try again, but exclude locale and category
    %ttvars = eval {
           $guide->show_missing_metadata(
                                    metadata_type => 'lat',
                                    metadata_value => '22.22',
                                    exclude_locales => 1,
                                    exclude_categories => 2,
                                    return_tt_vars => 1 
            );
    };

    @nodes = sort {$a->{'name'} cmp $b->{'name'}} @{$ttvars{'nodes'}};
    is( scalar @nodes, 2, "Two without that lat" );
    is( $ttvars{'done_search'}, 1, "Did search" );
    is( $nodes[0]->{'name'}, "Test Page", "Right nodes" );
    is( $nodes[1]->{'name'}, "Test Page 3", "Right nodes" );


    # Test the normal, HTML version
    my $output = eval {
        $guide->show_missing_metadata( return_output=>1 );
    };
    is( $@, "", "->how_missing_metadata doesn't die" );

    like( $output, qr|Missing Metadata|, "Right page" );
    like( $output, qr|Metadata Type|, "Has prompts" );
    unlike( $output, qr|<h3>Pages</h3>|, "Didn't search" );

    $output = eval {
        $guide->show_missing_metadata( return_output=>1, metadata_type=>'lat' );
    };
    is( $@, "", "->how_missing_metadata doesn't die" );
    like( $output, qr|<h3>Pages</h3>|, "searched" );
    like( $output, qr|Test Page|, "had node" );
}
