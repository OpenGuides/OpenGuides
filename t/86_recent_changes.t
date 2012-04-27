use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides;
use OpenGuides::Feed;
use OpenGuides::Utils;
use OpenGuides::Test;
use Test::More;
use OpenGuides::CGI;


eval { require DBD::SQLite; };
if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with. ($error)";
}

eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) {
    plan skip_all => "Plucene not installed";
}


plan tests => 14;

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
my $q = OpenGuides::Test->make_cgi_object(
    content => "foo",
    username => "bob",
    comment => "First edit",
    node_image => "image",
    edit_type => "Normal edit",
);

my $output = $guide->commit_node(
                                  return_output => 1,
                                  id => "Wombats",
                                  cgi_obj => $q,
                                );

# Check we have it
ok( $wiki->node_exists( "Wombats" ), "Wombats written" );

my %node = $wiki->retrieve_node("Wombats");
is( $node{version}, 1, "First version" );


# Now write a second version of it
$q->param( -name => "edit_type", -value => "Normal edit" );
$q->param( -name => "checksum", -value => $node{checksum} );
$q->param( -name => "comment", -value => "Second edit" );
$output = $guide->commit_node(
                               return_output => 1,
                               id => "Wombats",
                               cgi_obj => $q,
                             );

# Check it's as expected
%node = $wiki->retrieve_node("Wombats");
is( $node{version}, 2, "First version" );
is( $node{metadata}->{edit_type}[0], "Normal edit", "Right edit type" );

# Now try to commit some invalid data, and make sure we get an edit form back
$q = OpenGuides::Test->make_cgi_object(
    content => "foo",
    os_x => "fooooo",
    username => "bob",
    comment => "bar",
    node_image => "image",
    edit_type => "Minor tidying"
);

$output = $guide->commit_node(
                                return_output => 1,
                                id => "Wombats again",
                                cgi_obj => $q,
                             );

like( $output, qr/Your input was invalid/,
    "Edit form displayed and invalid input message shown if invalid input" );

like( $output, qr/os_x must be integer/,
    "Edit form displayed and os_x integer message displayed" );

my @nodes = $wiki->list_recent_changes( days => 1 );
    is( scalar @nodes, 1,
        "By default each node returned only once however many times changed" );
    @nodes = $wiki->list_recent_changes( days => 1, include_all_changes => 1 );
    is( scalar @nodes, 2,
        "...returned more than once when 'include_all_changes' set" );

# when minor_edits = 1

my $cookie = OpenGuides::CGI->make_prefs_cookie(
    config                     => $config,
    username                   => "bob",
    include_geocache_link      => 1,
    preview_above_edit_box     => 1,
    omit_help_links            => 1,
    show_minor_edits_in_rc     => 1,
    default_edit_type          => "tidying",
    cookie_expires             => "never",
    track_recent_changes_views => 1,
    is_admin => 1,
);
$output = $guide->display_recent_changes( return_output => 1 );

unlike ($output, qr/First edit/, "showing a page edit twice when show minor edits enabled. "); 


# set show_minor_edits to 0.
 $cookie = OpenGuides::CGI->make_prefs_cookie(
    config                     => $config,
    username                   => "bob",
    include_geocache_link      => 1,
    preview_above_edit_box     => 1,
    omit_help_links            => 1,
    show_minor_edits_in_rc     => 0,
    default_edit_type          => "tidying",
    cookie_expires             => "never",
    track_recent_changes_views => 1,
    is_admin => 1,
);
$ENV{HTTP_COOKIE} = $cookie;



$output = $guide->display_recent_changes( return_output => 1 );

TODO: {
    local $TODO = "http://dev.openguides.org/ticket/270";
    unlike ($output, qr/First edit/, "showing a page edit twice when not showing minor edits"); 
}

# Now write a node that will Auto Create a locale, and check the
# Recent Changes output with minor edits and admin links switched on.
# We can't use OG::Test->write_data() for this, because it calls
# make_cgi_object(), which overwrites REMOTE_ADDR (and we want to test
# output of IP address).
$q = OpenGuides::Test->make_cgi_object();
$q->param( -name => "username", -value => "Anonymous" );
$q->param( -name => "locales", -value => "London" );
my $test_host = "198.51.100.255";
$ENV{REMOTE_ADDR} = $test_host;
$guide->commit_node( id => "A Pub", cgi_obj => $q, return_output => 1 );
$ENV{HTTP_COOKIE} = OpenGuides::CGI->make_prefs_cookie(
    config => $config, show_minor_edits_in_rc => 1, is_admin => 1 );
$output = $guide->display_recent_changes( return_output => 1 );
like( $output, qr|Auto\s+Create|,
      "Auto Create stuff shown on Recent Changes." );
unlike( $output, qr|host=;action=userstats|,
        "...and no spurious link to host userstats" );

# Make sure IP addresses always show up for anonymous edits.
$ENV{HTTP_COOKIE} = OpenGuides::CGI->make_prefs_cookie(
    config => $config, is_admin => 1 );
$output = $guide->display_recent_changes( return_output => 1 );
like( $output, qr|$test_host|,
      "IP addresses show for anon edits when admin links switched on" );
$ENV{HTTP_COOKIE} = OpenGuides::CGI->make_prefs_cookie(
    config => $config, is_admin => 0 );
$output = $guide->display_recent_changes( return_output => 1 );
like( $output, qr|$test_host|,
      "...also when admin links switched off" );

