use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides;
use OpenGuides::Feed;
use OpenGuides::Utils;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
    exit 0;
}

eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) {
    plan skip_all => "Plucene not installed";
    exit 0;
}

plan tests => 7;

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

my $rss = eval { $feed->make_feed(feed_type => 'rss'); };
is( $@, "", "->make_feed for rss doesn't croak" );

# Now write some data, first a minor edit then a non-minor one.
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
$q->param( -name => "edit_type", -value => "Minor tidying" );
$ENV{REMOTE_ADDR} = "127.0.0.1";

my $output = $guide->commit_node(
                                  return_output => 1,
                                  id => "Wombats",
                                  cgi_obj => $q,
                                );

$q->param( -name => "edit_type", -value => "Normal edit" );
$output = $guide->commit_node(
                               return_output => 1,
                               id => "Badgers",
                               cgi_obj => $q,
                             );

$q->param( -name => "username", -value => "Kake" );
$output = $guide->commit_node(
                               return_output => 1,
                               id => "Wombles",
                               cgi_obj => $q,
                             );

# Check that the writes went in.
ok( $wiki->node_exists( "Wombats" ), "Wombats written" );
ok( $wiki->node_exists( "Badgers" ), "Badgers written" );
ok( $wiki->node_exists( "Wombles" ), "Wombles written" );

# Check that the minor edits can be filtered out.
$output = $guide->display_feed(
                               feed_type          => "rss",
                               items              => 5,
                               username           => "bob",
                               ignore_minor_edits => 1,
                               return_output      => 1,
                             );
unlike( $output, qr/Wombats/, "minor edits filtered out when required" );
like( $output, qr/Badgers/, "but normal edits still in" );

# Check that the username parameter is taken notice of.
unlike( $output, qr/Wombles/, "username parameter taken note of" );
