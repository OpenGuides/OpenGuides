use strict;
use Test::More tests => 17;
use Config::Tiny;
use Cwd;
use CGI::Cookie;
use CGI::Wiki::Formatter::UseMod;
use Test::MockObject;

use_ok( "OpenGuides::Template" );

my $config = Config::Tiny->read( "t/21_wiki.conf" );
$config->{_}->{template_path} = cwd . "/t/templates";

eval { OpenGuides::Template->output( config => $config ); };
ok( $@, "->output croaks if no template file supplied" );

eval {
    OpenGuides::Template->output( config   => $config,
                                  template => "15_test.tt" );
};
is( $@, "", "...but not if one is" );

my $output = OpenGuides::Template->output(
    config   => $config,
    template => "15_test.tt",
    vars     => { foo => "bar" }
);
like( $output, qr/^Content-Type: text\/html/,
      "Content-Type header included and defaults to text/html" );
like( $output, qr/FOO: bar/, "variables substituted" );

$output = OpenGuides::Template->output(
    config       => $config,
    template     => "15_test.tt",
    content_type => ""
);
unlike( $output, qr/^Content-Type: text\/html/,
        "Content-Type header omitted if content_type arg explicitly blank" );

$output = OpenGuides::Template->output(
    config => $config,
    template => "15_idonotexist.tt"
);
like( $output, qr/Failed to process template/, "fails nice on TT error" );

# Test TT variables are auto-set from config.

$output = OpenGuides::Template->output(
    config   => $config,
    template => "15_test.tt"
);

like( $output, qr/SITE NAME: CGI::Wiki Test Site/, "site_name var set" );
like( $output, qr/CGI URL: mywiki.cgi/, "cgi_url var set" );
like( $output, qr/FULL CGI URL: http:\/\/wiki.example.com\/mywiki.cgi/,
      "full_cgi_url var set" );
like( $output, qr/CONTACT EMAIL: wiki\@example.com/, "contact_email var set" );
like( $output, qr/STYLESHEET: http:\/\/wiki.example.com\/styles.css/,
      "stylesheet var set" );
like( $output, qr/HOME LINK: mywiki.cgi/, "home_link var set" );
like( $output, qr/HOME NAME: Home Page/, "home_name var set" );

# Test TT variables auto-set from node name.

# White box testing - we know that OpenGuides::Template only actually uses
# the node_name_to_node_param method of the formatter component of the wiki
# object passed in, and I CBA to faff about with picking out the test DB
# info to make a proper wiki object here.
my $fake_wiki = Test::MockObject->new;
$fake_wiki->mock("formatter",
                 sub { return CGI::Wiki::Formatter::UseMod->new; } );

$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    node     => "Test Node",
    template => "15_test.tt"
);

like( $output, qr/NODE NAME: Test Node/, "node_name var set" );
like( $output, qr/NODE PARAM: Test_Node/, "node_param var set" );

# Test that cookies go in.
my $cookie = CGI::Cookie->new( -name => "x", -value => "y" );
$output = OpenGuides::Template->output(
    config   => $config,
    template => "15_test.tt",
    cookies  => $cookie
);
like( $output, qr/Set-Cookie: $cookie/, "cookie in header" );
