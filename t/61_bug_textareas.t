use strict;
use Config::Tiny;
use Cwd;
use OpenGuides::Template;
use OpenGuides::Utils;
use Test::More tests => 1;

#####
##### IMPORTANT: Treat this wiki object as read-only or we may eat live data.
#####

my $config = Config::Tiny->read( "wiki.conf" )
    or die "Couldn't read wiki.conf";
my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );
$config->{_}{template_path} = cwd . "/templates";

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

like( $out, qr/Barville\nFooville/, "locales properly separated in textarea" );


