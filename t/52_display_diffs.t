use strict;
use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use OpenGuides;
use Test::More tests => 4;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 4
      unless $have_sqlite;

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
    my $guide = OpenGuides->new( config => $config );
    my $wiki = $guide->wiki;

    # Clear out the database from any previous runs.
    foreach my $del_node ( $wiki->list_all_nodes ) {
        print "# Deleting node $del_node\n";
        $wiki->delete_node( $del_node ) or die "Can't delete $del_node";
    }

    $wiki->write_node( "I Like Pie", "Best pie is meat pie." )
      or die "Couldn't write node";
    my %data = $wiki->retrieve_node( "I Like Pie" );
    $wiki->write_node( "I Like Pie", "Best pie is apple pie.",
                       $data{checksum} )
      or die "Couldn't write node";
    %data = $wiki->retrieve_node( "I Like Pie" );
    $wiki->write_node( "I Like Pie", "Best pie is lentil pie.",
                       $data{checksum} )
      or die "Couldn't write node";

    my $output = eval {
        $guide->display_diffs(
                               id            => "I Like Pie",
                               version       => 3,
                               other_version => 2,
                               return_output => 1,
                             );
    };
    is( $@, "", "->display_diffs doesn't die" );
    like( $output,
          qr/differences between version 2 and version 3 of I Like Pie/i,
          "...version numbers included in output" );
    unlike( $output, qr/contents are identical/i,
            "...'contents are identical' not printed when contents differ" );
    like( $output, qr/<th.*Version\s+2.*Version\s+3.*apple.*lentil/s,
          "...versions are right way round" );
}
