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
