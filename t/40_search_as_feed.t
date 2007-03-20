use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Search;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

plan tests => 7;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Test->make_basic_config;
$config->script_name( "wiki.cgi" );
$config->script_url( "http://example.com/" );

# Plucene is the recommended searcher now.
eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) { $config->use_plucene( 0 ) };

my $search = OpenGuides::Search->new( config => $config );
isa_ok( $search, "OpenGuides::Search" );

# Pop some test data in
my $wiki = $search->{wiki}; # white boxiness
$wiki->write_node( "Banana", "banana" );
$wiki->write_node( "Monkey", "banana brains" );
$wiki->write_node( "Monkey Brains", "BRANES" );
$wiki->write_node( "Want Pie Now", "weebl" );
$wiki->write_node( "Punctuation", "*" );
$wiki->write_node( "Choice", "Eenie meenie minie mo");

# RSS search, should give 2 hits
my $output = $search->run(
                         return_output => 1,
                         vars => { search => "banana", format => "rss" },
                       );

like($output, qr/<rdf:RDF/, "Really was RSS");
like($output, qr/<items>/, "Really was RSS");

my @found = ($output =~ /(<rdf:li)/g);
is( scalar @found, 2, "found right entries in feed" );


# Atom search, should give 1 hit
$output = $search->run(
                        return_output => 1,
                        vars => { search => "weebl", format => "atom" },
                      );
like($output, qr/<feed/, "Really was Atom");
like($output, qr/<entry>/, "Really was Atom");

@found = ($output =~ /(<entry>)/g);
is( scalar @found, 1, "found right entries in feed" );