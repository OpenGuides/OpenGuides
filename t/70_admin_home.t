use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More tests => 13;

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


    # Add 3 different pages, one of which with two versions
    $wiki->write_node( "Test Page", "foo", undef,
                       { category => "Alpha" } )
      or die "Couldn't write node";
    $wiki->write_node( "Test Page 2", "foo", undef,
                       { category => "Alpha" } )
      or die "Couldn't write node";
    $wiki->write_node( "Locale Bar", "foo", undef,
                       { category => "Locales" } )
      or die "Couldn't write locale";
    my %data = $wiki->retrieve_node( "Locale Bar" );
    $wiki->write_node( "Locale Bar", "foo version 2", $data{checksum},
                       { category => "Locales" } )
      or die "Couldn't write locale for the 2nd time";


    # Test the tt vars
    my %ttvars = eval {
           $guide->display_admin_interface( return_tt_vars=> 1 );
    };
    is( $@, "", "->display_admin_interface doesn't die" );

    is( scalar @{$ttvars{'nodes'}}, 2, "Right number of nodes" );
    is( scalar @{$ttvars{'locales'}}, 1, "Right number of locales" );
    is( scalar @{$ttvars{'categories'}}, 0, "Right number of categories" );

    is( $ttvars{'nodes'}->[0]->{name}, "Test Page", "Right nodes" );
    is( $ttvars{'nodes'}->[1]->{name}, "Test Page 2", "Right nodes" );
    is( $ttvars{'locales'}->[0]->{name}, "Bar", "Right locale, right name" );

    # Test the normal, HTML version
    my $output = eval {
        $guide->display_admin_interface( return_output=>1 );
    };
    is( $@, "", "->display_admin_interface doesn't die" );

    like( $output, qr|Site Administration|, "Right page" );
    like( $output, qr|Test Page|, "Has nodes" );
    like( $output, qr|Bar|, "Has locales" );
}
