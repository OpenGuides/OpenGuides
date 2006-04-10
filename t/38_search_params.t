use strict;
use CGI;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides::Search;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
    exit 0;
}

eval { require Wiki::Toolkit::Search::Plucene; };
if ( $@ ) { 
    plan skip_all => "Plucene not installed";
    exit 0;
}

# Strictly speaking we don't need to skip _all_ tests if we don't have
# the modules below.  Revisit this when not in a hurry.
# We only actually need them for the tests where lat/long are converted.
eval { require Geography::NationalGrid; };
if ( $@ ) { 
    plan skip_all => "Geography::NationalGrid not installed";
}

eval { require Geo::Coordinates::UTM; };
if ( $@ ) { 
    plan skip_all => "Geo::Coordinates::UTM not installed";
}

plan tests => 19;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Config->new(
       vars => {
                 dbtype             => "sqlite",
                 dbname             => "t/node.db",
                 indexing_directory => "t/indexes",
                 script_name        => "wiki.cgi",
                 script_url         => "http://example.com/",
                 site_name          => "Test Site",
                 template_path      => "./templates",
                 use_plucene        => 1,
                 geo_handler        => 1, # British National Grid
               }
);

# Check the British National Grid case.
my $q = CGI->new( "" );
$q->param( -name => "os_x",         -value => 500000 );
$q->param( -name => "os_y",         -value => 200000 );
$q->param( -name => "os_dist",      -value => 500    );
$q->param( -name => "osie_dist",    -value => 600    );
$q->param( -name => "latlong_dist", -value => 700    );
my %vars = $q->Vars();
my $search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
is( $search->{distance_in_metres}, 500,
    "os_dist picked up when OS co-ords given and using British grid" );
is( $search->{x}, 500000, "...x set from os_x" );
is( $search->{y}, 200000, "...y set from os_y" );

$q = CGI->new( "" );
$q->param( -name => "osie_x",       -value => 500000 );
$q->param( -name => "osie_y",       -value => 200000 );
$q->param( -name => "os_dist",      -value => 500    );
$q->param( -name => "osie_dist",    -value => 600    );
$q->param( -name => "latlong_dist", -value => 700    );
%vars = $q->Vars();
$search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
ok( !defined $search->{distance_in_metres},
    "OSIE co-ords ignored when using British grid" );

$q = CGI->new( "" );
$q->param( -name => "latitude",     -value => 51  );
$q->param( -name => "longitude",    -value => 1   );
$q->param( -name => "os_dist",      -value => 500 );
$q->param( -name => "osie_dist",    -value => 600 );
$q->param( -name => "latlong_dist", -value => 700 );
%vars = $q->Vars();
$search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
is( $search->{distance_in_metres}, 700,
    "latlong_dist picked up when lat/long given and using British grid" );
ok( defined $search->{x}, "...x set" );
ok( defined $search->{y}, "...y set" );


# Check the Irish National Grid case.
$config->geo_handler( 2 );

$q = CGI->new( "" );
$q->param( -name => "osie_x",       -value => 500000 );
$q->param( -name => "osie_y",       -value => 200000 );
$q->param( -name => "os_dist",      -value => 500    );
$q->param( -name => "osie_dist",    -value => 600    );
$q->param( -name => "latlong_dist", -value => 700    );
%vars = $q->Vars();
$search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
is( $search->{distance_in_metres}, 600,
    "osie_dist picked up when OS co-ords given and using Irish grid" );
is( $search->{x}, 500000, "...x set from osie_x" );
is( $search->{y}, 200000, "...y set from osie_y" );

$q = CGI->new( "" );
$q->param( -name => "os_x",         -value => 500000 );
$q->param( -name => "os_y",         -value => 200000 );
$q->param( -name => "os_dist",      -value => 500    );
$q->param( -name => "osie_dist",    -value => 600    );
$q->param( -name => "latlong_dist", -value => 700    );
%vars = $q->Vars();
$search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
ok( !defined $search->{distance_in_metres},
    "OS co-ords ignored when using Irish grid" );

$q = CGI->new( "" );
$q->param( -name => "latitude",     -value => 55  );
$q->param( -name => "longitude",    -value => -5  );
$q->param( -name => "os_dist",      -value => 500 );
$q->param( -name => "osie_dist",    -value => 600 );
$q->param( -name => "latlong_dist", -value => 700 );
%vars = $q->Vars();
$search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
is( $search->{distance_in_metres}, 700,
    "latlong_dist picked up when lat/long given and using Irish grid" );
ok( defined $search->{x}, "...x set" );
ok( defined $search->{y}, "...y set" );


# Check the UTM case.
$config->geo_handler( 3 );
$config->ellipsoid( "Airy" );

$q = CGI->new( "" );
$q->param( -name => "os_x",         -value => 500000 );
$q->param( -name => "os_y",         -value => 200000 );
$q->param( -name => "os_dist",      -value => 500    );
$q->param( -name => "osie_dist",    -value => 600    );
$q->param( -name => "latlong_dist", -value => 700    );
%vars = $q->Vars();
$search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
ok( !defined $search->{distance_in_metres},
    "OS co-ords ignored when using UTM" );

$q = CGI->new( "" );
$q->param( -name => "osie_x",       -value => 500000 );
$q->param( -name => "osie_y",       -value => 200000 );
$q->param( -name => "os_dist",      -value => 500    );
$q->param( -name => "osie_dist",    -value => 600    );
$q->param( -name => "latlong_dist", -value => 700    );
%vars = $q->Vars();
$search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
ok( !defined $search->{distance_in_metres},
    "OSIE co-ords ignored when using UTM" );

$q = CGI->new( "" );
$q->param( -name => "latitude",     -value => 51  );
$q->param( -name => "longitude",    -value => 1   );
$q->param( -name => "os_dist",      -value => 500 );
$q->param( -name => "osie_dist",    -value => 600 );
$q->param( -name => "latlong_dist", -value => 700 );
%vars = $q->Vars();
$search = OpenGuides::Search->new( config => $config );
$search->run( vars => \%vars, return_output => 1 );
is( $search->{distance_in_metres}, 700,
    "latlong_dist picked up when lat/long given and using UTM" );
ok( defined $search->{x}, "...x set" );
ok( defined $search->{y}, "...y set" );
