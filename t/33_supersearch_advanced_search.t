use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
use Test::More tests => 8;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 8
      unless $have_sqlite;

    # Clear out the database from any previous runs.
    unlink "t/node.db";
    unlink <t/indexes/*>;

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

    # Plucene is the recommended searcher now.
    eval { require CGI::Wiki::Search::Plucene; };
    unless ( $@ ) {
        $config->{_}{use_plucene} = 1;
    }

    my $search = OpenGuides::SuperSearch->new( config => $config );

    # Add some data.  Write more than one pub to avoid hitting the redirect.
    my $wiki = $search->{wiki}; # white boxiness
    my $ctdata = {
                   os_x      => 523465,
                   os_y      => 177490,
                   latitude  => 51.482385,
                   longitude => -0.221743,
                   category  => "Pubs",
                 };
    $wiki->write_node( "Crabtree Tavern",
                       "Nice pub on the riverbank.",
                       undef,
                       $ctdata,
                     ) or die "Couldn't write node";
    my $badata = {
                   os_x      => 522909,
                   os_y      => 178232,
                   latitude  => 51.489176,
                   longitude => -0.229488,
                   category  => "Pubs",
                 };
    $wiki->write_node( "Blue Anchor",
                       "Another pub.",
                       undef,
                       $badata,
                     ) or die "Couldn't write node";
    my $stdata = {
                   os_x      => 528107,
                   os_y      => 179347,
                   latitude  => 51.498043,
                   longitude => -0.154247,
                   category  => "Pubs",
                 };
    $wiki->write_node( "Star Tavern",
                       "A most excellent pub.",
                       undef,
                       $stdata,
                     ) or die "Couldn't write node";
    my $hbdata = {
                   os_x      => 522983,
                   os_y      => 178118,
                   latitude  => 51.488135,
                   longitude => -0.228463,
                 };
    $wiki->write_node( "Hammersmith Bridge",
                       "It's a bridge.",
                       undef,
                       $hbdata,
                     ) or die "Couldn't write node";

    # Sanity check.
    print "# Distances should be:\n";
    use CGI::Wiki::Plugin::Locator::UK;
    my $locator = CGI::Wiki::Plugin::Locator::UK->new;
    $wiki->register_plugin( plugin => $locator );
    foreach my $node ( "Blue Anchor", "Crabtree Tavern", "Hammersmith Bridge"){
        print "# $node: " . $locator->distance( from_lat  => 51.484320,
                                                from_long => -0.223484,
                                                to_node   => $node ) . "\n";
    }

    # Check that a distance search finds them.
    my %tt_vars = $search->run(
                                return_tt_vars => 1,
                                vars => {
                                          lat  => 51.484320,
                                          long => -0.223484,
                                          distance_in_metres => 1000,
                                        },
                              );
    my @ordered = map { $_->{name} } @{ $tt_vars{results} || [] };
    my @found = sort @ordered;
    is_deeply( \@found,
               [ "Blue Anchor", "Crabtree Tavern", "Hammersmith Bridge" ],
               "distance search finds the right things" );
    is_deeply( \@ordered,
               [ "Crabtree Tavern", "Hammersmith Bridge", "Blue Anchor" ],
               "...and returns them in the right order" );

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars => {
                                       lat  => 51.484320,
                                       long => -0.223484,
                                       distance_in_metres => 1000,
                                       search => " ",
                                     },
                           );
    @ordered = map { $_->{name} } @{ $tt_vars{results} || [] };
    @found = sort @ordered;
    is_deeply( \@found,
               [ "Blue Anchor", "Crabtree Tavern", "Hammersmith Bridge" ],
               "...still works if whitespace-only search text supplied" );

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars => {
                                       os_x => 523450,
                                       os_y => 177650,
                                       distance_in_metres => 1000,
                                       search => " ",
                                     },
                           );
    @ordered = map { $_->{name} } @{ $tt_vars{results} || [] };
    @found = sort @ordered;
    is_deeply( \@found,
               [ "Blue Anchor", "Crabtree Tavern", "Hammersmith Bridge" ],
               "...works with OS co-ords" );

    %tt_vars = eval {
               $search->run(
                             return_tt_vars => 1,
                             vars => {
                                       os_x => 523450,
                                       os_y => 177650,
                                       distance_in_metres => 1000,
                                       search => " ",
                                       lat => " ",
                                       long => " ",
                                     },
                           );
    };
    is( $@, "", "...works with OS co-ords and whitespace-only lat/long" );
    @ordered = map { $_->{name} } @{ $tt_vars{results} || [] };
    @found = sort @ordered;
    is_deeply( \@found,
               [ "Blue Anchor", "Crabtree Tavern", "Hammersmith Bridge" ],
                 "...returns the right stuff" );

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars => {
                                       lat  => 51.484320,
                                       long => -0.223484,
                                       distance_in_metres => 1000,
                                       search => "pubs",
                                     },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "Blue Anchor", "Crabtree Tavern", ],
               "distance search in combination with text search works" );

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars => {
                                       os_x => 523450,
                                       os_y => 177650,
                                       distance_in_metres => 1000,
                                       search => "pubs",
                                     },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "Blue Anchor", "Crabtree Tavern", ],
               "...works with OS co-ords too" );
}
