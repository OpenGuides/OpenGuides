use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
use Test::More tests => 16;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 16
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

    my $search = OpenGuides::SuperSearch->new( config => $config );
    isa_ok( $search, "OpenGuides::SuperSearch" );

    # Clear out the database from any previous runs.
    my $wiki = $search->{wiki}; # white boxiness
    foreach my $del_node ( $wiki->list_all_nodes ) {
        print "# Deleting node $del_node\n";
        $wiki->delete_node( $del_node ) or die "Can't delete $del_node";
    }

    my $output = $search->run( return_output => 1 );
    unlike( $output, qr/no items matched/i,
            "doesn't output 'no items matched' if no terms supplied" );
    unlike( $output, qr/action=edit/,
            "doesn't offer edit link" );

    my %tt_vars = $search->run(
                                return_tt_vars => 1,
                                vars           => { search => "banana" },
                              );
    is( $tt_vars{first_num}, 0, "first_num set to 0 when no hits" );
    is( scalar @{ $tt_vars{results} }, 0, "...and results array empty" );

    $output = $search->run(
                            return_output => 1,
                            vars          => { search => "banana" }
                           );
    like( $output, qr/no items matched/i,
          "outputs 'no items matched' if term not found" );

    # Pop some data in and search again.
    $wiki = $search->{wiki}; # white boxiness
    $wiki->write_node( "Banana", "banana" );
    $wiki->write_node( "Monkey", "banana brains" );
    $wiki->write_node( "Monkey Brains", "BRANES" );
    $wiki->write_node( "Want Pie Now", "weebl" );
    $wiki->write_node( "Punctuation", "*" );
    $wiki->write_node( "Choice", "Eenie meenie minie mo");

    # Test with two hits first - simpler.
    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "banana" },
                           );
    my @found = map { $_->{name} } @{ $tt_vars{results} || [] };
    is( scalar @found, 2, "search finds single word twice" );
    is_deeply( [ sort @found ], [ "Banana", "Monkey" ],
               "...in the right places" );
    print "# Found in $_\n" foreach @found;

    # Make sure that $output matches too - we're testing the template here.
    $output =  $search->run(
                             return_output => 1,
                             vars           => { search => "banana" },
                           );
    like( $output, qr/<a href="http:\/\/example.com\/wiki.cgi\?Banana">/,
          "...and link is included in template output" );

    # Now try with one hit - should print redirect to that page.
    $output = $search->run(
                            return_output => 1,
                            vars          => { search => "weebl" },
                          );
    like( $output, qr/Status: 302 Moved/, "prints redirect on single hit" );
    # Old versions of CGI.pm mistakenly print location: instead of Location:
    like( $output,
          qr/[lL]ocation: http:\/\/example.com\/wiki.cgi\?Want_Pie_Now/,
          "...and node name munged correctly in URL" );

    # Test the AND search
    $output = $search->run(
                            return_output => 1,
                            vars          => { search => "monkey banana" },
                           );
    like( $output, qr/[lL]ocation: http:\/\/example.com\/wiki.cgi\?Monkey/,
          "AND search returns right results" );

    # Test the OR search
    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "brains, pie" },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "Monkey", "Monkey_Brains", "Want_Pie_Now" ],
               "OR search returns right results" );
    print "# Found in $_\n" foreach @found;

    # Test the NOT search
    $output = $search->run(
                            return_output => 1,
                            vars           => { search => "banana -monkey" },
                           );
    like( $output,
          qr/[lL]ocation: http:\/\/example.com\/wiki.cgi\?Banana/,    
          "NOT search returns right results"
        );

    # Test the phrase search
    $output = $search->run(
                            return_output => 1,
                            vars          => { search => '"monkey brains"' },
                           );
    like( $output,
          qr/[lL]ocation: http:\/\/example.com\/wiki.cgi\?Monkey_Brains/,    
          "phrase search returns right results"
        );

    #####
    ##### Test numbering when we have more than a page of results.
    #####

    foreach my $i ( 1 .. 30 ) {
        $wiki->write_node( "Node $i", "wombat" ) or die "Can't write Node $i";
    }
    $output = $search->run(
                            return_output => 1,
                            vars          => {
                                               search => "wombat",
                                               next   => 20,
                                             },
                          );
    like( $output, qr/ol start="21"/,
          "second page of results starts with right numbering" );
}
