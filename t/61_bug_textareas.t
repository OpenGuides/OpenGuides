use Wiki::Toolkit::Setup::SQLite;
use OpenGuides::Template;
use OpenGuides::Test;
use OpenGuides::Utils;
use Test::More tests => 1;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 1
      unless $have_sqlite;

    Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = OpenGuides::Test->make_basic_config;
    my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

    my $out = OpenGuides::Template->output(
        wiki     => $wiki,
        config   => $config,
        template => "edit_form.tt",
        vars     => {
                      locales  => [
                                    { name => "Barville" },
                                    { name => "Fooville" },
                                  ],
                    },
    );

    like( $out, qr/Barville\nFooville/,
         "locales properly separated in textarea" );
}


