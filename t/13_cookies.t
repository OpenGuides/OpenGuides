use strict;
use Config::Tiny;
use Test::More tests => 14;

use_ok( "OpenGuides::CGI" );

eval { OpenGuides::CGI->make_prefs_cookie; };
ok( $@, "->make_prefs_cookie dies if no config object supplied" );

eval { OpenGuides::CGI->make_prefs_cookie( config => "foo" ); };
ok( $@, "...or if config isn't a Config::Tiny" );

my $config = Config::Tiny->read( "t/21_wiki.conf" );

eval { OpenGuides::CGI->make_prefs_cookie( config => $config ); };
is( $@, "", "...but not if it is" );

my $cookie = OpenGuides::CGI->make_prefs_cookie(
    config                 => $config,
    username               => "Kake",
    include_geocache_link  => 1,
    preview_above_edit_box => 1,
    latlong_traditional    => 1
);
isa_ok( $cookie, "CGI::Cookie", "->make_prefs_cookie returns a cookie" );

$ENV{HTTP_COOKIE} = $cookie;

eval { OpenGuides::CGI->get_prefs_from_cookie; };
ok( $@, "->get_prefs_from_cookie dies if no config object supplied" );

eval { OpenGuides::CGI->get_prefs_from_cookie( config => "foo" ); };
ok( $@, "...or if config isn't a Config::Tiny" );

eval { OpenGuides::CGI->get_prefs_from_cookie( config => $config ); };
is( $@, "", "...but not if it is" );

my %prefs = OpenGuides::CGI->get_prefs_from_cookie( config => $config );
is( $prefs{username}, "Kake",
    "get_prefs_from_cookie can find username" );
is( $prefs{include_geocache_link}, 1, "...and geocache prefs" );
is( $prefs{preview_above_edit_box}, 1, "...and preview prefs" );
is( $prefs{latlong_traditional}, 1, "...and latlong prefs" );

# Check that cookie parsing fails nicely if no cookie set.
delete $ENV{HTTP_COOKIE};
%prefs = eval { OpenGuides::CGI->get_prefs_from_cookie( config => $config ); };
is( $@, "", "->get_prefs_from_cookie doesn't die if no cookie set" );
is( keys %prefs, 4, "...and returns four default values" );

