use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides;
use Test::More;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

plan tests => 13;

Wiki::Toolkit::Setup::SQLite::cleardb( { dbname => "t/node.db" } );
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
               }
);
eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) { $config->use_plucene ( 0 ) };

my $guide = OpenGuides->new( config => $config );
isa_ok( $guide, "OpenGuides" );
my $wiki = $guide->wiki;
isa_ok( $wiki, "Wiki::Toolkit" );
$wiki->write_node( "Test Page", "foo", undef, { source => "alternate.cgi?Test_Page" } );
my $output = eval {
    $guide->display_node( id => "Test Page", return_output => 1 );
};
is( $@, "", "->display_node doesn't die" );

like( $output, qr{\<a.*?\Qhref="alternate.cgi?id=Test_Page;action=edit"\E>Edit\s+this\s+page</a>}, "...and edit link is redirected to source URL" );
$config->home_name( "My Home Page" );
$output = $guide->display_node( return_output => 1 );
like( $output, qr/My\s+Home\s+Page/, "...and defaults to the home node, and takes notice of what we want to call it" );
like( $output, qr{\Q<a href="wiki.cgi?action=edit;id=My_Home_Page"\E>Edit\s+this\s+page</a>}, "...and home page has an edit link" );
my %tt_vars = $guide->display_node( return_tt_vars => 1 );
ok( defined $tt_vars{recent_changes}, "...and recent_changes is set for the home node even if we have changed its name" );

$wiki->write_node( 'Redirect Test', '#REDIRECT Test Page', undef );

$output = $guide->display_node( id => 'Redirect Test',
                                return_output => 1,
                                intercept_redirect => 1 );

like( $output, qr{^\QLocation: http://example.com/wiki.cgi?id=Test_Page;oldid=Redirect_Test}ms,
      '#REDIRECT redirects correctly' );

$output = $guide->display_node( id => 'Redirect Test', return_output => 1, redirect => 0 );

unlike( $output, qr{^\QLocation: }ms, '...but not with redirect=0' );

$wiki->write_node( "Non-existent categories and locales", "foo", undef,
                                { category => [ "Does not exist" ],
                                  locale   => [ "Does not exist" ] } );

$output = $guide->display_node( id => 'Non-existent categories and locales',
                                return_output => 1
                              );

unlike( $output, qr{\Q<a href="wiki.cgi?Category_Does_Not_Exist"},
    'Category name not linked if category does not exist' );

$wiki->write_node( "Category_Does_Not_Exist", "bar", undef, undef );

$output = $guide->display_node( id => 'Non-existent categories and locales',
                                return_output => 1
                              );

like( $output, qr{\Q<a href="wiki.cgi?Category_Does_Not_Exist"},
    'but does when it does exist' );

unlike( $output, qr{\Q<a href="wiki.cgi?Locale_Does_Not_Exist"},
    'Locale name not linked if category does not exist' );

$wiki->write_node( "Locale_Does_Not_Exist", "wibble", undef, undef );

$output = $guide->display_node( id => 'Non-existent categories and locales',
                                return_output => 1
                              );

like( $output, qr{\Q<a href="wiki.cgi?Locale_Does_Not_Exist"},
    'but does when it does exist' );


