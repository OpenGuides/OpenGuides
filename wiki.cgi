#!/usr/local/bin/perl -w

use strict;
use warnings;

use vars qw( $VERSION );
$VERSION = '0.21';

use CGI qw/:standard/;
use CGI::Carp qw(croak);
use CGI::Wiki;
use CGI::Wiki::Search::SII;
use CGI::Wiki::Formatter::UseMod;
use CGI::Wiki::Plugin::GeoCache;
use CGI::Wiki::Plugin::Locator::UK;
use Config::Tiny;
use Geography::NationalGrid;
use Geography::NationalGrid::GB;
use OpenGuides::CGI;
use OpenGuides::RDF;
use OpenGuides::Utils;
use OpenGuides::Diff;
use OpenGuides::Template;
use Time::Piece;
use URI::Escape;

# config vars
my $config = Config::Tiny->read('wiki.conf');

# Read in configuration values from config file.
my $script_name = $config->{_}->{script_name};
my $script_url = $config->{_}->{script_url};

# Ensure that script_url ends in a '/' - this is done in Build.PL but
# we need to allow for people editing the config file by hand later.
$script_url .= "/" unless $script_url =~ /\/$/;

my ($wiki, $formatter, $locator, $q);
eval {
    $wiki = OpenGuides::Utils->make_wiki_object( config => $config );
    $formatter = $wiki->formatter;
    $locator = CGI::Wiki::Plugin::Locator::UK->new;
    $wiki->register_plugin( plugin => $locator );

    # Get CGI object, find out what to do.
    $q = CGI->new;

    # Note $q->param('keywords') gives you the entire param string.
    # We need this because usemod has URLs like foo.com/wiki.pl?This_Page
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
        show_index( type   => $q->param("index_type") || "Full",
                    value  => $q->param("index_value") || "",
                    format => $format );
    } elsif ($action eq "catindex") {
        # This is for backwards compatibility with pre-0.04 versions.
        show_index( type   => "category",
                    value  => $q->param("category") || "",
                    format => $format );
    } elsif ($action eq 'random') {
        my @nodes = $wiki->list_all_nodes();
        $node = $nodes[int(rand(scalar(@nodes) + 1)) + 1];
        redirect_to_node($node);
        exit 0;
    } elsif ($action eq 'find_within_distance') {
        my $metres = $q->param("distance_in_metres");
        my @finds = $locator->find_within_distance( node => $node,
			 		            metres => $metres );
        my @nodes;
        foreach my $find ( @finds ) {
            my $distance = $locator->distance( from_node => $node,
					       to_node   => $find,
                                               unit      => "metres" );
            push @nodes, { name => $find,
			   param => $formatter->node_name_to_node_param($find),
                           distance => $distance };
	}
        @nodes = sort { $a->{distance} <=> $b->{distance} } @nodes;
        process_template("site_index.tt", "index",
                         { nodes  => \@nodes,
			   origin => $node,
			   origin_param => $formatter->node_name_to_node_param($node),
			   limit  => "$metres metres" } );
    } elsif ($action eq 'userstats') {
        show_userstats( $username );
    } elsif ($action eq 'list_all_versions') {
        list_all_versions($node);
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
                my %diff_vars = OpenGuides::Diff->formatted_diff_vars(
                    wiki     => $wiki,
                    node     => $node,
                    versions => [ $version, $other_ver ]
                );
                print OpenGuides::Template->output(
                    wiki     => $wiki,
                    config   => $config,
                    node     => $node,
                    template => "differences.tt",
                    vars     => \%diff_vars
                );
	    } else {
        	display_node($node, $version);
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

sub redirect_to_node {
    my $node = shift;
    print $q->redirect("$script_url$script_name?" . $q->escape($formatter->node_name_to_node_param($node)));
    exit 0;
}

sub display_node {
    my ($node, $version) = @_;
    $node ||= "Home";

    my %tt_vars;

    # If this is a Category or Locale node, check whether it exists
    # and write it a stub node if it doesn't.
    if ( $node =~ /^(Category|Locale) (.*)$/ ) {
        my $type = $1;
        $tt_vars{is_indexable_node} = 1;
        $tt_vars{index_type} = lc($type);
        $tt_vars{index_value} = $2;

        unless ( $wiki->node_exists($node) ) {
            warn "Creating default node $node";
            my $category = $type eq "Category" ? "Category" : "Locales";
            $wiki->write_node( $node,
                               "\@INDEX_LINK [[$node]]",
                               undef,
			       { username => "Auto Create",
				 comment  => "Auto created $tt_vars{index_type} stub page",
                                 category => $category
			       }
	    );
	}
    }

    my %current_data = $wiki->retrieve_node( $node );
    my $current_version = $current_data{version};
    undef $version if ($version && $version == $current_version);
    my %criteria = ( name => $node );
    $criteria{version} = $version if $version;#retrieve_node default is current

    my %node_data = $wiki->retrieve_node( %criteria );
    my $raw = $node_data{content};
    if ( $raw =~ /^#REDIRECT\s+(.+?)\s*$/ ) {
        my $redirect = $1;
        # Strip off enclosing [[ ]] in case this is an extended link.
        $redirect =~ s/^\[\[//;
        $redirect =~ s/\]\]\s*$//;
        # See if this is a valid node, if not then just show the page as-is.
	if ( $wiki->node_exists($redirect) ) {
            redirect_to_node($redirect);
	}
    }
    my $content    = $wiki->format($raw);
    my $modified   = $node_data{last_modified};
    my %metadata   = %{$node_data{metadata}};

    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
                            wiki     => $wiki,
			    config   => $config,
                            metadata => $node_data{metadata} );

    %tt_vars = ( %tt_vars,
		 %metadata_vars,
		 content       => $content,
		 geocache_link => make_geocache_link($node),
		 last_modified => $modified,
		 version       => $node_data{version},
		 node_name     => $q->escapeHTML($node),
		 node_param    => $q->escape($node) );

    # We've undef'ed $version above if this is the current version.
    $tt_vars{current} = 1 unless $version;

    if ($node eq "RecentChanges") {
        my $minor_edits = get_cookie( "show_minor_edits_in_rc" );
        my %criteria = ( days => 7 );
        $criteria{metadata_isnt} = { edit_type => "Minor tidying" }
          unless $minor_edits;
        my @recent = $wiki->list_recent_changes( %criteria );
        @recent = map { {name          => $q->escapeHTML($_->{name}),
                         last_modified => $q->escapeHTML($_->{last_modified}),
                         comment       => $q->escapeHTML($_->{metadata}{comment}[0]),
                         username      => $q->escapeHTML($_->{metadata}{username}[0]),
                         edit_type     => $q->escapeHTML($_->{metadata}{edit_type}[0]),
                         url           => "$script_name?"
          . $q->escape($formatter->node_name_to_node_param($_->{name})) }
                       } @recent;
        $tt_vars{recent_changes} = \@recent;
        $tt_vars{days} = 7;
        process_template("recent_changes.tt", $node, \%tt_vars);
    } elsif ($node eq "Home") {
        my @recent = $wiki->list_recent_changes(
            last_n_changes => 10,
            metadata_isnt  => { edit_type => "Minor tidying" },
        );
        @recent = map { {name          => $q->escapeHTML($_->{name}),
                         last_modified => $q->escapeHTML($_->{last_modified}),
                         comment       => $q->escapeHTML($_->{metadata}{comment}[0]),
                         username      => $q->escapeHTML($_->{metadata}{username}[0]),
                         url           => "$script_name?"
          . $q->escape($formatter->node_name_to_node_param($_->{name})) }
                       } @recent;
        $tt_vars{recent_changes} = \@recent;
        process_template("home_node.tt", $node, \%tt_vars);
    } else {
        process_template("node.tt", $node, \%tt_vars);
    }
}

