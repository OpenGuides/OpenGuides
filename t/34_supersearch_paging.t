use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
}

eval { require Plucene; };
if ( $@ ) {
    plan skip_all => "Plucene not installed";
}

plan tests => 9;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;
CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );

my $config = OpenGuides::Test->make_basic_config;
$config->{_}{use_plucene} = 1;
my $search = OpenGuides::SuperSearch->new( config => $config );
my $guide = OpenGuides->new( config => $config );

# Test with OS co-ords.
eval { require Geography::NationalGrid::GB; };
SKIP: {
    skip "Geography::NationalGrid::GB not installed", 1 if $@;
    $config->{_}{geo_handler} = 1;

    foreach my $i ( 1 .. 30 ) {
        OpenGuides::Test->write_data(
                                      guide      => $guide,
                                      node       => "Crabtree Tavern $i",
                                      os_x       => 523465,
                                      os_y       => 177490,
                                      categories => "Pubs",
                                    );
    }
    
    my $output = $search->run(
                               return_output => 1,
                               vars          => {
                                                  os_dist => 1500,
                                                  os_x => 523500,
                                                  os_y => 177500,
                                                },
                             );
    like( $output, qr/supersearch.cgi\?.*os_x=523500.*Next.*results/s,
          "os_x retained in next page link" );
    like( $output, qr/supersearch.cgi\?.*os_y=177500.*Next.*results/s,
          "os_y retained in next page link" );
    like( $output, qr/supersearch.cgi\?.*os_dist=1500.*Next.*results/s,
          "os_dist retained in next page link" );
}

# Test with OSIE co-ords.
eval { require Geography::NationalGrid::IE; };
SKIP: {
    skip "Geography::NationalGrid::IE not installed", 1 if $@;

    # We must create a new search object after changing the geo_handler
    # in order to force it to create a fresh locator.
    $config->{_}{geo_handler} = 2;
    my $search = OpenGuides::SuperSearch->new( config => $config );

    foreach my $i ( 1 .. 30 ) {
        OpenGuides::Test->write_data(
                                      guide      => $guide,
                                      node       => "I Made This Place Up $i",
                                      osie_x     => 100005,
                                      osie_y     => 200005,
                                    );
    }
    
    my $output = $search->run(
                               return_output => 1,
                               vars          => {
                                                  osie_dist => 1500,
                                                  osie_x => 100000,
                                                  osie_y => 200000,
                                                },
                             );
    like( $output, qr/supersearch.cgi\?.*osie_x=100000.*Next.*results/s,
          "osie_x retained in next page link" );
    like( $output, qr/supersearch.cgi\?.*osie_y=200000.*Next.*results/s,
          "osie_y retained in next page link" );
    like( $output, qr/supersearch.cgi\?.*osie_dist=1500.*Next.*results/s,
          "osie_dist retained in next page link" );
}

# Test with UTM.
eval { require Geo::Coordinates::UTM; };
SKIP: {
    skip "Geo::Coordinates::UTM not installed", 1 if $@;

    # We must create a new search object after changing the geo_handler
    # in order to force it to create a fresh locator.
    $config->{_}{geo_handler} = 3;
    $config->{_}{ellipsoid} = "International";
    my $search = OpenGuides::SuperSearch->new( config => $config );

    foreach my $i ( 1 .. 30 ) {
        OpenGuides::Test->write_data(
                                      guide      => $guide,
                                      node       => "London Aquarium $i",
                                      latitude   => 51.502,
                                      longitude  => -0.118,
                                    );
    }
    
    my $output = $search->run(
                               return_output => 1,
                               vars          => {
                                                  latlong_dist => 1500,
                                                  latitude     => 51.5,
                                                  longitude    => -0.12,
                                                },
                             );
    like( $output, qr/supersearch.cgi\?.*latitude=51.5.*Next.*results/s,
          "latitude retained in next page link" );
    like( $output, qr/supersearch.cgi\?.*longitude=-0.12.*Next.*results/s,
          "longitude retained in next page link" );
    like( $output, qr/supersearch.cgi\?.*latlong_dist=1500.*Next.*results/s,
          "latlong_dist retained in next page link" );
}
