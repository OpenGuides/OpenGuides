#!/usr/local/bin/perl

use strict;
use warnings;

use vars qw( $VERSION );
$VERSION = '0.33_05';

use CGI qw/:standard/;
use CGI::Carp qw(croak);
use CGI::Wiki;
use Config::Tiny;
use Geography::NationalGrid;
use Geography::NationalGrid::GB;
use OpenGuides;
use OpenGuides::CGI;
use OpenGuides::RDF;
use OpenGuides::Utils;
use OpenGuides::Template;
use Time::Piece;
use URI::Escape;

# config vars
my $config = Config::Tiny->read('wiki.conf');

# Read in configuration values from config file.
my $script_name = $config->{_}->{script_name};
my $script_url  = $config->{_}->{script_url};

# Ensure that script_url ends in a '/' - this is done in Build.PL but
# we need to allow for people editing the config file by hand later.
$script_url .= "/" unless $script_url =~ /\/$/;

my ($guide, $wiki, $formatter, $q);
eval {
    $guide = OpenGuides->new( config => $config );
    $wiki = $guide->wiki;
    $formatter = $wiki->formatter;

    # Get CGI object, find out what to do.
    $q = CGI->new;

    # Note $q->param('keywords') gives you the entire param string.
    # We need this to do URLs like foo.com/wiki.cgi?This_Page
    my $node = $q->param('id') || $q->param('title') || $q->param('keywords') || "";
    $node = $formatter->node_param_to_node_name( $node );

    my $action = $q->param('action') || 'display';
    my $commit = $q->param('Save') || 0;
    my $preview = $q->param('preview') || 0;
    my $search_terms = $q->param('terms') || $q->param('search') || '';
    my $username = $q->param('username') || '';
    my $format = $q->param('format') || '';

    # Alternative method of calling search, supported by usemod.
    $action = 'search' if $q->param("search");

    if ($commit) {
        commit_node($node);
    } elsif ($preview) {
        preview_node($node);
    } elsif ($action eq 'edit') {
        edit_node($node);
    } elsif ($action eq 'search') {
        do_search($search_terms);
    } elsif ($action eq 'show_backlinks') {
        show_backlinks($node);
    } elsif ($action eq 'show_wanted_pages') {
        show_wanted_pages();
    } elsif ($action eq 'index') {
        $guide->show_index(
                            type   => $q->param("index_type") || "Full",
                            value  => $q->param("index_value") || "",
                            format => $format,
                          );
    } elsif ($action eq 'random') {
        my @nodes = $wiki->list_all_nodes();
        $node = $nodes[int(rand(scalar(@nodes) + 1)) + 1];
        print $guide->redirect_to_node($node);
        exit 0;
    } elsif ($action eq 'find_within_distance') {
        $guide->find_within_distance(
                                      id => $node,
                                      metres => $q->param("distance_in_metres")
                                    );
    } elsif ( $action eq 'delete'
              and ( lc($config->{_}->{enable_page_deletion}) eq "y"
                    or $config->{_}->{enable_page_deletion} eq "1" )
            ) {
        delete_node($node);
    } elsif ($action eq 'userstats') {
        show_userstats( $username );
    } elsif ($action eq 'list_all_versions') {
        $guide->list_all_versions( id => $node );
    } elsif ($action eq 'rss') {
        my $feed = $q->param("feed");
        if ( !defined $feed or $feed eq "recent_changes" ) {
            my $items = $q->param("items") || "";
            my $days  = $q->param("days")  || "";
            emit_recent_changes_rss( items => $items, days => $days);
        } elsif ( $feed eq "chef_dan" ) {
            display_node_rdf( node => $node );
        } else {
            croak "Unknown RSS feed type '$feed'";
        }
    } else { # Default is to display a node.
        if ( $format and $format eq "rdf" ) {
            display_node_rdf( node => $node );
        } else {
            my $version = $q->param("version");
	    my $other_ver = $q->param("diffversion");
            if ( $other_ver ) {
                $guide->display_diffs(
                                       id            => $node,
                                       version       => $version,
                                       other_version => $other_ver,
                                     );
            } else {
                $guide->display_node( id => $node, version => $version );
	    }
        }
    }
};

if ($@) {
    my $error = $@;
    warn $error;
    print $q->header;
    my $contact_email = $config->{_}->{contact_email};
    print qq(<html><head><title>ERROR</title></head><body>
             <p>Sorry!  Something went wrong.  Please contact the
             Wiki administrator at
             <a href="mailto:$contact_email">$contact_email</a> and quote
             the following error message:</p><blockquote>)
      . $q->escapeHTML($error)
      . qq(</blockquote><p><a href="$script_name">Return to the Wiki home page</a>
           </body></html>);
}
exit 0;

############################ subroutines ###################################

