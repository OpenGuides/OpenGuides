use strict;
use CGI::Wiki::Setup::SQLite;
use OpenGuides;
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

plan tests => 2;

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;

CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
my $config = OpenGuides::Test->make_basic_config;
$config->{_}{site_name} = "Test Site";
my $guide = OpenGuides->new( config => $config );

OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "London Zoo",
                              content    => "It's a zoo.",
                            );
my $wiki = $guide->wiki;
my %data = $wiki->retrieve_node( "London Zoo" );
is( $data{content}, "It's a zoo.", "first write with write_data went in" );

OpenGuides::Test->write_data(
                              guide      => $guide,
                              node       => "London Zoo",
                              content    => "It's still a zoo.",
                            );
%data = $wiki->retrieve_node( "London Zoo" );
is( $data{content}, "It's still a zoo.", "...so does second" );

