#!/usr/bin/perl

use warnings;
use strict;

use CGI;
use OpenGuides::Config;
use OpenGuides::CGI;
use OpenGuides::Utils;
use OpenGuides::Template;

my $config_file = $ENV{OPENGUIDES_CONFIG_FILE} || "wiki.conf";
my $config = OpenGuides::Config->new( file => $config_file );
my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );
my $cgi = CGI->new();
my $action = $cgi->param('action') || '';

if ( $action eq "set_preferences" ) {
    set_preferences();
} else {
    show_form();
}

exit 0;

sub set_preferences {
    my $username     = $cgi->param("username")                   || "";
    my $gc_link      = $cgi->param("include_geocache_link")      || 0;
    my $pre_above    = $cgi->param("preview_above_edit_box")     || 0;
    my $latlong_trad = $cgi->param("latlong_traditional")        || 0;
    my $omit_hlplnks = $cgi->param("omit_help_links")            || 0;
    my $rc_minor_eds = $cgi->param("show_minor_edits_in_rc")     || 0;
    my $edit_type    = $cgi->param("default_edit_type")          || "normal";
    my $expires      = $cgi->param("cookie_expires")             || "month";
    my $track_rc     = $cgi->param("track_recent_changes_views") || 0;
    my $gmaps        = $cgi->param("display_google_maps")        || 0;
    my $prefs_cookie = OpenGuides::CGI->make_prefs_cookie(
        config => $config,
        username => $username,
        include_geocache_link  => $gc_link,
	preview_above_edit_box => $pre_above,
        latlong_traditional    => $latlong_trad,
        omit_help_links        => $omit_hlplnks,
        show_minor_edits_in_rc => $rc_minor_eds,
        default_edit_type      => $edit_type,
        cookie_expires         => $expires,
        track_recent_changes_views => $track_rc,
        display_google_maps    => $gmaps
    );
    my @cookies = ( $prefs_cookie );
    # If they've asked not to have their recent changes visits tracked,
    # clear any existing recentchanges cookie.
    if ( ! $track_rc ) {
        my $rc_cookie = OpenGuides::CGI->make_recent_changes_cookie(
            config       => $config,
            clear_cookie => 1,
        );
        push @cookies, $rc_cookie;
    }
    print OpenGuides::Template->output(
        wiki     => $wiki,
        config   => $config,
        template => "preferences.tt",
        cookies  => \@cookies,
	vars     => {
                      not_editable               => 1,
                      username                   => $username,
                      include_geocache_link      => $gc_link,
                      preview_above_edit_box     => $pre_above,
                      latlong_traditional        => $latlong_trad,
                      omit_help_links            => $omit_hlplnks,
                      show_minor_edits_in_rc     => $rc_minor_eds,
                      default_edit_type          => $edit_type,
                      cookie_expires             => $expires,
                      track_recent_changes_views => $track_rc,
                      display_google_maps        => $gmaps
                    }
    );
}

sub show_form {
    # Get defaults for form fields from cookies.
    my %prefs = OpenGuides::CGI->get_prefs_from_cookie( config => $config );

    print OpenGuides::Template->output(
        wiki     => $wiki,
        config   => $config,
        template => "preferences.tt",
	vars     => { %prefs,
                      not_editable => 1,
                      show_form    => 1
                    }
    );
}
