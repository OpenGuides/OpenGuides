use strict;
use OpenGuides;
use OpenGuides::Template;
use OpenGuides::Test;
use Test::More tests => 3;

my $config = OpenGuides::Test->make_basic_config;
$config->site_name( "Test Site" );
$config->script_url( "/" );

my $guide = OpenGuides->new( config => $config );
my $wiki = $guide->wiki;

my $output = OpenGuides::Template->output(
    wiki     => $wiki,
    config   => $config,
    template => "node.tt",
);
unlike( $output, qr/action=delete/,
        "doesn't offer page deletion link by default" );
$config->enable_page_deletion( "y" );
$output = OpenGuides::Template->output(
    wiki     => $wiki,
    config   => $config,
    template => "node.tt",
);
like( $output, qr/action=delete/,
      "...but does when enable_page_deletion is set to 'y'" );
$config->enable_page_deletion( 1 );
$output = OpenGuides::Template->output(
    wiki     => $wiki,
    config   => $config,
    template => "node.tt",
);
like( $output, qr/action=delete/,
      "...and when enable_page_deletion is set to '1'" );
