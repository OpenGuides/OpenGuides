use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More tests => 5;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 5
      unless $have_sqlite;

    Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Test->make_basic_config;
    my $guide = OpenGuides->new( config => $config );
    my $wiki = $guide->wiki;

    # Clear out the database from any previous runs.
    foreach my $del_node ( $wiki->list_all_nodes ) {
        print "# Deleting node $del_node\n";
        $wiki->delete_node( $del_node ) or die "Can't delete $del_node";
    }

    $wiki->write_node( "I Like Pie", "Best pie is meat pie." )
      or die "Couldn't write node";
    my %data = $wiki->retrieve_node( "I Like Pie" );
    $wiki->write_node( "I Like Pie", "Best pie is apple pie.",
                       $data{checksum} )
      or die "Couldn't write node";
    %data = $wiki->retrieve_node( "I Like Pie" );
    $wiki->write_node( "I Like Pie", "Best pie is lentil pie.",
                       $data{checksum} )
      or die "Couldn't write node";

    my $output = eval {
        $guide->display_diffs(
                               id            => "I Like Pie",
                               version       => 3,
                               other_version => 2,
                               return_output => 1,
                             );
    };
    is( $@, "", "->display_diffs doesn't die" );
    like( $output,
          qr/differences between version 2 and version 3/i,
          "...version numbers included in output" );
    like( $output, qr|<span class="node_name">I Like Pie</span>|,
          "...node name inlined in output" );
    unlike( $output, qr/contents are identical/i,
            "...'contents are identical' not printed when contents differ" );
    like( $output, qr/<th.*Version\s+2.*Version\s+3.*apple.*lentil/s,
          "...versions are right way round" );
}
