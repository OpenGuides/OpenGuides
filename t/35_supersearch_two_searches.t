use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
} else {
    plan tests => 2;

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

    # Write some data.
    my $wiki = $search->{wiki};
    $wiki->write_node( "Wandsworth Common", "A common.", undef,
                       { category => "Parks" } )
        or die "Can't write node";
    $wiki->write_node( "Hammersmith", "A page about Hammersmith." )
        or die "Can't write node";

    my (%tt_vars, @results);
    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "parks" },
                           );
    @results = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@results, [ "Wandsworth_Common" ],
               "first search returns expected results" );
    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "hammersmith" },
                           );
    @results = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@results, [ "Hammersmith" ],
               "so does second" );

}
