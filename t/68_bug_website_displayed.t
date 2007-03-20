use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };

if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

plan tests => 1;

Wiki::Toolkit::Setup::SQLite::cleardb( { dbname => "t/node.db" } );
Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Test->make_basic_config;
my $guide = OpenGuides->new( config => $config );

$guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", undef, { website => "http://www.example.com/" } ) or die "Couldn't write node";

my $output = $guide->display_node(
                                     id => "South Croydon Station",
                                     return_output => 1,
                                 );
like( $output, qr#Website:</span> <span class="url"><a href="http://www.example.com/">http://www.example.com/</a>#, "website correctly displayed" );

