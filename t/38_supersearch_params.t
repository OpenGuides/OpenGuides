use strict;
use CGI;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
} else {
    plan tests => 4;

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
                     template_path      => "./templates",
                   };

    # Plucene is the recommended searcher now.
    eval { require CGI::Wiki::Search::Plucene; };
    unless ( $@ ) {
        $config->{_}{use_plucene} = 1;
    }

    # Check we get the right distance when we supply OS co-ords.
    my $search = OpenGuides::SuperSearch->new( config => $config );
    isa_ok( $search, "OpenGuides::SuperSearch" );

    my $q = CGI->new;
    $q->param( -name => "os_x",         -value => 500000 );
    $q->param( -name => "os_y",         -value => 200000 );
    $q->param( -name => "os_dist",      -value => 500    );
    $q->param( -name => "latlong_dist", -value => 600    );
    my %vars = $q->Vars();

    $search->run( vars => \%vars, return_output => 1 );
    is( $search->{distance_in_metres}, 500,
        "os_dist picked up in pref. to latlong_dist when OS co-ords given" );

    # Check we get the right distance when we supply lat/long.
    $search = OpenGuides::SuperSearch->new( config => $config );
    isa_ok( $search, "OpenGuides::SuperSearch" );

    $q = CGI->new( "" );
    $q->param( -name => "lat",          -value => 51  );
    $q->param( -name => "long",         -value => 1   );
    $q->param( -name => "os_dist",      -value => 500 );
    $q->param( -name => "latlong_dist", -value => 600 );
    %vars = $q->Vars();

    $search->run( vars => \%vars, return_output => 1 );
    is( $search->{distance_in_metres}, 600,
        "latlong_dist picked up in pref. to os_dist when lat/long given" );
}
