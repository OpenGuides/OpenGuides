#!/usr/bin/perl

use warnings;
use strict;
use sigtrap die => 'normal-signals';
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

sub set_preferences {
    my %prefs = OpenGuides::CGI->get_prefs_from_hash( $cgi->Vars );
    my $prefs_cookie = OpenGuides::CGI->make_prefs_cookie(
        config => $config,
        %prefs,
    );
    my @cookies = ( $prefs_cookie );
    # If they've asked not to have their recent changes visits tracked,
    # clear any existing recentchanges cookie.
    if ( ! $prefs{track_recent_changes_views} ) {
        my $rc_cookie = OpenGuides::CGI->make_recent_changes_cookie(
            config       => $config,
            clear_cookie => 1,
        );
        push @cookies, $rc_cookie;
    }
    # We have to send the username to OpenGuides::Template because they might
    # have changed it, in which case it won't be in the cookie yet.
    print OpenGuides::Template->output(
        wiki     => $wiki,
        config   => $config,
        template => "preferences.tt",
        cookies  => \@cookies,
        vars     => {
                      not_editable => 1,
                      not_deletable => 1,
                      username => $prefs{username},
                    }
    );
}

sub show_form {
    print OpenGuides::Template->output(
        wiki     => $wiki,
        config   => $config,
        template => "preferences.tt",
	vars     => { 
                      not_editable  => 1,
                      show_form     => 1,
                      not_deletable => 1,
                    }
    );
}
