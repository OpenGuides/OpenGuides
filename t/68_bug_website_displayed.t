use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };

if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

plan tests => 2;

Wiki::Toolkit::Setup::SQLite::cleardb( { dbname => "t/node.db" } );
Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Test->make_basic_config;
my $guide = OpenGuides->new( config => $config );

$guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", undef, { website => "http://example.com/" } ) or die "Couldn't write node";
$guide->wiki->write_node( "North Croydon Station", "A busy main-line station in what is arguably the furthest North part of Croydon.", undef, { website => "http://longer.example.com/asdfasdf" } ) or die "Couldn't write node";

my $output = $guide->display_node(
                                     id => "South Croydon Station",
                                     return_output => 1,
                                 );
like( $output, qr#Website:</span> <span class="url"><a href="http://example.com/">http://example.com/</a>#, "website correctly displayed" );

$output = $guide->display_node(   
                                    id => "North Croydon Station",
                                    return_output => 1,
                              );

like( $output, qr#Website:</span> <span class="url"><a href="http://longer.example.com/asdfasdf">http://longer.exampl...</a>#, "website correctly truncated" );
