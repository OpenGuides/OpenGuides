use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides::SuperSearch;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed";
} else {
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
                   };

    # Plucene is the recommended searcher now.
    eval { require CGI::Wiki::Search::Plucene; };
    unless ( $@ ) {
        $config->{_}{use_plucene} = 1;
    }

    my $search = OpenGuides::SuperSearch->new( config => $config );
    my $wiki = $search->wiki;

    foreach my $i ( 1 .. 30 ) {
        $wiki->write_node( "Crabtree Tavern $i",
                           "Nice pub on the riverbank.",
                           undef,
                           {
                             os_x      => 523465,
                             os_y      => 177490,
                             latitude  => 51.482385,
                             longitude => -0.221743,
                             category  => "Pubs",
                           }
                         ) or die "Couldn't write node";
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
}
