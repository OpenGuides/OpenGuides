use strict;
use Config::Tiny;
use OpenGuides::Utils;
use Test::More tests => 7;

eval { my $wiki = OpenGuides::Utils->make_wiki_object; };
ok( $@, "->make_wiki_object croaks if no config param supplied" );

eval { my $wiki = OpenGuides::Utils->make_wiki_object( config => "foo" ); };
ok( $@, "...and if config param isn't a Config::Tiny object" );

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 5
      unless $have_sqlite;

    my $config = Config::Tiny->new;
    $config->{_} = {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_url         => "",
                     script_name        => "",
                   };

    my $wiki = eval {
        OpenGuides::Utils->make_wiki_object( config => $config );
    };
    is( $@, "",
        "...but not if a Config::Tiny object with suitable data is supplied" );
    isa_ok( $wiki, "CGI::Wiki" );

    ok( $wiki->store,      "...and store defined" );
    ok( $wiki->search_obj, "...and search defined" );
    ok( $wiki->formatter,  "...and formatter defined" );
}
