use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides::Search;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

eval { require Plucene; };
if ( $@ ) {
    plan skip_all => "Plucene not installed";
}

# Strictly speaking we don't need to skip _all_ tests if we don't have
# the modules below.  Revisit this when not in a hurry.
# We only actually need the former for the National Grid tests and the
# latter for the UTM tests.
eval { require Geography::NationalGrid; };
if ( $@ ) { 
    plan skip_all => "Geography::NationalGrid not installed";
}

eval { require Geo::Coordinates::UTM; };
if ( $@ ) { 
    plan skip_all => "Geo::Coordinates::UTM not installed";
}

plan tests => 10;

# Clear out the database from any previous runs.
    OpenGuides::Test::refresh_db();

my $config = OpenGuides::Config->new(
       vars => {
                 dbtype             => "sqlite",
                 dbname             => "t/node.db",
                 indexing_directory => "t/indexes",
                 script_name        => "wiki.cgi",
                 script_url         => "http://example.com/",
                 site_name          => "Test Site",
                 template_path      => "./templates",
                 geo_handler        => 1,
               }
);

# Plucene is the recommended searcher now.
eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) { $config->use_plucene( 0 ) };

my $search = OpenGuides::Search->new( config => $config );

# Write some data.
my $wiki = $search->{wiki};
$wiki->write_node( "Wandsworth Common", "A common.", undef,
                   { category => "Parks" } )
    or die "Can't write node";
$wiki->write_node( "Hammersmith", "A page about Hammersmith." )
    or die "Can't write node";

# Check that the search forgets input search term between invocations.
$search->run(
              return_output => 1,
              vars          => { search => "parks" },
            );
ok( $search->{search_string}, "search_string set" );
$search->run(
              return_output => 1,
            );
ok( !$search->{search_string}, "...and forgotten" );

# Sanity check.
my (@results, %tt_vars);
%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "parks" },
                       );
@results = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@results, [ "Wandsworth Common" ],
           "first search returns expected results" );
%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "hammersmith" },
                       );
@results = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@results, [ "Hammersmith" ],
           "so does second" );

# Check that the search forgets input geodata between invocations.
# First with British National Grid.
$search->run(
              return_output => 1,
              vars => { os_x => 500000, os_y => 100000, os_dist => 1000 },
            );
ok( $search->{x}, "x-coord set" );
$search->run(
              return_output => 1,
              vars => { search => "foo" },
            );
ok( !$search->{x}, "...and forgotten" );

# Now with Irish National Grid.
$config->geo_handler( 2 );
$search = OpenGuides::Search->new( config => $config );
$search->run(
              return_output => 1,
              vars => { osie_x => 100000, osie_y => 200000, osie_dist => 100 },
            );
ok( $search->{x}, "x-coord set" );
$search->run(
              return_output => 1,
              vars => { search => "foo" },
            );
ok( !$search->{x}, "...and forgotten" );

# Now with UTM.
$config->geo_handler( 3 );
$config->ellipsoid( "Airy" );
$search = OpenGuides::Search->new( config => $config );
$search->run(
              return_output => 1,
              vars => { latitude => 10, longitude => 0, latlong_dist => 1000 },
            );
ok( $search->{x}, "x-coord set" );
$search->run(
              return_output => 1,
              vars => { search => "foo" },
            );
ok( !$search->{x}, "...and forgotten" );


