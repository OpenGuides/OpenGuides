package OpenGuides;
use strict;

use Carp "croak";
use CGI;
use CGI::Wiki::Plugin::Diff;
use CGI::Wiki::Plugin::Locator::UK;
use OpenGuides::Template;
use OpenGuides::Utils;

use vars qw( $VERSION );

$VERSION = '0.33_02';

=head1 NAME

OpenGuides - A complete web application for managing a collaboratively-written guide to a city or town.

=head1 DESCRIPTION

The OpenGuides software provides the framework for a collaboratively-written
city guide.  It is similar to a wiki but provides somewhat more structured
data storage allowing you to annotate wiki pages with information such as
category, location, and much more.  It provides searching facilities
including "find me everything within a certain distance of this place".
Every page includes a link to a machine-readable (RDF) version of the page.

=head1 METHODS

=over

=item B<new>

  my $guide = OpenGuides->new( config => $config );

=cut

sub new {
    my ($class, %args) = @_;
    my $self = {};
    bless $self, $class;
    my $wiki = OpenGuides::Utils->make_wiki_object( config => $args{config} );
    $self->{wiki} = $wiki;
    $self->{config} = $args{config};
    my $locator = CGI::Wiki::Plugin::Locator::UK->new;
    $wiki->register_plugin( plugin => $locator );
    $self->{locator} = $locator;
    my $differ = CGI::Wiki::Plugin::Diff->new;
    $wiki->register_plugin( plugin => $differ );
    $self->{differ} = $differ;
    return $self;
}

=item B<wiki>

An accessor, returns the underlying L<CGI::Wiki> object.

=cut

sub wiki {
    my $self = shift;
    return $self->{wiki};
}

=item B<config>

An accessor, returns the underlying L<Config::Tiny> object.

=cut

sub config {
    my $self = shift;
    return $self->{config};
}

=item B<locator>

An accessor, returns the underlying L<CGI::Wiki::Plugin::Locator::UK> object.

=cut

sub locator {
    my $self = shift;
    return $self->{locator};
}

=item B<differ>

An accessor, returns the underlying L<CGI::Wiki::Plugin::Diff> object.

=cut

sub differ {
    my $self = shift;
    return $self->{differ};
}

=item B<display_node>

  # Print node to STDOUT.
  $guide->display_node(
                        id      => "Calthorpe Arms",
                        version => 2,
                      );

  # Or return output as a string (useful for writing tests).
  $guide->display_node(
                        id            => "Calthorpe Arms",
                        return_output => 1,
                      );

If C<version> is omitted then the latest version will be displayed.

=cut

sub display_node {
    my ($self, %args) = @_;
    my $return_output = $args{return_output} || 0;
    my $version = $args{version};
    my $id = $args{id} || "Home";
    my $wiki = $self->wiki;
    my $config = $self->config;

    my %tt_vars;

    if ( $id =~ /^(Category|Locale) (.*)$/ ) {
        my $type = $1;
        $tt_vars{is_indexable_node} = 1;
        $tt_vars{index_type} = lc($type);
        $tt_vars{index_value} = $2;
    }

    my %current_data = $wiki->retrieve_node( $id );
    my $current_version = $current_data{version};
    undef $version if ($version && $version == $current_version);
    my %criteria = ( name => $id );
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

    %tt_vars = (
                 %tt_vars,
		 %metadata_vars,
		 content       => $content,
		 geocache_link => $self->make_geocache_link($id),
		 last_modified => $modified,
		 version       => $node_data{version},
		 node_name     => CGI->escapeHTML($id),
		 node_param    => CGI->escape($id),
                 language      => $config->{_}->{default_language},
               );


    # We've undef'ed $version above if this is the current version.
    $tt_vars{current} = 1 unless $version;

    if ($id eq "RecentChanges") {
        my $minor_edits = $self->get_cookie( "show_minor_edits_in_rc" );
        my %criteria = ( days => 7 );
        $criteria{metadata_was} = { edit_type => "Normal edit" }
          unless $minor_edits;
        my @recent = $wiki->list_recent_changes( %criteria );
        @recent = map { {name          => CGI->escapeHTML($_->{name}),
                         last_modified => CGI->escapeHTML($_->{last_modified}),
                         comment       => CGI->escapeHTML($_->{metadata}{comment}[0]),
                         username      => CGI->escapeHTML($_->{metadata}{username}[0]),
                         host          => CGI->escapeHTML($_->{metadata}{host}[0]),
                         username_param => CGI->escape($_->{metadata}{username}[0]),
                         edit_type     => CGI->escapeHTML($_->{metadata}{edit_type}[0]),
                         url           => "$config->{_}->{script_name}?"
          . CGI->escape($wiki->formatter->node_name_to_node_param($_->{name})) }
                       } @recent;
        $tt_vars{recent_changes} = \@recent;
        $tt_vars{days} = 7;
        my $output = $self->process_template(
                                          id            => $id,
                                          template      => "recent_changes.tt",
                                          tt_vars       => \%tt_vars,
                                            );
        return $output if $return_output;
        print $output;
    } elsif ($id eq "Home") {
        my @recent = $wiki->list_recent_changes(
            last_n_changes => 10,
            metadata_was   => { edit_type => "Normal edit" },
        );
        @recent = map { {name          => CGI->escapeHTML($_->{name}),
                         last_modified => CGI->escapeHTML($_->{last_modified}),
                         comment       => CGI->escapeHTML($_->{metadata}{comment}[0]),
                         username      => CGI->escapeHTML($_->{metadata}{username}[0]),
                         url           => "$config->{_}->{script_name}?"
          . CGI->escape($wiki->formatter->node_name_to_node_param($_->{name})) }
                       } @recent;
        $tt_vars{recent_changes} = \@recent;
        my $output = $self->process_template(
                                              id            => $id,
                                              template      => "home_node.tt",
                                              tt_vars       => \%tt_vars,
                                            );
        return $output if $return_output;
        print $output;
    } else {
        my $output = $self->process_template(
                                              id            => $id,
                                              template      => "node.tt",
                                              tt_vars       => \%tt_vars,
                                            );
        return $output if $return_output;
        print $output;
    }
}

