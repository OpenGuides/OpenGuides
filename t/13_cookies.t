use strict;
use Config::Tiny;
use OpenGuides::CGI;
use Time::Piece;
use Time::Seconds;
use Test::More tests => 19;

eval { OpenGuides::CGI->make_prefs_cookie; };
ok( $@, "->make_prefs_cookie dies if no config object supplied" );

eval { OpenGuides::CGI->make_prefs_cookie( config => "foo" ); };
ok( $@, "...or if config isn't a Config::Tiny" );

my $config = Config::Tiny->new;
$config->{_} = {
                 site_name => "Test Site",
               };

eval { OpenGuides::CGI->make_prefs_cookie( config => $config ); };
is( $@, "", "...but not if it is" );

my $cookie = OpenGuides::CGI->make_prefs_cookie(
    config                     => $config,
    username                   => "Kake",
    include_geocache_link      => 1,
    preview_above_edit_box     => 1,
    latlong_traditional        => 1,
    omit_help_links            => 1,
    show_minor_edits_in_rc     => 1,
    default_edit_type          => "tidying",
    cookie_expires             => "never",
    track_recent_changes_views => 1,
);
isa_ok( $cookie, "CGI::Cookie", "->make_prefs_cookie returns a cookie" );

my $expiry_string = $cookie->expires;
# Hack off the timezone bit since strptime can't parse it portably.
# Timezones taken from RFC 822.
$expiry_string =~ s/ (UT|GMT|EST|EDT|CST|CDT|MST|MDT|PST|PDT|1[A-IK-Z]|\+\d\d\d\d|-\d\d\d\d)$//;
print "# (String hacked to $expiry_string)\n";
my $expiry = Time::Piece->strptime( $expiry_string, "%a, %d-%b-%Y %T");
print "# Expires: " . $cookie->expires . ", ie $expiry\n";
my $now = localtime;
print "# cookie should still be valid in a year, ie " . ($now + ONE_YEAR) . "\n";
ok( $expiry - ( $now + ONE_YEAR ) > 0, "cookie expiry date correct" );

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
is( $prefs{omit_help_links}, 1, "...and help link prefs" );
is( $prefs{show_minor_edits_in_rc}, 1, "...and minor edits prefs" );
is( $prefs{default_edit_type}, "tidying", "...and default edit prefs" );
is( $prefs{cookie_expires}, "never", "...and requested cookie expiry" );
ok( $prefs{track_recent_changes_views}, "...and recent changes tracking" );

# Check that cookie parsing fails nicely if no cookie set.
delete $ENV{HTTP_COOKIE};
%prefs = eval { OpenGuides::CGI->get_prefs_from_cookie( config => $config ); };
is( $@, "", "->get_prefs_from_cookie doesn't die if no cookie set" );
is( keys %prefs, 9, "...and returns nine default values" );
