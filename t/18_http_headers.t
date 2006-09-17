use strict;
use Cwd;
use CGI::Cookie;
use Wiki::Toolkit::Formatter::UseMod;
use OpenGuides::Config;
use OpenGuides::Template;
use Test::MockObject;
use Test::More tests => 5;

my $config = OpenGuides::Config->new(
       vars => {
                 template_path         => cwd . '/t/templates',
                 site_name             => 'Wiki::Toolkit Test Site',
                 script_url            => 'http://wiki.example.com/',
                 script_name           => 'mywiki.cgi',
                 default_country       => 'United Kingdom',
                 default_city          => 'London',
                 contact_email         => 'wiki@example.com',
                 stylesheet_url        => 'http://wiki.example.com/styles.css',
                 home_name             => 'Home Page',
                 formatting_rules_node => 'Rules',
                 formatting_rules_link => '',
               }
);

# White box testing - we know that OpenGuides::Template only actually uses
# the node_name_to_node_param method of the formatter component of the wiki
# object passed in, and I CBA to make a proper wiki object here.
my $fake_wiki = Test::MockObject->new;
$fake_wiki->mock("formatter",
                 sub { return Wiki::Toolkit::Formatter::UseMod->new( munge_urls => 1 ); } );

eval {
    OpenGuides::Template->output( wiki     => $fake_wiki,
                                  config   => $config,
                                  template => "15_test.tt" );
};
is( $@, "", "is happy doing output" );

my $output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt"
);
like( $output, qr/^Content-Type: text\/html/,
      "Content-Type header included and defaults to text/html" );

# Now supply a http charset
$config->{http_charset} = "UTF-8";

$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    template => "15_test.tt"
);
like( $output, qr/^Content-Type: text\/html; charset=UTF-8/,
      "Content-Type header included charset" );

# Suppy charset and content type
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    content_type => "text/xml",
    template => "15_test.tt"
);
like( $output, qr/^Content-Type: text\/xml; charset=UTF-8/,
      "Content-Type header included charset" );

# Content type but no charset
$config->{http_charset} = "";
$output = OpenGuides::Template->output(
    wiki     => $fake_wiki,
    config   => $config,
    content_type => "text/xml",
    template => "15_test.tt"
);
like( $output, qr/^Content-Type: text\/xml/,
      "Content-Type header didn't include charset" );
