use strict;
use Config::Tiny;
use Cwd;
use CGI::Wiki::Formatter::UseMod;
use OpenGuides::Template;
use Test::MockObject;
use Test::More tests => 3;

my $config = Config::Tiny->new;
$config->{_}->{template_path} = cwd . "/templates";
$config->{_}->{site_name} = "Test Site";
$config->{_}->{script_url} = "/";
$config->{_}->{script_name} = "";

# White box testing - we know that OpenGuides::Template only actually uses
# the node_name_to_node_param method of the formatter component of the wiki
# object passed in, and I CBA to faff about with picking out the test DB
# info to make a proper wiki object here.
my $fake_wiki = Test::MockObject->new;
$fake_wiki->mock("formatter",
                 sub { return CGI::Wiki::Formatter::UseMod->new( munge_urls => 1 ); } );

my $output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "node.tt",
);
unlike( $output, qr/action=delete/,
        "doesn't offer page deletion link by default" );
$config->{_}->{enable_page_deletion} = "y";
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "node.tt",
);
like( $output, qr/action=delete/,
      "...but does when enable_page_deletion is set to 'y'" );
$config->{_}->{enable_page_deletion} = "1";
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "node.tt",
);
like( $output, qr/action=delete/,
      "...and when enable_page_deletion is set to '1'" );
