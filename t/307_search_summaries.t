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

plan tests => 2;

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
               }
);

# Plucene is the recommended searcher now.
eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) { $config->use_plucene( 0 ) };

my $search = OpenGuides::Search->new( config => $config );
isa_ok( $search, "OpenGuides::Search" );
my $wiki = $search->wiki;
$wiki->write_node( "Pub Crawls", "The basic premise of the pub crawl is to visit a succession of pubs, rather than spending the entire evening or day in a single establishment. London offers an excellent choice of themes for your pub crawl.", undef, { category => "Pubs" } ) or die "Can't write node";

my $output = $search->run(
                           return_output => 1,
                           vars          => { search => "pub" }
                         );
SKIP: {
    skip "TODO: summaries", 1;
    like( $output, qr|<b>pub</b>|i,
          "outputs at least one bolded occurence of 'pub'" );
} # end of SKIP