=item B<display_diffs>

  $guide->display_diffs(
                         id            => "Home Page",
                         version       => 6,
                         other_version => 5,
                       );

  # Or return output as a string (useful for writing tests).
  my $output = $guide->display_diffs(
                                      id            => "Home Page",
                                      version       => 6,
                                      other_version => 5,
                                      return_output => 1,
                                    );

  # Or return the hash of variables that will be passed to the template
  # (not including those set additionally by OpenGuides::Template).
  my %vars = $guide->display_diffs(
                                    id             => "Home Page",
                                    version        => 6,
                                    other_version  => 5,
                                    return_tt_vars => 1,
                                  );

=cut

sub display_diffs {
    my ($self, %args) = @_;
    my %diff_vars = $self->differ->differences(
                                        node          => $args{id},
                                        left_version  => $args{version},
   		                        right_version => $args{other_version},
                                              );
    return %diff_vars if $args{return_tt_vars};
    my $output = $self->process_template(
                                          id       => $args{id},
                                          template => "differences.tt",
                                          tt_vars  => \%diff_vars
                                        );
    return $output if $args{return_output};
    print $output;
}

=item B<find_within_distance>

  $guide->find_within_distance(
                                id => $node,
                                metres => $q->param("distance_in_metres")
                              );

=cut

sub find_within_distance {
    my ($self, %args) = @_;
    my $node = $args{node};
    my $metres = $args{metres};
    my $formatter = $self->wiki->formatter;

    my @finds = $self->locator->find_within_distance(
                                                      node   => $node,
			 		              metres => $metres,
                                                    );
    my @nodes;
    foreach my $find ( @finds ) {
        my $distance = $self->locator->distance(
                                                 from_node => $node,
					         to_node   => $find,
                                                 unit      => "metres"
                                               );
        push @nodes, {
                       name     => $find,
	               param    => $formatter->node_name_to_node_param($find),
                       distance => $distance,
                     };
    }
    @nodes = sort { $a->{distance} <=> $b->{distance} } @nodes;

    my %tt_vars = (
                    nodes        => \@nodes,
                    origin       => $node,
                    origin_param => $formatter->node_name_to_node_param($node),
                    limit        => "$metres metres",
                  );

    print $self->process_template(
                                   id       => "index", # KLUDGE
                                   template => "site_index.tt",
                                   vars     => \%tt_vars,
                                 );
}

=item B<show_index>

  $guide->show_index(
                      type   => "category",
                      value  => "pubs",
                    );

  # RDF version.
  $guide->show_index(
                      type   => "locale",
                      value  => "Holborn",
                      format => "rdf",
                    );

=cut

