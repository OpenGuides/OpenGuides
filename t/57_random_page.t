use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Test;
use OpenGuides;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

plan tests => 4;

my ( $config, $guide, $wiki );

# Clear out database from previous runs, set up a guide.
refresh_db();
$config = OpenGuides::Test->make_basic_config;
$config->script_url( "http://www.example.com/" );
$config->script_name( "wiki.cgi" );
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;

# Write some data.
my %nodes = map { $_ => "A pub." } ( "Red Lion", "Farmers Arms", "Angel" );
foreach my $node ( keys %nodes ) {
  OpenGuides::Test->write_data(
                                guide         => $guide,
                                node          => $node,
                                return_output => 1,
                              );
}

# See what we get when we ask for a random page.
my $output = $guide->display_random_page( return_output => 1 );

# Old versions of CGI.pm mistakenly print location: instead of Location:
like( $output, qr/[lL]ocation: http:\/\/www.example.com\/wiki.cgi/,
      "->display_random_page makes a redirect" );

my $node = get_node_from_output( $output );
print "# Random node chosen: $node\n";
ok( $nodes{$node}, "...to an existing node" );

# Clear the database and write some data including categories and locales.
refresh_db();
$config = OpenGuides::Test->make_basic_config;
$config->script_url( "http://www.example.com/" );
$config->script_name( "wiki.cgi" );
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;

# Write data including some categories/locales.
OpenGuides::Test->write_data(
                              guide         => $guide,
                              node          => "Red Lion",
                              locales       => "Hammersmith",
                              categories    => "Pubs",
                              return_output => 1,
                            );

# Check we can turn off locales.
$config = OpenGuides::Test->make_basic_config;
$config->script_url( "http://www.example.com/" );
$config->script_name( "wiki.cgi" );
$config->random_page_omits_locales( 1 );
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;
$output = $guide->display_random_page( return_output => 1 );
$node = get_node_from_output( $output );
print "# Random node chosen: $node\n";
isnt( $node, "Locale Hammersmith", "locale nodes not picked up as random page "
                       . "(this test may sometimes pass when it shouldn't)" );

# Check we can turn off categories.
$config = OpenGuides::Test->make_basic_config;
$config->script_url( "http://www.example.com/" );
$config->script_name( "wiki.cgi" );
$config->random_page_omits_categories( 1 );
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;
$output = $guide->display_random_page( return_output => 1 );
$node = get_node_from_output( $output );
print "# Random node chosen: $node\n";
isnt( $node, "Category Pubs", "category nodes not picked up as random page "
                       . "(this test may sometimes pass when it shouldn't)" );

sub refresh_db {
    unlink "t/node.db";
    unlink <t/indexes/*>;
    Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
}

sub get_node_from_output {
    my $node_param = shift;
    $node_param =~ s/^.*\?//s;
    $node_param =~ s/\s+$//;
    my $formatter = $guide->wiki->formatter;
    my $node = $formatter->node_param_to_node_name( $node_param );
    return $node;
}
