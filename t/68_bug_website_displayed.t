use CGI::Wiki::Setup::SQLite;
use OpenGuides;
use OpenGuides::Test;
use Test::More tests => 1;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 1
      unless $have_sqlite;

    CGI::Wiki::Setup::SQLite::cleardb( { dbname => "t/node.db" } );
    CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Test->make_basic_config;
    my $guide = OpenGuides->new( config => $config );

    $guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", undef, { website => "http://www.example.com/" } ) or die "Couldn't write node";

    my $output = $guide->display_node(
                                       id => "South Croydon Station",
                                       return_output => 1,
                                     );
    like( $output, qr#Website:</span> <a href="http://www.example.com/">http://www.example.com/</a>#, "website correctly displayed" );
}

