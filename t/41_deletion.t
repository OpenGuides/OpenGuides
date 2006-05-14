use strict;
use Wiki::Toolkit::Formatter::UseMod;
use OpenGuides::Template;
use OpenGuides::Test;
use Test::MockObject;
use Test::More tests => 3;

my $config = OpenGuides::Test->make_basic_config;
$config->site_name( "Test Site" );
$config->script_url( "/" );

# White box testing - we know that OpenGuides::Template only actually uses
# the node_name_to_node_param method of the formatter component of the wiki
# object passed in, and I CBA to faff about with picking out the test DB
# info to make a proper wiki object here.
my $fake_wiki = Test::MockObject->new;
$fake_wiki->mock("formatter",
                 sub { return Wiki::Toolkit::Formatter::UseMod->new( munge_urls => 1 ); } );

my $output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "node.tt",
);
unlike( $output, qr/action=delete/,
        "doesn't offer page deletion link by default" );
$config->enable_page_deletion( "y" );
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "node.tt",
);
like( $output, qr/action=delete/,
      "...but does when enable_page_deletion is set to 'y'" );
$config->enable_page_deletion( 1 );
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "node.tt",
);
like( $output, qr/action=delete/,
      "...and when enable_page_deletion is set to '1'" );
