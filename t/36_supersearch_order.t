use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
} else {
    plan tests => 6;

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

    # Write some data.
    $wiki->write_node( "Parks", "A page about parks." )
        or die "Can't write node";
    $wiki->write_node( "Wandsworth Common", "A common.", undef,
                       { category => "Parks" } )
        or die "Can't write node";
    $wiki->write_node( "Kake", "I like walking in parks." )
        or die "Can't write node";

    my %tt_vars = $search->run(
                                return_tt_vars => 1,
                                vars           => { search => "parks" },
                              );
    foreach my $result ( @{ $tt_vars{results} || [] } ) {
        print "# $result->{name} scores $result->{score}\n";
    }
    my %scores = map { $_->{name} => $_->{score} } @{$tt_vars{results} || []};
    ok( $scores{Kake} < $scores{Wandsworth_Common},
        "content match scores less than category match" );
    ok( $scores{Wandsworth_Common} < $scores{Parks},
        "title match scores less than category match" );

    # Now test locales.
    $wiki->write_node( "Hammersmith", "A page about Hammersmith." )
        or die "Can't write node";
    $wiki->write_node( "The Gate", "A restaurant.", undef,
                       { locale => "Hammersmith" } )
        or die "Can't write node";
    $wiki->write_node( "Kake Pugh", "I live in Hammersmith." )
        or die "Can't write node";

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "hammersmith" },
                           );
    foreach my $result ( @{ $tt_vars{results} || [] } ) {
        print "# $result->{name} scores $result->{score}\n";
    }
    %scores = map { $_->{name} => $_->{score} } @{$tt_vars{results} || []};
    ok( $scores{Kake_Pugh} < $scores{The_Gate},
        "content match scores less than locale match" );
    ok( $scores{The_Gate} < $scores{Hammersmith},
        "locale match scores less than title match" );

    # Check that two words in the title beats one in the title and
    # one in the content.
    $wiki->write_node( "Putney Tandoori", "Indian food" )
      or die "Couldn't write node";
    $wiki->write_node( "Putney", "There is a tandoori restaurant here" )
      or die "Couldn't write node";

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "putney tandoori" },
                           );
    foreach my $result ( @{ $tt_vars{results} || [] } ) {
        print "# $result->{name} scores $result->{score}\n";
    }
    %scores = map { $_->{name} => $_->{score} } @{$tt_vars{results} || []};
    ok( $scores{Putney} < $scores{Putney_Tandoori},
        "two words in title beats one in title and one in content" );
}
