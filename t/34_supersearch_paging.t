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

eval { require Geography::NationalGrid::GB; };
if ( $@ ) {
    plan skip_all => "Geography::NationalGrid::GB not installed";
}

plan tests => 1;

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
                 use_plucene        => 1,
                 geo_handler        => 1,
               };

my $search = OpenGuides::SuperSearch->new( config => $config );
my $guide = OpenGuides->new( config => $config );

foreach my $i ( 1 .. 30 ) {
    write_data(
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
    $q->param( -name => "os_x", -value => $args{os_x} );
    $q->param( -name => "os_y", -value => $args{os_y} );
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
