use strict;
use Config::Tiny;
use OpenGuides::Utils;
use Test::More tests => 2;

eval { require DBD::SQLite; };
my $have_sqlite = $@ ? 0 : 1;

SKIP: {
    skip "DBD::SQLite not installed - no database to test with", 2
      unless $have_sqlite;

    my $config = Config::Tiny->new;
    $config->{_} = {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_url         => "",
                     script_name        => "",
                   };

    my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );
    my $formatter = $wiki->formatter;

    my $wikitext = <<WIKI;

\@INDEX_LINK [[Category Foo]]

\@INDEX_LINK [[Category Bar|Bars]]

WIKI

    my $html = $formatter->format($wikitext);
    like( $html, qr/View all pages in Category Foo/,
          "\@INDEX_LINK has right default link text" );
    like( $html, qr/>Bars<\/a>/, "...and can be overridden" );
}
