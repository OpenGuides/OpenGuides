use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides;
use OpenGuides::Template;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };

if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with ($error)";
}

plan tests => 8;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;
Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );

my $config = OpenGuides::Test->make_basic_config;
my $guide = OpenGuides->new( config => $config );

SKIP: {
    eval { require Geography::NationalGrid::GB; };
    skip "Geography::NationalGrid::GB not installed", 2 if $@;

    my $q = CGI->new( "" );
    $q->param( -name => "os_x", -value => " 123456 " );
    $q->param( -name => "os_y", -value => " 654321 " );
    $q->param( -name => "categories", -value => "" ); #avoid uninit val warning
    $q->param( -name => "locales", -value => "" );    #avoid uninit val warning

    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
        wiki    => $guide->wiki,
        config  => $config,
        cgi_obj => $q,
    );

    is( $metadata_vars{os_x}, "123456",
        "leading and trailing spaces stripped from os_x when processed" );
    is( $metadata_vars{os_y}, "654321", "...and os_y" );
}

SKIP: {
    eval { require Geography::NationalGrid::IE; };
    skip "Geography::NationalGrid::IE not installed", 2 if $@;

    $config->geo_handler( 2 );
    my $q = CGI->new( "" );
    $q->param( -name => "osie_x", -value => " 100000 " );
    $q->param( -name => "osie_y", -value => " 200000 " );
    $q->param( -name => "categories", -value => "" ); #avoid uninit val warning
    $q->param( -name => "locales", -value => "" );    #avoid uninit val warning

    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
        wiki    => $guide->wiki,
        config  => $config,
        cgi_obj => $q,
    );

    is( $metadata_vars{osie_x}, "100000",
        "leading and trailing spaces stripped from osie_x when processed" );
    is( $metadata_vars{osie_y}, "200000", "...and osie_y" );
}

SKIP: {
    eval { require Geo::Coordinates::UTM; };
    skip "Geo::Coordinates::UTM not installed", 2 if $@;

    $config->geo_handler( 3 );
    my $q = CGI->new( "" );
    $q->param( -name => "latitude", -value => " 1.463113 " );
    $q->param( -name => "longitude", -value => " -0.215293 " );
    $q->param( -name => "categories", -value => "" ); #avoid uninit val warning
    $q->param( -name => "locales", -value => "" );    #avoid uninit val warning

    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
        wiki    => $guide->wiki,
        config  => $config,
        cgi_obj => $q,
    );

    is( $metadata_vars{latitude}, "1.463113",
        "leading and trailing spaces stripped from latitude when processed" );
    is( $metadata_vars{longitude}, "-0.215293", "...and longitude" );
}

OpenGuides::Test->write_data(
                              guide => $guide,
                              node  => "A Node",
                              categories => " Food \r\n Live Music ",
                              locales    => " Hammersmith \r\n Fulham ",
);
my %node = $guide->wiki->retrieve_node( "A Node" );
my %data = %{ $node{metadata} };
my @cats = sort @{ $data{category} || [] };
is_deeply( \@cats, [ "Food", "Live Music" ],
    "leading and trailing spaces stripped from all categories when stored" );
my @locs = sort @{ $data{locale} || [] };
is_deeply( \@locs, [ "Fulham", "Hammersmith" ], "...and all locales" );
