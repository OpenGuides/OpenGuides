#!/usr/bin/perl -w
use strict;

use CGI;
use Config::Tiny;
use OpenGuides::Template;
use OpenGuides::Utils;
use URI::Escape;

my @badchars = qw( ! " $ % ^ & @ ~ ? { } [ ] );
push @badchars, '#'; # Avoid warning about possible comments in qw()

my $q = CGI->new;
my $config = Config::Tiny->read('wiki.conf');
my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

my $pagename = $q->param("pagename") || "";
$pagename =~ s/^\s*//;
$pagename =~ s/\s*$//;

my $action = $q->param("action") || "";

if ( $action eq "makepage" ) {
    make_page();
} else {
    show_form();
}

exit 0;

sub show_form {
    print OpenGuides::Template->output( wiki     => $wiki,
					config   => $config,
					template => "newpage.tt",
					vars     => {
					    not_editable     => 1,
				       	    disallowed_chars => \@badchars,
                                            pagename         => $pagename }
    );
}

sub make_page {
    # Ensure pagename not blank.
    unless ( $pagename ) {
        print OpenGuides::Template->output(
            wiki     => $wiki,
	    config   => $config,
	    template => "error.tt",
	    vars     => { not_editable => 1,
			  message      => "Please enter a page name!",
			  return_url   => "newpage.cgi" } );
        exit 0;
    }

    # Ensure pagename valid.
    my %badhash = map { $_ => 1 } @badchars;
    my @naughty;
    foreach my $i ( 0 .. (length $pagename) - 1 ) {
        my $char = substr( $pagename, $i, 1 );
        push @naughty, $char if $badhash{$char};
    }
    if ( scalar @naughty ) {
        my $message = "Page name $pagename contains disallowed characters";
        print OpenGuides::Template->output(
            wiki     => $wiki,
	    config   => $config,
	    template => "error.tt",
	    vars     => {
                pagename     => $pagename,
                not_editable => 1,
		message      => $message,
		return_url   => "newpage.cgi?pagename=" . uri_escape($pagename)
            }
        );
        exit 0;
    }

    # Hurrah, we're OK.
    my $node_param = $wiki->formatter->node_name_to_node_param($pagename);
    print "Location: $config->{_}->{script_name}?action=edit;id=$node_param\n\n";
    exit 0;
}


