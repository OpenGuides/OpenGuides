use Wiki::Toolkit::Setup::SQLite;
use OpenGuides;
use OpenGuides::Config;
use OpenGuides::RDF;
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

plan tests => 28;

Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
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

# Clear out the database from any previous runs.
foreach my $del_node ( $wiki->list_all_nodes ) {
    $wiki->delete_node( $del_node ) or die "Can't delete $del_node";
}

my $rdf_writer = eval {
    OpenGuides::RDF->new( wiki => $wiki, config => $config );
};
is( $@, "", "'new' doesn't croak if wiki and config objects supplied" );
isa_ok( $rdf_writer, "OpenGuides::RDF" );

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
        website            => "test website",
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
        website            => "test website",
        hours_text         => "test hours",
        latitude           => "51.524193",
        longitude          => "-0.114436",
        summary            => "a nice pub",
);

my $rdfxml = $rdf_writer->emit_rdfxml( node => "Calthorpe Arms" );

like( $rdfxml, qr|<\?xml version="1.0"\?>|, "RDF is encoding-neutral" );

like( $rdfxml, qr|<dc:title>Bloomsbury</dc:title>|,
    "finds the first locale" );
like( $rdfxml, qr|<dc:title>St Pancras</dc:title>|,
    "finds the second locale" );

like( $rdfxml, qr|<phone>test phone number</phone>|,
    "picks up phone number" );

like( $rdfxml, qr|<chefmoz:Hours>test hours</chefmoz:Hours>|,
    "picks up opening hours text" );

like( $rdfxml, qr|<foaf:homepage rdf:resource="test website" />|, "picks up website" );

like( $rdfxml,
    qr|<dc:title>Wiki::Toolkit Test Site: Calthorpe Arms</dc:title>|,
    "sets the title correctly" );

like( $rdfxml, qr|<foaf:Person rdf:ID="Kake">|,
    "last username to edit used as contributor" );
like( $rdfxml, qr|<foaf:Person rdf:ID="Anonymous">|,
    "... as well as previous usernames" );

like( $rdfxml, qr|<wiki:version>2</wiki:version>|, "version picked up" );

like( $rdfxml, qr|<rdf:Description rdf:about="">|, "sets the 'about' correctly" );

like( $rdfxml, qr|<dc:source rdf:resource="http://wiki.example.com/mywiki.cgi\?Calthorpe_Arms" />|,
    "set the dc:source with the version-independent uri" );

like( $rdfxml, qr|<country>United Kingdom</country>|, "country" ).
like( $rdfxml, qr|<city>London</city>|, "city" ).
like( $rdfxml, qr|<postalCode>WC1X 8JR</postalCode>|, "postcode" );
like( $rdfxml, qr|<geo:lat>51.524193</geo:lat>|, "latitude" );
like( $rdfxml, qr|<geo:long>-0.114436</geo:long>|, "longitude" );
like( $rdfxml, qr|<dc:description>a nice pub</dc:description>|, "summary (description)" );

like( $rdfxml, qr|<dc:date>|, "date element included" );
unlike( $rdfxml, qr|<dc:date>1970|, "hasn't defaulted to the epoch" );

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
$rdf_writer = OpenGuides::RDF->new( wiki => $guide->wiki, config => $config );
$rdfxml = $rdf_writer->emit_rdfxml( node => "Star Tavern" );
unlike( $rdfxml, qr|<city>|, "no city in RDF when no default city" );
unlike( $rdfxml, qr|<country>|, "...same for country" );

# Now test that there's a nice failsafe where a node doesn't exist.
$rdfxml = eval { $rdf_writer->emit_rdfxml( node => "I Do Not Exist" ); };
is( $@, "", "->emit_rdfxml doesn't die when called on a nonexistent node" );

like( $rdfxml, qr|<wiki:version>0</wiki:version>|, "...and wiki:version is 0" );

# Test the data for a node that redirects.
$wiki->write_node( "Calthorpe Arms Pub",
    "#REDIRECT [[Calthorpe Arms]]",
    undef,
    {
        comment  => "Created as redirect to Calthorpe Arms page.",
        username => "Earle",
    }
);

my $redirect_rdf = $rdf_writer->emit_rdfxml( node => "Calthorpe Arms Pub" );

like( $redirect_rdf, qr|<owl:sameAs rdf:resource="/\?id=Calthorpe_Arms;format=rdf#obj" />|,
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

$rdfxml = $rdf_writer->emit_rdfxml( node => "Nonesuch Stores" );

like( $rdfxml, qr|<geo:SpatialThing rdf:ID="obj" dc:title="Nonesuch Stores">|,
    "having opening hours marks node as geospatial" );

