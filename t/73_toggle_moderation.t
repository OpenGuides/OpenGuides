use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More tests => 14;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 14
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


    # First up, try with no password
    my $output = $guide->set_node_moderation(
                                id => "Test Page 3",
                                moderation_flag => 0,
                                return_output => 1
    );
    like($output, qr|Change moderation status|, "Confirm page");
    like($output, qr|Confirm Moderation|, "Confirm page");


    # Now, try with the wrong password
    $output = $guide->set_node_moderation(
                                id => "Test Page 3",
                                moderation_flag => 0,
                                password => "I_AM_WRONG",
                                return_output => 1
    );
    like($output, qr|Incorrect Password|, "Wrong password");
    like($output, qr|Incorrect password for page moderation|, "Wrong password");


    # Check that "Test Page 3" doesn't have moderation set
    my %node = $wiki->retrieve_node("Test Page 3");
    is($node{'node_requires_moderation'}, 0, "Doesn't have moderation on by default");

    # Set the moderation flag on it to off
    $guide->set_node_moderation(
                                id => "Test Page 3",
                                moderation_flag => 0,
                                password => $guide->config->admin_pass
    );
    %node = $wiki->retrieve_node("Test Page 3");
    is($node{'node_requires_moderation'}, 0, "Doesn't have moderation set when called with 0");

    # Set it to on
    $guide->set_node_moderation(
                                id => "Test Page 3",
                                moderation_flag => 1,
                                password => $guide->config->admin_pass
    );
    %node = $wiki->retrieve_node("Test Page 3");
    is($node{'node_requires_moderation'}, 1, "Turned on properly");
   
    # Set it back to off
    $guide->set_node_moderation(
                                id => "Test Page 3",
                                moderation_flag => 0,
                                password => $guide->config->admin_pass
    );
    %node = $wiki->retrieve_node("Test Page 3");
    is($node{'node_requires_moderation'}, 0, "Turned off properly");


    # Test we were sent to the right place
    $output = $guide->set_node_moderation(
                                id => "Test Page 3",
                                moderation_flag => 0,
                                password => $guide->config->admin_pass,
                                return_output => 1
    );
    like($output, qr|Location: http://example.com/wiki.cgi\?action=admin;moderation=changed|, "Right location");
    like($output, qr|Status: 302|, "Right status");

    # And again, but this time with a made up node
    $output = $guide->set_node_moderation(
                                id => "THIS PAGE DOES NOT EXIST",
                                moderation_flag => 0,
                                password => $guide->config->admin_pass,
                                return_output => 1
    );
    like($output, qr|Location: http://example.com/wiki.cgi\?action=admin;moderation=unknown_node|, "Right location");
    like($output, qr|Status: 302|, "Right status");
}