sub show_userstats {
    my $username = shift;
    croak "No username supplied to show_userstats" unless $username;
    my @nodes = $wiki->list_recent_changes(
        last_n_changes => 5,
	metadata_is    => { username => $username }
    );
    @nodes = map { {name          => $q->escapeHTML($_->{name}),
		    last_modified => $q->escapeHTML($_->{last_modified}),
		    comment       => $q->escapeHTML($_->{metadata}{comment}[0]),
		    url           => "$script_name?"
          . $q->escape($formatter->node_name_to_node_param($_->{name})) }
                       } @nodes;
    my %tt_vars = ( last_five_nodes => \@nodes,
		    username        => $username,
		    username_param  => $wiki->formatter->node_name_to_node_param($username),
                  );
    process_template("userstats.tt", "", \%tt_vars);
}

sub preview_node {
    my $node = shift;
    my $content  = $q->param('content');
    $content     =~ s/\r\n/\n/gs;
    my $checksum = $q->param('checksum');

    my %tt_metadata_vars = OpenGuides::Template->extract_metadata_vars(
                                                   wiki    => $wiki,
						   config  => $config,
						   cgi_obj => $q );
    foreach my $var ( qw( username comment edit_type ) ) {
        $tt_metadata_vars{$var} = $q->escapeHTML($q->param($var));
    }

    if ($wiki->verify_checksum($node, $checksum)) {
        my %tt_vars = (
            %tt_metadata_vars,
            content                => $q->escapeHTML($content),
            preview_html           => $wiki->format($content),
            preview_above_edit_box => get_cookie( "preview_above_edit_box" ),
            checksum               => $q->escapeHTML($checksum)
	);
        process_template("edit_form.tt", $node, \%tt_vars);
    } else {
        my %node_data = $wiki->retrieve_node($node);
        my %tt_vars = ( checksum       => $node_data{checksum},
                        new_content    => $content,
                        stored_content => $node_data{content} );
        foreach my $mdvar ( keys %tt_metadata_vars ) {
            if ($mdvar eq "locales") {
                $tt_vars{"stored_$mdvar"} = $node_data{metadata}{locale};
                $tt_vars{"new_$mdvar"}    = $tt_metadata_vars{locale};
            } elsif ($mdvar eq "categories") {
                $tt_vars{"stored_$mdvar"} = $node_data{metadata}{category};
                $tt_vars{"new_$mdvar"}    = $tt_metadata_vars{category};
            } elsif ($mdvar eq "username" or $mdvar eq "comment"
                      or $mdvar eq "edit_type" ) {
                $tt_vars{$mdvar} = $tt_metadata_vars{$mdvar};
            } else {
                $tt_vars{"stored_$mdvar"} = $node_data{metadata}{$mdvar}[0];
                $tt_vars{"new_$mdvar"}    = $tt_metadata_vars{$mdvar};
            }
        }
        process_template("edit_conflict.tt", $node, \%tt_vars);
    }
}

sub edit_node {
    my $node = shift;
    my %node_data = $wiki->retrieve_node($node);
    my ($content, $checksum) = @node_data{ qw( content checksum ) };
    my $username = get_cookie( "username" );

    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
                             wiki     => $wiki,
                             config   => $config,
			     metadata => $node_data{metadata} );

    my %tt_vars = ( content    => $q->escapeHTML($content),
                    checksum   => $q->escapeHTML($checksum),
                    %metadata_vars,
		    username   => $username
    );

    process_template("edit_form.tt", $node, \%tt_vars);
}

sub delete_node {
    my $node = shift;

    my %tt_vars = (
                    not_editable   => 1,
                    page_deletable => 0,
                  );

    my $password = $q->param('password');

    if ($password) {
        if ($password ne $config->{_}->{admin_pass}) {
            process_template("delete_password_wrong.tt", $node, \%tt_vars); 
        } else {
            $wiki->delete_node($node);
            process_template("delete_done.tt", $node, \%tt_vars);
        }
    } else {
        process_template("delete_confirm.tt", $node, \%tt_vars);
    }
}

sub get_cookie {
    my $pref_name = shift or return "";
    my %cookie_data = OpenGuides::CGI->get_prefs_from_cookie(config=>$config);
    return $cookie_data{$pref_name};
}

sub emit_recent_changes_rss {
    my %args = @_;
    my $rdf_writer = OpenGuides::RDF->new( wiki      => $wiki,
					   config => $config );
    print "Content-type: text/plain\n\n";
    print $rdf_writer->make_recentchanges_rss( %args );
    exit 0;
}

sub display_node_rdf {
    my %args = @_;
    my $rdf_writer = OpenGuides::RDF->new( wiki      => $wiki,
					   config => $config );
    print "Content-type: text/plain\n\n";
    print $rdf_writer->emit_rdfxml( node => $args{node} );
    exit 0;
}