sub show_index {
    my %args = @_;
    my %tt_vars;
    my @selnodes;
    if ( $args{type} and $args{value} ) {
        if ( $args{type} eq "fuzzy_title_match" ) {
            my %finds = $wiki->fuzzy_title_match( $args{value} );
            @selnodes = sort { $finds{$a} <=> $finds{$b} } keys %finds;
            $tt_vars{criterion} = {
                type  => $args{type},  # for RDF version
                value => $args{value}, # for RDF version
                name  => $q->escapeHTML( "Fuzzy Title Match on '$args{value}'")
	    };
        } else {
            @selnodes = $wiki->list_nodes_by_metadata(
                metadata_type => $args{type},
	        metadata_value => $args{value} );
            $tt_vars{criterion} = {
                type  => $args{type},
                value => $args{value}, # for RDF version
                name => $q->escapeHTML(ucfirst($args{type}) . " $args{value}"),
	        url  => "$script_name?" . ucfirst($args{type}) . "_" .
                  uri_escape($formatter->node_name_to_node_param($args{value}))
            };
        }
    } else {
        @selnodes = $wiki->list_all_nodes();
    }
    my @nodes = map { { name  => $_,
			param => $formatter->node_name_to_node_param($_) }
		    } sort @selnodes;
    $tt_vars{nodes} = \@nodes;
    my ($template, $omit_header);
    if ( $args{format} eq "rdf" ) {
	$template = "rdf_index.tt";
	$omit_header = 1;
	print "Content-type: text/plain\n\n";
    } else {
	$template = "site_index.tt";
    }

    process_template($template,
		     "$args{type} index",
                     \%tt_vars,
		     {},
		     $omit_header,
    );
}

sub list_all_versions {
    my $node = shift;
    my %curr_data = $wiki->retrieve_node($node);
    my $curr_version = $curr_data{version};
    croak "This is the first version" unless $curr_version > 1;
    my @history;
    for my $version ( 1 .. $curr_version ) {
        my %node_data = $wiki->retrieve_node( name    => $node,
					      version => $version );
	push @history, { version  => $version,
			 modified => $node_data{last_modified},
		         username => $node_data{metadata}{username}[0],
		         comment  => $node_data{metadata}{comment}[0]   };
    }
    @history = reverse @history;
    my %tt_vars = ( node    => $node,
		    version => $curr_version,
		    history => \@history );
    process_template("node_history.tt", $node, \%tt_vars );
}

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
		    username        => $username );
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
        $tt_metadata_vars{$var} = $q->param($var);
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

sub make_geocache_link {
    return "" unless get_cookie( "include_geocache_link" );
    my $node = shift || $config->{_}->{home_name};
    my %current_data = $wiki->retrieve_node( $node );
    my %criteria     = ( name => $node );
    my %node_data    = $wiki->retrieve_node( %criteria );
    my %metadata     = %{$node_data{metadata}};
    my $latitude     = $metadata{latitude}[0];
    my $longitude    = $metadata{longitude}[0];
    my $geocache     = CGI::Wiki::Plugin::GeoCache->new();
    my $link_text    = "Look for nearby geocaches";

    if ($latitude && $longitude) {
        my $cache_url    = $geocache->make_link(
					latitude  => $latitude,
					longitude => $longitude,
					link_text => $link_text
				);
        return $cache_url;
    }
    else {
        return "";
    }
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

    foreach my $var ( qw( username comment edit_type ) ) {
        $metadata{$var} = $q->param($var) || "";
    }

    my $written = $wiki->write_node($node, $content, $checksum, \%metadata );

    if ($written) {
        redirect_to_node($node);
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

