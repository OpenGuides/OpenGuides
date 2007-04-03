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

plan tests => 2;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Test->make_basic_config;
$config->script_url( "http://www.example.com/" );
$config->script_name( "wiki.cgi" );
my $guide = OpenGuides->new( config => $config );
my $wiki = $guide->wiki;

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

my $node_param = $output;
$node_param =~ s/^.*\?//s;
$node_param =~ s/\s+$//;
my $formatter = $guide->wiki->formatter;
my $node = $formatter->node_param_to_node_name( $node_param );
print "# Random node chosen: $node\n";
ok( $nodes{$node}, "...to an existing node" );
