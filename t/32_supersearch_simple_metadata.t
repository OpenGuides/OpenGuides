local $^W = 1;
use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
use Test::More;

eval { require DBD::SQLite; };

if ( $@ ) {
    plan skip_all => "DBD::SQLite needed to run these tests";
} else {
    plan tests => 12;

    # Ensure the test database is set up.
    CGI::Wiki::Setup::SQLite::setup( "t/sqlite.32.db" );

    my $config = Config::Tiny->new;
    $config->{_} = {
                     dbtype             => "sqlite",
                     dbname             => "t/sqlite.32.db",
                     indexing_directory => "t/index.32/",
                     script_name        => "wiki.cgi",
                     script_url         => "http://example.com/",
                     site_name          => "Test Site",
                     template_path      => "./templates",
                   };
    my $search = OpenGuides::SuperSearch->new( config => $config );

    # Clear out the database from any previous runs.
    my $wiki = $search->{wiki}; # white boxiness
    foreach my $del_node ( $wiki->list_all_nodes ) {
        $wiki->delete_node( $del_node ) or die "Can't delete $del_node";
    }

    # Add some data.  We write it twice to avoid hitting the redirect.
    $wiki = $search->{wiki}; # white boxiness
    $wiki->write_node( "Calthorpe Arms", "Serves beer.", undef,
                       { category => "Pubs", locale => "Holborn" } );
    $wiki->write_node( "Penderel's Oak", "Serves beer.", undef,
                       { category => "Pubs", locale => "Holborn" } );
    $wiki->write_node( "British Museum", "Huge museum, lots of artifacts.", undef,
                       { category => ["Museums", "Major Attractions"]
		       , locale => ["Holborn", "Bloomsbury"] } );

    # Check that a search on its category works.
    my %tt_vars = $search->run(
                                return_tt_vars => 1,
                                vars           => { search => "Pubs" },
                              );
    my @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "Calthorpe_Arms", "Penderel's_Oak" ],
               "simple search looks in category" );

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "pubs" },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "Calthorpe_Arms", "Penderel's_Oak" ],
               "...and is case-insensitive" );

    # Check that a search on its locale works.
    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "Holborn" },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "British_Museum", "Calthorpe_Arms", "Penderel's_Oak" ],
               "simple search looks in locale" );

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "holborn" },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "British_Museum", "Calthorpe_Arms", "Penderel's_Oak" ],
               "...and is case-insensitive" );

    # Test AND search in various combinations.
    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "Holborn Pubs" },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "Calthorpe_Arms", "Penderel's_Oak" ],
               "AND search works between category and locale" );

    my $output = $search->run(
                             return_output => 1,
                             vars         => { search => "Holborn Penderel" },
                           );
    like( $output, qr/Status: 302 Moved/, "title and locale, single hit" );
    like( $output, qr/Location: http:\/\/example.com\/wiki.cgi\?Penderel%27s_Oak/,
	          "...and node name munged correctly in URL" );

    $output = $search->run(
                             return_output => 1,
                             vars           => { search => "Pubs Penderel" },
                           );
    like( $output, qr/Status: 302 Moved/, "title and category, single hit" );
    like( $output, qr/Location: http:\/\/example.com\/wiki.cgi\?Penderel%27s_Oak/,
	          "...and node name munged correctly in URL" );

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "Holborn beer" },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "Calthorpe_Arms", "Penderel's_Oak" ],
               "...and between body and locale" );

    %tt_vars = $search->run(
                             return_tt_vars => 1,
                             vars           => { search => "Pubs beer" },
                           );
    @found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
    is_deeply( \@found, [ "Calthorpe_Arms", "Penderel's_Oak" ],
               "...and between body and category" );

SKIP: {
    skip "Multi word category broken", 1;
    $output = $search->run(
                             return_output => 1,
                             vars           => { search => "major attractions" },
                           );
    like( $output, qr/Status: 302 Moved/, "Multi word category, single hit" );
    like( $output, qr/Location: http:\/\/example.com\/wiki.cgi\?British_Museum/,
	          "...and node name munged correctly in URL" );
    }
}
