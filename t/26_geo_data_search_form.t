use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
}

eval { require Plucene; };
if ( $@ ) {
    plan skip_all => "Plucene not installed";
}

eval { require Test::HTML::Content; };
if ( $@ ) {
    plan skip_all => "Test::HTML::Content not installed";
    exit 0;
}

# Strictly speaking we don't need to skip _all_ tests if we don't have
# the modules below.  Revisit this when not in a hurry.
# We only actually need the former for the National Grid tests and the
# latter for the UTM tests.
eval { require Geography::NationalGrid; };
if ( $@ ) { 
    plan skip_all => "Geography::NationalGrid not installed";
}

eval { require Geo::Coordinates::UTM; };
if ( $@ ) { 
    plan skip_all => "Geo::Coordinates::UTM not installed";
}

plan tests => 12;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = Config::Tiny->new;
$config->{_} = {
                 dbtype             => "sqlite",
                 dbname             => "t/node.db",
                 indexing_directory => "t/indexes",
                 script_name        => "wiki.cgi",
                 script_url         => "http://example.com/",
                 site_name          => "Test Site",
                 home_name          => "Home",
                 template_path      => "./templates",
                 use_plucene        => 1,
                 geo_handler        => 1,
               };

# British National Grid guides should have os_x/os_y/os_dist search fields.
my $guide = OpenGuides->new( config => $config );

write_data(
            guide      => $guide,
            node       => "Banana Leaf",
            os_x       => 532125,
            os_y       => 165504,
          );

# Display the node, check that the distance search form defaults to OS co-ords
# (stops places being "found" 70m away from themselves due to rounding).
my $output = $guide->display_node(
                                   id => "Banana Leaf",
                                   return_output => 1,
                                 );

# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "select", { name => "os_dist" },
                             "distance select defaults to os_dist with BNG" );
# Use a regex; Test::HTML::Content can't do this yet I think (read docs, check)
like( $output, qr|select\sname="os_dist".*metres.*kilometres.*/select|is,
      "...and to offering distances in metres/kilometres" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "os_x", value => "532125" },
                             "...includes input 'os_x' with correct value");
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "os_y", value => "165504" },
                             "...includes input 'os_y' with correct value");


# Irish National Grid guides should have osie_x/osie_y/osie_dist.
$config->{_}{geo_handler} = 2;
$guide = OpenGuides->new( config => $config );

write_data(
            guide      => $guide,
            node       => "I Made This Place Up",
            osie_x     => 100000,
            osie_y     => 200000,
          );

# Display node, check distance search form.
$output = $guide->display_node(
                                id => "I Made This Place Up",
                                return_output => 1,
                              );

$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "select", { name => "osie_dist" },
                             "distance select defaults to osie_dist with ING");
like( $output, qr|select\sname="osie_dist".*metres.*kilometres.*/select|is,
      "...and to offering distances in metres/kilometres" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "osie_x", value => "100000" },
                             "...includes input 'osie_x' with correct value");
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "osie_y", value => "200000" },
                             "...includes input 'osie_y' with correct value");


# UTM guides should have latitude/longitude/latlong_dist.
$config->{_}{geo_handler} = 3;
$config->{_}{ellipsoid} = "Airy";
$guide = OpenGuides->new( config => $config );

write_data(
            guide      => $guide,
            node       => "London Aquarium",
            latitude   => 51.502,
            longitude  => -0.118,
          );

# Display node, check distance search form.
# UTM guides currently use latitude/longitude for searching.
$output = $guide->display_node(
                                id => "London Aquarium",
                                return_output => 1,
                              );
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "select", { name => "latlong_dist" },
                             "dist select defaults to latlong_dist with UTM" );
like( $output, qr|select\sname="latlong_dist".*metres.*kilometres.*/select|is,
      "...and to offering distances in metres/kilometres" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "latitude", value => "51.502" },
                             "...includes input 'latitude' with correct value");
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "longitude", value => "-0.118" },
                             "...includes input 'longitude' with correct value");



sub write_data {
    my %args = @_;
    
    # Set up CGI parameters ready for a node write.
    # Most of these are in here to avoid uninitialised value warnings.
    my $q = CGI->new( "" );
    $q->param( -name => "content", -value => "foo" );
    $q->param( -name => "categories", -value => $args{categories} || "" );
    $q->param( -name => "locales", -value => "" );
    $q->param( -name => "phone", -value => "" );
    $q->param( -name => "fax", -value => "" );
    $q->param( -name => "website", -value => "" );
    $q->param( -name => "hours_text", -value => "" );
    $q->param( -name => "address", -value => "" );
    $q->param( -name => "postcode", -value => "" );
    $q->param( -name => "map_link", -value => "" );
    $q->param( -name => "os_x", -value => $args{os_x} || "" );
    $q->param( -name => "os_y", -value => $args{os_y} || "" );
    $q->param( -name => "osie_x", -value => $args{osie_x} || "" );
    $q->param( -name => "osie_y", -value => $args{osie_y} || "" );
    $q->param( -name => "latitude", -value => $args{latitude} || "" );
    $q->param( -name => "longitude", -value => $args{longitude} || "" );
    $q->param( -name => "username", -value => "Kake" );
    $q->param( -name => "comment", -value => "foo" );
    $q->param( -name => "edit_type", -value => "Normal edit" );
    $ENV{REMOTE_ADDR} = "127.0.0.1";
    
    $args{guide}->commit_node(
                               return_output => 1,
                               id => $args{node},
                               cgi_obj => $q,
                             );
}
