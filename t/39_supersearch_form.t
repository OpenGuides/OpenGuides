use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
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

plan tests => 27;

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

# British National Grid guides should have os and latlong search fields.
my $search = OpenGuides::SuperSearch->new( config => $config );
my $output = $search->run( return_output => 1 );
# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "input", { name => "os_dist" },
                             "search page includes os_dist input with BNG" );
Test::HTML::Content::tag_ok( $output, "input", { name => "os_x" },
                             "...and os_x" );
Test::HTML::Content::tag_ok( $output, "input", { name => "os_y" },
                             "...and os_y" );
Test::HTML::Content::tag_ok( $output, "input", { name => "latlong_dist" },
                             "...and latlong_dist" );
Test::HTML::Content::tag_ok( $output, "input", { name => "latitude" },
                             "...and latitude" );
Test::HTML::Content::tag_ok( $output, "input", { name => "longitude" },
                             "...and longitude" );
Test::HTML::Content::no_tag( $output, "input", { name => "osie_dist" },
                             "...but not osie_dist" );
Test::HTML::Content::no_tag( $output, "input", { name => "osie_x" },
                             "...nor osie_x" );
Test::HTML::Content::no_tag( $output, "input", { name => "osie_y" },
                             "...nor osie_y" );

# Irish National Grid guides should have osie and latlong.
$config->{_}{geo_handler} = 2;
$search = OpenGuides::SuperSearch->new( config => $config );
$output = $search->run( return_output => 1 );
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "input", { name => "osie_dist" },
                             "search page includes os_dist input with ING" );
Test::HTML::Content::tag_ok( $output, "input", { name => "osie_x" },
                             "...and osie_x" );
Test::HTML::Content::tag_ok( $output, "input", { name => "osie_y" },
                             "...and osie_y" );
Test::HTML::Content::tag_ok( $output, "input", { name => "latlong_dist" },
                             "...and latlong_dist" );
Test::HTML::Content::tag_ok( $output, "input", { name => "latitude" },
                             "...and latitude" );
Test::HTML::Content::tag_ok( $output, "input", { name => "longitude" },
                             "...and longitude" );
Test::HTML::Content::no_tag( $output, "input", { name => "os_dist" },
                             "...but not os_dist" );
Test::HTML::Content::no_tag( $output, "input", { name => "os_x" },
                             "...nor os_x" );
Test::HTML::Content::no_tag( $output, "input", { name => "os_y" },
                             "...nor os_y" );

# UTM guides should have latitude/longitude/latlong_dist only.
$config->{_}{geo_handler} = 3;
$config->{_}{ellipsoid} = "Airy";
$search = OpenGuides::SuperSearch->new( config => $config );
$output = $search->run( return_output => 1 );
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "input", { name => "latlong_dist" },
                             "includes latlong_dist with UTM" );
Test::HTML::Content::tag_ok( $output, "input", { name => "latitude" },
                             "...and latitude" );
Test::HTML::Content::tag_ok( $output, "input", { name => "longitude" },
                             "...and longitude" );
Test::HTML::Content::no_tag( $output, "input", { name => "os_dist" },
                             "...but not os_dist" );
Test::HTML::Content::no_tag( $output, "input", { name => "os_x" },
                             "...nor os_x" );
Test::HTML::Content::no_tag( $output, "input", { name => "os_y" },
                             "...nor os_y" );
Test::HTML::Content::no_tag( $output, "input", { name => "osie_x" },
                             "...but not osie_x" );
Test::HTML::Content::no_tag( $output, "input", { name => "osie_y" },
                             "...nor osie_y" );
Test::HTML::Content::no_tag( $output, "input", { name => "osie_dist" },
                             "...nor osie_dist" );