sub process_template {
    my ($template, $node, $vars, $conf, $omit_header) = @_;

    my %output_conf = ( wiki     => $wiki,
			config   => $config,
                        node     => $node,
			template => $template,
			vars     => $vars
    );
    $output_conf{content_type} = "" if $omit_header; # defaults otherwise
    print OpenGuides::Template->output( %output_conf );
}


sub commit_node {
    my $node = shift;
    my $content  = $q->param('content');
    $content =~ s/\r\n/\n/gs;
    my $checksum = $q->param('checksum');

    my %metadata = OpenGuides::Template->extract_metadata_vars(
        wiki    => $wiki,
        config  => $config,
	cgi_obj => $q
    );

    $metadata{opening_hours_text} = $q->param("hours_text") || "";

    # Check to make sure all the indexable nodes are created
    foreach my $type (qw(Category Locale)) {
        my $lctype = lc($type);
        foreach my $index (@{$metadata{$lctype}}) {
	    $index =~ s/(.*)/\u$1/;
	    my $node = $type . " " . $index;
	    unless ( $wiki->node_exists($node) ) {
	        my $category = $type eq "Category" ? "Category" : "Locales";
		$wiki->write_node( $node,
		                   "\@INDEX_LINK [[$node]]",
				   undef,
				   { username => "Auto Create",
				     comment  => "Auto created $lctype stub page",
				     category => $category
				   }
		);
	    }
	}
    }
	
    foreach my $var ( qw( username comment edit_type ) ) {
        $metadata{$var} = $q->param($var) || "";
    }
    $metadata{host} = $ENV{REMOTE_ADDR};

    my $written = $wiki->write_node($node, $content, $checksum, \%metadata );

    if ($written) {
        print $guide->redirect_to_node($node);
    } else {
        my %node_data = $wiki->retrieve_node($node);
        my %tt_vars = ( checksum       => $node_data{checksum},
                        new_content    => $content,
                        stored_content => $node_data{content} );
        foreach my $mdvar ( keys %metadata ) {
            if ($mdvar eq "locales") {
                $tt_vars{"stored_$mdvar"} = $node_data{metadata}{locale};
                $tt_vars{"new_$mdvar"}    = $metadata{locale};
            } elsif ($mdvar eq "categories") {
                $tt_vars{"stored_$mdvar"} = $node_data{metadata}{category};
                $tt_vars{"new_$mdvar"}    = $metadata{category};
            } elsif ($mdvar eq "username" or $mdvar eq "comment"
                      or $mdvar eq "edit_type" ) {
                $tt_vars{$mdvar} = $metadata{$mdvar};
            } else {
                $tt_vars{"stored_$mdvar"} = $node_data{metadata}{$mdvar}[0];
                $tt_vars{"new_$mdvar"}    = $metadata{$mdvar};
            }
        }
        process_template("edit_conflict.tt", $node, \%tt_vars);
    }
}


sub do_search {
    my $terms = shift;
    my %finds = $wiki->search_nodes($terms);
#    my @sorted = sort { $finds{$a} cmp $finds{$b} } keys %finds;
    my @sorted = sort keys %finds;
    my @results = map {
        { url   => $q->escape($formatter->node_name_to_node_param($_)),
	  title => $q->escapeHTML($_)
        }             } @sorted;
    my %tt_vars = ( results      => \@results,
                    num_results  => scalar @results,
                    not_editable => 1,
                    search_terms => $q->escapeHTML($terms) );
    process_template("search_results.tt", "", \%tt_vars);
}

sub show_backlinks {
    my $node = shift;
    my @backlinks = $wiki->list_backlinks( node => $node );
    my @results = map {
        { url   => $q->escape($formatter->node_name_to_node_param($_)),
	  title => $q->escapeHTML($_)
        }             } sort @backlinks;
    my %tt_vars = ( results      => \@results,
                    num_results  => scalar @results,
                    not_editable => 1 );
    process_template("backlink_results.tt", $node, \%tt_vars);
}

sub show_wanted_pages {
    my @dangling = $wiki->list_dangling_links;
    @dangling = sort @dangling;
    my @wanted;
    foreach my $node_name (@dangling) {
        my $node_param =
 	    uri_escape($formatter->node_name_to_node_param($node_name));
        push @wanted, {
            name          => $q->escapeHTML($node_name),
            edit_link     => $script_url . uri_escape($script_name)
                           . "?action=edit;id=$node_param",
            backlink_link => $script_url . uri_escape($script_name)
 		           . "?action=show_backlinks;id=$node_param"
        };
    }
    process_template( "wanted_pages.tt",
                      "",
                      { not_editable => 1,
                        wanted       => \@wanted } );
}

