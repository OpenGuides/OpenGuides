use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides::Search;
use Test::More;

eval { require DBD::SQLite; };

if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with. ($error)";
}

plan tests => 10;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Config->new(
       vars => {
                 dbtype             => "sqlite",
                 dbname             => "t/node.db",
                 indexing_directory => "t/indexes",
                 script_name        => "wiki.cgi",
                 script_url         => "http://example.com/",
                 site_name          => "Test Site",
                 template_path      => "./templates",
               }
);

# Plucene is the recommended searcher now.
eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) { $config->use_plucene( 0 ) };

my $search = OpenGuides::Search->new( config => $config );

# Add some data.  We write it twice to avoid hitting the redirect.
my $wiki = $search->{wiki}; # white boxiness
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
is_deeply( \@found, [ "Calthorpe Arms", "Penderel's Oak" ],
           "simple search looks in category" );

%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "pubs" },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "Calthorpe Arms", "Penderel's Oak" ],
           "...and is case-insensitive" );

# Check that a search on its locale works.
%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "Holborn" },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "British Museum", "Calthorpe Arms", "Penderel's Oak" ],
           "simple search looks in locale" );

%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "holborn" },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "British Museum", "Calthorpe Arms", "Penderel's Oak" ],
           "...and is case-insensitive" );

# Test AND search in various combinations.
%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "Holborn Pubs" },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "Calthorpe Arms", "Penderel's Oak" ],
           "AND search works between category and locale" );

%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars         => { search => "Holborn Penderel" },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "Penderel's Oak" ],
           "AND search works between title and locale" );

%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "Pubs Penderel" },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "Penderel's Oak" ],
           "AND search works between title and category" );

%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "Holborn beer" },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "Calthorpe Arms", "Penderel's Oak" ],
           "...and between body and locale" );

%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => "Pubs beer" },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "Calthorpe Arms", "Penderel's Oak" ],
           "...and between body and category" );

%tt_vars = $search->run(
                         return_tt_vars => 1,
                         vars           => { search => '"major attractions"' },
                       );
@found = sort map { $_->{name} } @{ $tt_vars{results} || [] };
is_deeply( \@found, [ "British Museum", ],
           "Multi word category name" );
