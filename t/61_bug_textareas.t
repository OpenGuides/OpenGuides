use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use Cwd;
use OpenGuides::Template;
use OpenGuides::Utils;
use Test::More tests => 1;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 1
      unless $have_sqlite;

    CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = Config::Tiny->new;
    $config->{_} = {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_url         => "http://wiki.example.com/",
                     script_name        => "mywiki.cgi",
                     site_name          => "CGI::Wiki Test Site",
                     template_path      => cwd . "/templates",
                   };

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


