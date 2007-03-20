use strict;
use OpenGuides;
use OpenGuides::Test;
use Test::More;
use Wiki::Toolkit::Setup::SQLite;

eval { require DBD::SQLite; };
if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

eval { require Test::HTML::Content; };
if ( $@ ) {
    plan skip_all => "Test::HTML::Content not installed";
}

plan tests => 1;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;
Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );

my $config = OpenGuides::Test->make_basic_config;
my $guide = OpenGuides->new( config => $config );
my $wiki = $guide->wiki;

my $q = OpenGuides::Test->make_cgi_object(
                                           content => "I am some content.",
                                           summary => "I am a summary.",
                                         );

# Get a checksum for a "blank" node.
my %node_data = $wiki->retrieve_node( "Clapham Junction Station" );
$q->param( -name => "checksum", -value => $node_data{checksum} );

my $output = $guide->preview_edit(
                                   id            => "Clapham Junction Station",
                                   cgi_obj       => $q,
                                   return_output => 1,
                                 );

# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::text_ok( $output, "I am a summary.",
                              "Summary shows up in preview." );
