use strict;
use Config::Tiny;
use OpenGuides::Utils;
use Test::More tests => 2;

my $config = Config::Tiny->read( "wiki.conf" )
    or die "Couldn't read wiki.conf";
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
