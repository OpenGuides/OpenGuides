#!/usr/bin/perl -w

use strict;
use CGI;
use Config::Tiny;
use OpenGuides::CGI;
use OpenGuides::Utils;
use OpenGuides::Template;

my $config = Config::Tiny->read("wiki.conf");
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
    my $username  = $cgi->param("username") || "";
    my $gc_link   = $cgi->param('include_geocache_link') || 0;
    my $pre_above = $cgi->param('preview_above_edit_box') || 0;
    my $cookie = OpenGuides::CGI->make_prefs_cookie(
        config => $config,
        username => $username,
        include_geocache_link => $gc_link,
	preview_above_edit_box => $pre_above
    );
    print OpenGuides::Template->output(
        wiki     => $wiki,
        config   => $config,
        template => "preferences.tt",
        cookies  => $cookie,
	vars     => { not_editable           => 1,
                      username               => $username,
                      include_geocache_link  => $gc_link,
                      preview_above_edit_box => $pre_above
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
