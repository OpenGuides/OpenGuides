use strict;
use Config::Tiny;
use Cwd;
use CGI::Cookie;
use CGI::Wiki::Formatter::UseMod;
use OpenGuides::Template;
use Test::MockObject;
use Test::More tests => 27;

my $config = Config::Tiny->new;
$config->{_} = {
                 template_path         => cwd . '/t/templates',
                 site_name             => 'CGI::Wiki Test Site',
                 script_url            => 'http://wiki.example.com/',
                 script_name           => 'mywiki.cgi',
                 default_country       => 'United Kingdom',
                 default_city          => 'London',
                 contact_email         => 'wiki@example.com',
                 stylesheet_url        => 'http://wiki.example.com/styles.css',
                 home_name             => 'Home Page',
                 formatting_rules_node => 'Rules',
               };

# White box testing - we know that OpenGuides::Template only actually uses
# the node_name_to_node_param method of the formatter component of the wiki
# object passed in, and I CBA to make a proper wiki object here.
my $fake_wiki = Test::MockObject->new;
$fake_wiki->mock("formatter",
                 sub { return CGI::Wiki::Formatter::UseMod->new( munge_urls => 1 ); } );

eval { OpenGuides::Template->output( wiki   => $fake_wiki,
                                     config => $config ); };
ok( $@, "->output croaks if no template file supplied" );

eval {
    OpenGuides::Template->output( wiki     => $fake_wiki,
                                  config   => $config,
                                  template => "15_test.tt" );
};
is( $@, "", "...but not if one is" );

my $output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt",
    vars     => { foo => "bar" }
);
like( $output, qr/^Content-Type: text\/html/,
      "Content-Type header included and defaults to text/html" );
like( $output, qr/FOO: bar/, "variables substituted" );

$output = OpenGuides::Template->output(
    wiki         => $fake_wiki,
    config       => $config,
    template     => "15_test.tt",
    content_type => ""
);
unlike( $output, qr/^Content-Type: text\/html/,
        "Content-Type header omitted if content_type arg explicitly blank" );

$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_idonotexist.tt"
);
like( $output, qr/Failed to process template/, "fails nice on TT error" );

# Test TT variables are auto-set from config.
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
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
like( $output, qr/HOME LINK: http:\/\/wiki.example.com\/mywiki.cgi/, "home_link var set" );
like( $output, qr/HOME NAME: Home Page/, "home_name var set" );
like( $output,
      qr/FORMATTING RULES LINK: http:\/\/wiki.example.com\/mywiki.cgi\?Rules/,
      "formatting_rules_link var set" );

# Test openguides_version TT variable.
like( $output, qr/OPENGUIDES VERSION: 0\.\d\d/,
      "openguides_version set" );

# Test TT variables auto-set from node name.
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
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt",
    cookies  => $cookie
);
like( $output, qr/Set-Cookie: $cookie/, "cookie in header" );

# Test that home_link is set correctly when script_name is blank.
$config->{_} = {
                 template_path         => cwd . '/t/templates',
                 site_name             => 'CGI::Wiki Test Site',
                 script_url            => 'http://wiki.example.com/',
                 script_name           => '',
               };
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt"
);
like( $output, qr/HOME LINK: http:\/\/wiki.example.com/,
      "home_link var set OK when script_name blank" );

# Test that full_cgi_url comes out right if the trailing '/' is
# missing from script_url in the config file.
$config->{_} = {
                 template_path         => cwd . '/t/templates',
                 site_name             => 'CGI::Wiki Test Site',
                 script_url            => 'http://wiki.example.com',
                 script_name           => 'wiki.cgi',
               };
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt"
);
like( $output, qr/FULL CGI URL: http:\/\/wiki.example.com\/wiki.cgi/,
      "full_cgi_url OK when trailing '/' missed off script_url" );

# Test that TT vars are picked up from user cookie prefs.
$cookie = OpenGuides::CGI->make_prefs_cookie(
    config                 => $config,
    omit_formatting_link   => 1,
);
$ENV{HTTP_COOKIE} = $cookie;
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt"
);
like( $output, qr/FORMATTING RULES LINK: /,
      "formatting_rules_link TT var blank as set in cookie" );

# Test that explicitly supplied vars override vars in cookie.
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt",
    vars     => { omit_formatting_link => "fish" },
);
like( $output, qr/OMIT FORMATTING LINK: fish/,
      "explicitly supplied TT vars override cookie ones" );

# Test that enable_page_deletion is set correctly in various circumstances.
$config = Config::Tiny->new;
$config->{_}->{template_path} = cwd . "/t/templates";
$config->{_}->{site_name} = "Test Site";
$config->{_}->{script_url} = "/";
$config->{_}->{script_name} = "";

$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt",
);
like( $output, qr/ENABLE PAGE DELETION: 0/,
      "enable_page_deletion var set correctly when not specified in conf" );

$config->{_}->{enable_page_deletion} = "n";
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt",
);
like( $output, qr/ENABLE PAGE DELETION: 0/,
      "enable_page_deletion var set correctly when set to 'n' in conf" );

$config->{_}->{enable_page_deletion} = "y";
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt",
);
like( $output, qr/ENABLE PAGE DELETION: 1/,
      "enable_page_deletion var set correctly when set to 'y' in conf" );

$config->{_}->{enable_page_deletion} = 0;
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt",
);
like( $output, qr/ENABLE PAGE DELETION: 0/,
      "enable_page_deletion var set correctly when set to '0' in conf" );

$config->{_}->{enable_page_deletion} = 1;
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt",
);
like( $output, qr/ENABLE PAGE DELETION: 1/,
      "enable_page_deletion var set correctly when set to '1' in conf" );
