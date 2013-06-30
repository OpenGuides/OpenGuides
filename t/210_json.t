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

plan tests => 30;

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

like( $json, qr|<\?xml version="1.0" \?>|, "JSON uses no encoding when none set" );
$config->http_charset( "UTF-8" );
$guide = OpenGuides->new( config => $config );
$json = $json_writer->emit_json( node => "Calthorpe Arms" );
like( $json, qr|<\?xml version="1.0" encoding="UTF-8"\?>|, "JSON uses declared encoding" );

like( $json, qr|<foaf:depiction json:resource="http://example.com/calthorpe.jpg" />|, "Node image");

like( $json, qr|<wail:Neighborhood json:nodeID="Bloomsbury">|,
    "finds the first locale" );
like( $json, qr|<wail:Neighborhood json:nodeID="St_Pancras">|,
    "finds the second locale" );

like( $json, qr|<contact:phone>test phone number</contact:phone>|,
    "picks up phone number" );

like( $json, qr|<dc:available>test hours</dc:available>|,
    "picks up opening hours text" );

like( $json, qr|<foaf:homepage json:resource="http://example.com" />|, "picks up website" );

like( $json,
    qr|<dc:title>Wiki::Toolkit Test Site: Calthorpe Arms</dc:title>|,
    "sets the title correctly" );

like( $json, qr|id=Kake;format=json#obj"|,
    "last username to edit used as contributor" );
like( $json, qr|id=Anonymous;format=json#obj"|,
    "... as well as previous usernames" );

like( $json, qr|<wiki:version>2</wiki:version>|, "version picked up" );

like( $json, qr|<json:Description json:about="">|, "sets the 'about' correctly" );

like( $json, qr|<dc:source json:resource="http://wiki.example.com/mywiki.cgi\?Calthorpe_Arms" />|,
    "set the dc:source with the version-independent uri" );

like( $json, qr|<wail:City json:nodeID="city">\n\s+<wail:name>London</wail:name>|, "city" ).
like( $json, qr|<wail:locatedIn>\n\s+<wail:Country json:nodeID="country">\n\s+<wail:name>United Kingdom</wail:name>|, "country" ).
like( $json, qr|<wail:postalCode>WC1X 8JR</wail:postalCode>|, "postcode" );
like( $json, qr|<geo:lat>51.524193</geo:lat>|, "latitude" );
like( $json, qr|<geo:long>-0.114436</geo:long>|, "longitude" );
like( $json, qr|<dc:description>a nice pub</dc:description>|, "summary (description)" );

like( $json, qr|<dc:date>|, "date element included" );
unlike( $json, qr|<dc:date>1970|, "hasn't defaulted to the epoch" );

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
unlike( $json, qr|<city>|, "no city in JSON when no default city" );
unlike( $json, qr|<country>|, "...same for country" );

# Now test that there's a nice failsafe where a node doesn't exist.
$json = eval { $json_writer->emit_json( node => "I Do Not Exist" ); };
is( $@, "", "->emit_json doesn't die when called on a nonexistent node" );

like( $json, qr|<wiki:version>0</wiki:version>|, "...and wiki:version is 0" );

# Test the data for a node that redirects.
$wiki->write_node( "Calthorpe Arms Pub",
    "#REDIRECT [[Calthorpe Arms]]",
    undef,
    {
        comment  => "Created as redirect to Calthorpe Arms page.",
        username => "Earle",
    }
);

my $redirect_json = $json_writer->emit_json( node => "Calthorpe Arms Pub" );

like( $redirect_json, qr|<owl:sameAs json:resource="/\?id=Calthorpe_Arms;format=json#obj" />|,
    "redirecting node gets owl:sameAs to target" );

$wiki->write_node( "Nonesuch Stores",
    "A metaphysical wonderland",
    undef,
    {
        comment            => "Yup.",
        username           => "Nobody",
        opening_hours_text => "Open All Hours",
    }
);

$json = $json_writer->emit_json( node => "Nonesuch Stores" );

like( $json, qr|<geo:SpatialThing json:ID="obj">|,
    "having opening hours marks node as geospatial" );

