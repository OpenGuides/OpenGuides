use strict;
use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Config;
use OpenGuides::Utils;
use Test::More tests => 8;

eval { my $wiki = OpenGuides::Utils->make_wiki_object; };
ok( $@, "->make_wiki_object croaks if no config param supplied" );

eval { my $wiki = OpenGuides::Utils->make_wiki_object( config => "foo" ); };
ok( $@, "...and if config param isn't an OpenGuides::Config object" );

eval {
    my $wiki = OpenGuides::Utils->make_wiki_object(
        config => OpenGuides::Config->new( file => 'fake' )
    );
};

like( $@, qr/File 'fake' does not exist/, '...and Config::Tiny errors are reported');

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 5
      unless $have_sqlite;

    # Clear out the database from any previous runs.
    unlink "t/node.db";
    unlink <t/indexes/*>;
    Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );

    my $config = OpenGuides::Config->new(
           vars => {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_url         => "",
                     script_name        => "",
                   }
    );

    eval { require Wiki::Toolkit::Search::Plucene; };
    if ( $@ ) { $config->use_plucene ( 0 ) };

    my $wiki = eval {
        OpenGuides::Utils->make_wiki_object( config => $config );
    };
    is( $@, "",
        "...but not with an OpenGuides::Config object with suitable data" );
    isa_ok( $wiki, "Wiki::Toolkit" );

    ok( $wiki->store,      "...and store defined" );
    ok( $wiki->search_obj, "...and search defined" );
    ok( $wiki->formatter,  "...and formatter defined" );
}
