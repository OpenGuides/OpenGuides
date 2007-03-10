use strict;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed - no database to test with";
} else {
    plan tests => 1;
}

my $config = OpenGuides::Test->make_basic_config;
my $guide = OpenGuides->new( config => $config );
my $wiki = $guide->wiki;

# Clear out the database from any previous runs.
foreach my $del_node ( $wiki->list_all_nodes ) {
    print "# Deleting node $del_node\n";
    $wiki->delete_node( $del_node ) or die "Can't delete $del_node";
}

# Check that autocapitalisation works correctly in categories with hyphens.
OpenGuides::Test->write_data(
                              guide => $guide,
                              node  => "Vivat Bacchus",
                              categories => "Restaurants\r\nVegan-friendly",
                            );

ok( $wiki->node_exists( "Category Vegan-Friendly" ),
    "Categories with hyphens in are auto-created correctly." );