sub show_index {
    my ($self, %args) = @_;
    my $wiki = $self->wiki;
    my $formatter = $wiki->formatter;
    my %tt_vars;
    my @selnodes;

    if ( $args{type} and $args{value} ) {
        if ( $args{type} eq "fuzzy_title_match" ) {
            my %finds = $wiki->fuzzy_title_match( $args{value} );
            @selnodes = sort { $finds{$a} <=> $finds{$b} } keys %finds;
            $tt_vars{criterion} = {
                type  => $args{type},  # for RDF version
                value => $args{value}, # for RDF version
                name  => CGI->escapeHTML("Fuzzy Title Match on '$args{value}'")
	    };
        } else {
            @selnodes = $wiki->list_nodes_by_metadata(
                metadata_type  => $args{type},
	        metadata_value => $args{value},
                ignore_case    => 1,
            );
            my $name = ucfirst($args{type}) . " $args{value}" ;
            my $url = $self->config->{_}->{script_name}
                      . ucfirst( $args{type} )
                      . "_"
                      . uri_escape(
                              $formatter->node_name_to_node_param($args{value})
                                  );
            $tt_vars{criterion} = {
                type  => $args{type},
                value => $args{value}, # for RDF version
                name  => CGI->escapeHTML( $name ),
	        url   => $url,
            };
        }
    } else {
        @selnodes = $wiki->list_all_nodes();
    }

    my @nodes = map { { name      => $_,
                        node_data => { $wiki->retrieve_node( name => $_ ) },
			param     => $formatter->node_name_to_node_param($_) }
		    } sort @selnodes;

    $tt_vars{nodes} = \@nodes;

    my ($template, %conf);

    if ( $args{format} eq "rdf" ) {
	$template = "rdf_index.tt";
        $conf{content_type} = "text/plain";
    } else {
	$template = "site_index.tt";
    }

    %conf = (
              %conf,
              node        => "$args{type} index", # KLUDGE
              template    => $template,
              tt_vars     => \%tt_vars,
    );

    print $self->process_template( %conf );
}

=item B<list_all_versions>

  $guide->list_all_versions ( id => "Home Page" );

=cut

sub list_all_versions {
    my ($self, %args) = @_;
    my $node = $args{id};
    my %curr_data = $self->wiki->retrieve_node($node);
    my $curr_version = $curr_data{version};
    croak "This is the first version" unless $curr_version > 1;
    my @history;
    for my $version ( 1 .. $curr_version ) {
        my %node_data = $self->wiki->retrieve_node( name    => $node,
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
    print $self->process_template(
                                   id       => $node,
                                   template => "node_history.tt",
                                   tt_vars  => \%tt_vars,
                                 );
}

sub process_template {
    my ($self, %args) = @_;
    my %output_conf = ( wiki     => $self->wiki,
			config   => $self->config,
                        node     => $args{id},
			template => $args{template},
			vars     => $args{tt_vars},
    );
    $output_conf{content_type} = $args{content_type} if $args{content_type};
    return OpenGuides::Template->output( %output_conf );
}

sub get_cookie {
    my $self = shift;
    my $config = $self->config;
    my $pref_name = shift or return "";
    my %cookie_data = OpenGuides::CGI->get_prefs_from_cookie(config=>$config);
    return $cookie_data{$pref_name};
}

sub make_geocache_link {
    my $self = shift;
    my $wiki = $self->wiki;
    my $config = $self->config;
    return "" unless $self->get_cookie( "include_geocache_link" );
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

=back

=head1 BUGS AND CAVEATS

At the moment, the location data uses a United-Kingdom-specific module,
so the location features might not work so well outside the UK.

=head1 SEE ALSO

=over 4

=item * L<http://london.openguides.org/|The Open Guide to London>, the first and biggest OpenGuides site.

=item * L<http://openguides.org/|The OpenGuides website>, with a list of all live OpenGuides installs.

=item * L<CGI::Wiki>, the Wiki toolkit which does the heavy lifting for OpenGuides

=back

=head1 FEEDBACK

If you have a question, a bug report, or a patch, or you're interested
in joining the development team, please contact openguides-dev@openguides.org
(moderated mailing list, will reach all current developers but you'll have
to wait for your post to be approved) or kake@earth.li (a real person who
may take a little while to reply to your mail if she's busy).

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

     Copyright (C) 2003-4 The OpenGuides Project.  All Rights Reserved.

The OpenGuides distribution is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 CREDITS

Programming by Earle Martin, Kake Pugh, Ivor Williams.  Testing and
bug reporting by Cal Henderson, Bob Walker, Kerry Bosworth, Dominic
Hargreaves, Simon Cozens, among others.  Much of the Module::Build
stuff copied from the Siesta project L<http://siesta.unixbeard.net/>

=cut

1;
