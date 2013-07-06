use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Config;
use OpenGuides::JSON;
use OpenGuides::Utils;
use OpenGuides::Test;
use URI::Escape;
use Test::More;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all => "DBD::SQLite could not be used - no database to test with. ($error)";
}

plan tests => 26;

# clear out the database
OpenGuides::Test::refresh_db();


my $config = OpenGuides::Test->make_basic_config;
$config->script_url( "http://wiki.example.com/" );
$config->script_name( "mywiki.cgi" );
$config->site_name( "Wiki::Toolkit Test Site" );
$config->default_city( "London" );
$config->default_country( "United Kingdom" );
$config->geo_handler( 3 );

eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) { $config->use_plucene ( 0 ) };


my $guide = OpenGuides->new( config => $config );
my $wiki = $guide->wiki;


my $json_writer_no_wiki = eval {
    OpenGuides::JSON->new( wiki => '', config => $config );
};
isnt( $@, "", "croak if wiki object not supplied" );

my $json_writer_no_config = eval {
    OpenGuides::JSON->new( wiki => $wiki, config => '' );
};
isnt( $@, "", "croak if config object not supplied" );

my $json_writer = eval {
    OpenGuides::JSON->new( wiki => $wiki, config => $config );
};
is( $@, "", "'new' doesn't croak if wiki and config objects supplied" );
isa_ok( $json_writer, "OpenGuides::JSON" );

# Test the data for a node that exists.
OpenGuides::Test->write_data(
        guide              => $guide,
        node               => "Calthorpe Arms",
        content            => "CAMRA-approved pub near King's Cross",
        comment            => "Stub page, please update!",
        username           => "Anonymous",
        postcode           => "WC1X 8JR",
        locales            => "Bloomsbury\r\nSt Pancras",
        phone              => "test phone number",
        website            => "http://example.com",
        hours_text         => "test hours",
        latitude           => "51.524193",
        longitude          => "-0.114436",
        summary            => "a really nice pub",
);

OpenGuides::Test->write_data(
        guide              => $guide,
        node               => "Calthorpe Arms",
        content            => "CAMRA-approved pub near King's Cross",
        comment            => "Stub page, please update!",
        username           => "Kake",
        postcode           => "WC1X 8JR",
        locales            => "Bloomsbury\r\nSt Pancras",
        phone              => "test phone number",
        website            => "http://example.com",
        hours_text         => "test hours",
        latitude           => "51.524193",
        longitude          => "-0.114436",
        summary            => "a nice pub",
        node_image         => "http://example.com/calthorpe.jpg",
);

my $json = $json_writer->emit_json( node => "Calthorpe Arms" );

SKIP: {
        eval "use Test::JSON";

        skip "Test::JSON not installed", 1 if $@;

        is_valid_json( $json, "is well formed json");
      };

like( $json, qr|"locales":\["|,
     "displays and array of locales" );
like( $json, qr|"Bloomsbury"|,
    "finds the first locale" );
like( $json, qr|"St Pancras"|,
    "finds the second locale" );

like( $json, qr|"phone":"test phone number"|,
    "picks up phone number" );

like( $json, qr|"opening_hours_text":"test hours"|,
    "picks up opening hours text" );

like( $json, qr|"website":"http://example.com"|, "picks up website" );


like( $json, qr|username":"Kake"|,
    "last username to edit used as contributor" );

like( $json, qr|"version":"2"|, "version picked up" );


like( $json, qr|"version_indpt_url":"http://wiki.example.com/mywiki.cgi\?Calthorpe_Arms"|,
    "set the dc:source with the version-independent uri" );

like( $json, qr|"city":"London"|, "city" ).
like( $json, qr|"country":"United Kingdom"|, "country" ).
like( $json, qr|"postcode":"WC1X 8JR"|, "postcode" );
like( $json, qr|"latitude":"51.524193"|, "latitude" );
like( $json, qr|"longitude":"-0.114436"|, "longitude" );
like( $json, qr|"summary":"a nice pub"|, "summary (description)" );

like( $json, qr|"timestamp":"|, "date element included" );
unlike( $json, qr|"timestamp":"1970|, "hasn't defaulted to the epoch" );

# Check that default city and country can be set to blank.
$config = OpenGuides::Test->make_basic_config;
$config->default_city( "" );
$config->default_country( "" );
$guide = OpenGuides->new( config => $config );
OpenGuides::Test->write_data(
                                guide => $guide,
                                node  => "Star Tavern",
                                latitude => 51.498,
                                longitude => -0.154,
                            );
$json_writer = OpenGuides::JSON->new( wiki => $guide->wiki, config => $config );
$json = $json_writer->emit_json( node => "Star Tavern" );
like( $json, qr|"city":""|, "no city in JSON when no default city" );
like( $json, qr|"country":""|, "...same for country" );

# Now test that there's a nice failsafe where a node doesn't exist.
$json = eval { $json_writer->emit_json( node => "I Do Not Exist" ); };
is( $@, "", "->emit_json doesn't die when called on a nonexistent node" );

# this really should be 'like( $json, qr|"version":"0"|, "...and version is 0" );' but theres a json output change which does the right thing. 
like( $json, qr|0|, "...and version is 0" );

