use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides;
use OpenGuides::Feed;
use OpenGuides::Utils;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with. ($error)";
}

eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) {
    plan skip_all => "Plucene not installed";
}


plan tests => 5;

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
                 home_name          => "Home",
                 use_plucene        => 1
               }
);

# Basic sanity check first.
my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

my $feed = OpenGuides::Feed->new( wiki   => $wiki,
                                  config => $config );


# Write the first version
my $guide = OpenGuides->new( config => $config );
    
# Set up CGI parameters ready for a node write.
# Most of these are in here to avoid uninitialised value warnings.
my $q = CGI->new;
$q->param( -name => "content", -value => "foo" );
$q->param( -name => "categories", -value => "" );
$q->param( -name => "locales", -value => "" );
$q->param( -name => "phone", -value => "" );
$q->param( -name => "fax", -value => "" );
$q->param( -name => "website", -value => "" );
$q->param( -name => "hours_text", -value => "" );
$q->param( -name => "address", -value => "" );
$q->param( -name => "postcode", -value => "" );
$q->param( -name => "map_link", -value => "" );
$q->param( -name => "os_x", -value => "" );
$q->param( -name => "os_y", -value => "" );
$q->param( -name => "username", -value => "bob" );
$q->param( -name => "comment", -value => "foo" );
$q->param( -name => "node_image", -value => "image" );
$q->param( -name => "edit_type", -value => "Minor tidying" );
$ENV{REMOTE_ADDR} = "127.0.0.1";

my $output = $guide->commit_node(
                                  return_output => 1,
                                  id => "Wombats",
                                  cgi_obj => $q,
                                );

# Check we have it
ok( $wiki->node_exists( "Wombats" ), "Wombats written" );

my %node = $wiki->retrieve_node("Wombats");
is( $node{version}, 1, "First version" );
is( $node{metadata}->{edit_type}[0], "Minor tidying", "Right edit type" );


# Now write a second version of it
$q->param( -name => "edit_type", -value => "Normal edit" );
$q->param( -name => "checksum", -value => $node{checksum} );
$output = $guide->commit_node(
                               return_output => 1,
                               id => "Wombats",
                               cgi_obj => $q,
                             );

# Check it's as expected
%node = $wiki->retrieve_node("Wombats");
is( $node{version}, 2, "First version" );
is( $node{metadata}->{edit_type}[0], "Normal edit", "Right edit type" );
