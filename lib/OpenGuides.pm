package OpenGuides;
use strict;

use Carp "croak";
use CGI;
use Wiki::Toolkit::Plugin::Diff;
use Wiki::Toolkit::Plugin::Locator::Grid;
use OpenGuides::CGI;
use OpenGuides::Feed;
use OpenGuides::Template;
use OpenGuides::Utils;
use Time::Piece;
use URI::Escape;

use vars qw( $VERSION );

$VERSION = '0.59';

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

  my $config = OpenGuides::Config->new( file => "wiki.conf" );
  my $guide = OpenGuides->new( config => $config );

=cut

sub new {
    my ($class, %args) = @_;
    my $self = {};
    bless $self, $class;
    my $wiki = OpenGuides::Utils->make_wiki_object( config => $args{config} );
    $self->{wiki} = $wiki;
    $self->{config} = $args{config};

    my $geo_handler = $self->config->geo_handler;
    my $locator;
    if ( $geo_handler == 1 ) {
        $locator = Wiki::Toolkit::Plugin::Locator::Grid->new(
                                             x => "os_x",    y => "os_y" );
    } elsif ( $geo_handler == 2 ) {
        $locator = Wiki::Toolkit::Plugin::Locator::Grid->new(
                                             x => "osie_x",  y => "osie_y" );
    } else {
        $locator = Wiki::Toolkit::Plugin::Locator::Grid->new(
                                             x => "easting", y => "northing" );
    }
    $wiki->register_plugin( plugin => $locator );
    $self->{locator} = $locator;

    my $differ = Wiki::Toolkit::Plugin::Diff->new;
    $wiki->register_plugin( plugin => $differ );
    $self->{differ} = $differ;

    if($self->config->ping_services) {
        eval {
            require Wiki::Toolkit::Plugin::Ping;
        };

        if ( $@ ) {
            warn "You asked for some ping services, but can't find "
                 . "Wiki::Toolkit::Plugin::Ping";
        } else {
            my @ws = split(/\s*,\s*/, $self->config->ping_services);
            my %well_known = Wiki::Toolkit::Plugin::Ping->well_known;
            my %services;
            foreach my $s (@ws) {
                if($well_known{$s}) {
                    $services{$s} = $well_known{$s};
                } else {
                    warn("Ignoring unknown ping service '$s'");
                }
            }
            my $ping = Wiki::Toolkit::Plugin::Ping->new(
                node_to_url => $self->{config}->{script_url}
                               . $self->{config}->{script_name} . '?$node',
                services => \%services
            );
            $wiki->register_plugin( plugin => $ping );
        }
    }

    return $self;
}

=item B<wiki>

An accessor, returns the underlying L<Wiki::Toolkit> object.

=cut

sub wiki {
    my $self = shift;
    return $self->{wiki};
}

=item B<config>

An accessor, returns the underlying L<OpenGuides::Config> object.

=cut

sub config {
    my $self = shift;
    return $self->{config};
}

=item B<locator>

An accessor, returns the underlying L<Wiki::Toolkit::Plugin::Locator::UK> object.

=cut

sub locator {
    my $self = shift;
    return $self->{locator};
}

=item B<differ>

An accessor, returns the underlying L<Wiki::Toolkit::Plugin::Diff> object.

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

  # Or return the hash of variables that will be passed to the template
  # (not including those set additionally by OpenGuides::Template).
  $guide->display_node(
                          id             => "Calthorpe Arms",
                          return_tt_vars => 1,
                      );

If C<version> is omitted then the latest version will be displayed.

=cut

sub display_node {
    my ($self, %args) = @_;
    my $return_output = $args{return_output} || 0;
    my $version = $args{version};
    my $id = $args{id} || $self->config->home_name;
    my $wiki = $self->wiki;
    my $config = $self->config;
    my $oldid = $args{oldid} || '';
    my $do_redirect = $args{redirect} || 1;

    my %tt_vars;

    $tt_vars{home_name} = $self->config->home_name;
    
    if ( $id =~ /^(Category|Locale) (.*)$/ ) {
        my $type = $1;
        $tt_vars{is_indexable_node} = 1;
        $tt_vars{index_type} = lc($type);
        $tt_vars{index_value} = $2;
        $tt_vars{"rss_".lc($type)."_url"} =
                           $config->script_name . "?action=rc;format=rss;"
                           . lc($type) . "=" . lc(CGI->escape($2));
        $tt_vars{"atom_".lc($type)."_url"} =
                           $config->script_name . "?action=rc;format=atom;"
                           . lc($type) . "=" . lc(CGI->escape($2));
    }

    my %current_data = $wiki->retrieve_node( $id );
    my $current_version = $current_data{version};
    undef $version if ($version && $version == $current_version);
    my %criteria = ( name => $id );
    $criteria{version} = $version if $version; # retrieve_node default is current

    my %node_data = $wiki->retrieve_node( %criteria );

    # Fixes passing undefined values to Text::Wikiformat if node doesn't exist.
    my $content = '';
    if ($node_data{content}) {
        $content    = $wiki->format($node_data{content});
    }

    my $modified   = $node_data{last_modified};
    my $moderated  = $node_data{moderated};
    my %metadata   = %{$node_data{metadata}};

    my ($wgs84_long, $wgs84_lat) = OpenGuides::Utils->get_wgs84_coords(
                                        longitude => $metadata{longitude}[0],
                                        latitude => $metadata{latitude}[0],
                                        config => $config);
    if ($args{format} && $args{format} eq 'raw') {
        print "Content-Type: text/plain\n\n";
        print $node_data{content};
        return 0;
    }
   
    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
                            wiki     => $wiki,
                            config   => $config,
                            metadata => $node_data{metadata}
                        );

    %tt_vars = (
                   %tt_vars,
                   %metadata_vars,
                   content       => $content,
                   last_modified => $modified,
                   version       => $node_data{version},
                   node          => $id,
                   language      => $config->default_language,
                   moderated     => $moderated,
                   oldid         => $oldid,
                   enable_gmaps  => 1,
                   wgs84_long    => $wgs84_long,
                   wgs84_lat     => $wgs84_lat
               );

    if ( $config->show_gmap_in_node_display
           && $self->get_cookie( "display_google_maps" ) ) {
        $tt_vars{display_google_maps} = 1;
    }

    # Should we include a standard list of categories or locales?
    if ($config->enable_common_categories || $config->enable_common_locales) {
        $tt_vars{common_catloc} = 1;
        $tt_vars{common_categories} = $config->enable_common_categories;
        $tt_vars{common_locales} = $config->enable_common_locales;
        $tt_vars{catloc_link} = $config->script_url . $config->script_name
                                . "?id=";
    }
    
    if ( $node_data{content} && $node_data{content} =~ /^#REDIRECT\s+(.+?)\s*$/ ) {
        my $redirect = $1;
        # Strip off enclosing [[ ]] in case this is an extended link.
        $redirect =~ s/^\[\[//;
        $redirect =~ s/\]\]\s*$//;

        # Don't redirect if the parameter "redirect" is given as 0.
        if ($do_redirect == 0) {
            return %tt_vars if $args{return_tt_vars};
            $tt_vars{current} = 1;
            my $output = $self->process_template(
                                                  id            => $id,
                                                  template      => "node.tt",
                                                  tt_vars       => \%tt_vars,
                                                );
            return $output if $return_output;
            print $output;
        } elsif ( $wiki->node_exists($redirect) && $redirect ne $id && $redirect ne $oldid ) {
            # Avoid loops by not generating redirects to the same node or the previous node.
            my $output = $self->redirect_to_node($redirect, $id);
            return $output if $return_output;
            print $output;
            return 0;
        }
    }

    # We've undef'ed $version above if this is the current version.
    $tt_vars{current} = 1 unless $version;

    if ($id eq "RecentChanges") {
        $self->display_recent_changes(%args);
    } elsif ( $id eq $self->config->home_name ) {
        if ( $self->config->recent_changes_on_home_page ) {
            my @recent = $wiki->list_recent_changes(
                last_n_changes => 10,
                metadata_was   => { edit_type => "Normal edit" },
            );
            @recent = map {
                            {
                              name          => CGI->escapeHTML($_->{name}),
                              last_modified =>
                                  CGI->escapeHTML($_->{last_modified}),
                              version       => CGI->escapeHTML($_->{version}),
                              comment       =>
                                  CGI->escapeHTML($_->{metadata}{comment}[0]),
                              username      =>
                                  CGI->escapeHTML($_->{metadata}{username}[0]),
                              url           => $config->script_name . "?"
                                             . CGI->escape($wiki->formatter->node_name_to_node_param($_->{name}))
                            }
                          } @recent;
            $tt_vars{recent_changes} = \@recent;
        }
        return %tt_vars if $args{return_tt_vars};
        my $output = $self->process_template(
                                                id            => $id,
                                                template      => "home_node.tt",
                                                tt_vars       => \%tt_vars,
                                            );
        return $output if $return_output;
        print $output;
    } else {
        return %tt_vars if $args{return_tt_vars};
        my $output = $self->process_template(
                                                id            => $id,
                                                template      => "node.tt",
                                                tt_vars       => \%tt_vars,
                                            );
        return $output if $return_output;
        print $output;
    }
}

=item B<display_random_page>

  $guide->display_random_page;

Display a random page.  As with other methods, the
C<return_output> parameter can be used to return the output instead of
printing it to STDOUT.

=cut

sub display_random_page {
    my ( $self, %args ) = @_;
    my @nodes = $self->wiki->list_all_nodes();
    my $node = $nodes[ rand @nodes ];
    my $output = $self->redirect_to_node( $node );
    return $output if $args{return_output};
    print $output;
}

=item B<display_edit_form>

  $guide->display_edit_form(
                             id => "Vivat Bacchus",
                           );

Display an edit form for the specified node.  As with other methods, the
C<return_output> parameter can be used to return the output instead of
printing it to STDOUT.

=cut

sub display_edit_form {
    my ($self, %args) = @_;
    my $return_output = $args{return_output} || 0;
    my $config = $self->config;
    my $wiki = $self->wiki;
    my $node = $args{id};
    my %node_data = $wiki->retrieve_node($node);
    my ($content, $checksum) = @node_data{ qw( content checksum ) };
    my %cookie_data = OpenGuides::CGI->get_prefs_from_cookie(config=>$config);

    my $username = $self->get_cookie( "username" );
    my $edit_type = $self->get_cookie( "default_edit_type" ) eq "normal"
                        ? "Normal edit"
                        : "Minor tidying";

    my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
                             wiki     => $wiki,
                             config   => $config,
                 metadata => $node_data{metadata} );

    $metadata_vars{website} ||= 'http://';
    my $moderate = $wiki->node_required_moderation($node);

    my %tt_vars = ( content         => CGI->escapeHTML($content),
                    checksum        => CGI->escapeHTML($checksum),
                    %metadata_vars,
                    config          => $config,
                    username        => $username,
                    edit_type       => $edit_type,
                    moderate        => $moderate,
                    deter_robots    => 1,
    );

    my $output = $self->process_template(
                                          id            => $node,
                                          template      => "edit_form.tt",
                                          tt_vars       => \%tt_vars,
                                        );
    return $output if $return_output;
    print $output;
}

=item B<preview_edit>

  $guide->preview_edit(
                        id      => "Vivat Bacchus",
                        cgi_obj => $q,
                      );

Preview the edited version of the specified node.  As with other methods, the
C<return_output> parameter can be used to return the output instead of
printing it to STDOUT.

=cut

sub preview_edit {
    my ($self, %args) = @_;
    my $node = $args{id};
    my $q = $args{cgi_obj};
    my $return_output = $args{return_output};
    my $wiki = $self->wiki;
    my $config = $self->config;

    my $content  = $q->param('content');
    $content     =~ s/\r\n/\n/gs;
    my $checksum = $q->param('checksum');

    my %new_metadata = OpenGuides::Template->extract_metadata_vars(
                                               wiki                 => $wiki,
                                               config               => $config,
                                               cgi_obj              => $q,
                                               set_coord_field_vars => 1,
    );
    foreach my $var ( qw( username comment edit_type ) ) {
        $new_metadata{$var} = $q->escapeHTML($q->param($var));
    }

    if ($wiki->verify_checksum($node, $checksum)) {
        my $moderate = $wiki->node_required_moderation($node);
        my %tt_vars = (
            %new_metadata,
            config                 => $config,
            content                => $q->escapeHTML($content),
            preview_html           => $wiki->format($content),
            preview_above_edit_box => $self->get_cookie(
                                                   "preview_above_edit_box" ),
            checksum               => $q->escapeHTML($checksum),
            moderate               => $moderate
        );
        my $output = $self->process_template(
                                              id       => $node,
                                              template => "edit_form.tt",
                                              tt_vars  => \%tt_vars,
                                            );
        return $output if $args{return_output};
        print $output;
    } else {
        return $self->_handle_edit_conflict(
                                             id            => $node,
                                             content       => $content,
                                             new_metadata  => \%new_metadata,
                                             return_output => $return_output,
                                           );
    }
}

=item B<display_recent_changes>  

  $guide->display_recent_changes;

As with other methods, the C<return_output> parameter can be used to
return the output instead of printing it to STDOUT.

=cut

sub display_recent_changes {
    my ($self, %args) = @_;
    my $config = $self->config;
    my $wiki = $self->wiki;
    my $minor_edits = $self->get_cookie( "show_minor_edits_in_rc" );
    my $id = $args{id} || $self->config->home_name;
    my $return_output = $args{return_output} || 0;
    my (%tt_vars, %recent_changes);
    my $q = CGI->new;
    my $since = $q->param("since");
    if ( $since ) {
        $tt_vars{since} = $since;
        my $t = localtime($since); # overloaded by Time::Piece
        $tt_vars{since_string} = $t->strftime;
        my %criteria = ( since => $since );   
        $criteria{metadata_was} = { edit_type => "Normal edit" }
          unless $minor_edits;
        my @rc = $self->{wiki}->list_recent_changes( %criteria );
 
        @rc = map {
            {
              name        => CGI->escapeHTML($_->{name}),
              last_modified => CGI->escapeHTML($_->{last_modified}),
              version     => CGI->escapeHTML($_->{version}),
              comment     => CGI->escapeHTML($_->{metadata}{comment}[0]),
              username    => CGI->escapeHTML($_->{metadata}{username}[0]),
              host        => CGI->escapeHTML($_->{metadata}{host}[0]),
              username_param => CGI->escape($_->{metadata}{username}[0]),
              edit_type   => CGI->escapeHTML($_->{metadata}{edit_type}[0]),
              url         => $config->script_name . "?"
      . CGI->escape($wiki->formatter->node_name_to_node_param($_->{name})),
        }
                   } @rc;
        if ( scalar @rc ) {
            $recent_changes{since} = \@rc; 
        }
    } else {
        for my $days ( [0, 1], [1, 7], [7, 14], [14, 30] ) {
            my %criteria = ( between_days => $days );
            $criteria{metadata_was} = { edit_type => "Normal edit" }
              unless $minor_edits;
            my @rc = $self->{wiki}->list_recent_changes( %criteria );

            @rc = map {
            {
              name        => CGI->escapeHTML($_->{name}),
              last_modified => CGI->escapeHTML($_->{last_modified}),
              version     => CGI->escapeHTML($_->{version}),
              comment     => CGI->escapeHTML($_->{metadata}{comment}[0]),
              username    => CGI->escapeHTML($_->{metadata}{username}[0]),
              host        => CGI->escapeHTML($_->{metadata}{host}[0]),
              username_param => CGI->escape($_->{metadata}{username}[0]),
              edit_type   => CGI->escapeHTML($_->{metadata}{edit_type}[0]),
              url         => $config->script_name . "?"
      . CGI->escape($wiki->formatter->node_name_to_node_param($_->{name})),
        }
                       } @rc;
            if ( scalar @rc ) {
                $recent_changes{$days->[1]} = \@rc;
        }
        }
    }
    $tt_vars{not_editable} = 1;
    $tt_vars{recent_changes} = \%recent_changes;
    my %processing_args = (
                            id            => $id,
                            template      => "recent_changes.tt",
                            tt_vars       => \%tt_vars,
                           );
    if ( !$since && $self->get_cookie("track_recent_changes_views") ) {
    my $cookie =
           OpenGuides::CGI->make_recent_changes_cookie(config => $config );
        $processing_args{cookies} = $cookie;
        $tt_vars{last_viewed} = OpenGuides::CGI->get_last_recent_changes_visit_from_cookie( config => $config );
    }
    return %tt_vars if $args{return_tt_vars};
    my $output = $self->process_template( %processing_args );
    return $output if $return_output;
    print $output;
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
    $diff_vars{not_deletable} = 1;
    $diff_vars{not_editable}  = 1;
    $diff_vars{deter_robots}  = 1;
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
    my $node = $args{id};
    my $metres = $args{metres};
    my %data = $self->wiki->retrieve_node( $node );
    my $lat = $data{metadata}{latitude}[0];
    my $long = $data{metadata}{longitude}[0];
    my $script_url = $self->config->script_url;
    my $q = CGI->new;
    print $q->redirect( $script_url . "search.cgi?lat=$lat;long=$long;distance_in_metres=$metres" );
}

=item B<show_backlinks>

  $guide->show_backlinks( id => "Calthorpe Arms" );

As with other methods, parameters C<return_tt_vars> and
C<return_output> can be used to return these things instead of
printing the output to STDOUT.

=cut

sub show_backlinks {
    my ($self, %args) = @_;
    my $wiki = $self->wiki;
    my $formatter = $wiki->formatter;

    my @backlinks = $wiki->list_backlinks( node => $args{id} );
    my @results = map {
                          {
                              url   => CGI->escape($formatter->node_name_to_node_param($_)),
                              title => CGI->escapeHTML($_)
                          }
                      } sort @backlinks;
    my %tt_vars = ( results       => \@results,
                    num_results   => scalar @results,
                    not_deletable => 1,
                    deter_robots  => 1,
                    not_editable  => 1 );
    return %tt_vars if $args{return_tt_vars};
    my $output = OpenGuides::Template->output(
                                                 node    => $args{id},
                                                 wiki    => $wiki,
                                                 config  => $self->config,
                                                 template=>"backlink_results.tt",
                                                 vars    => \%tt_vars,
                                             );
    return $output if $args{return_output};
    print $output;
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

  # RSS / Atom version (recent changes style).
  $guide->show_index(
                        type   => "locale",
                        value  => "Holborn",
                        format => "rss",
                    );

  # Or return output as a string (useful for writing tests).
  $guide->show_index(
                        type          => "category",
                        value         => "pubs",
                        return_output => 1,
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
            $tt_vars{not_editable} = 1;
        } else {
            @selnodes = $wiki->list_nodes_by_metadata(
                metadata_type  => $args{type},
                metadata_value => $args{value},
                ignore_case    => 1
            );
            my $name = ucfirst($args{type}) . " $args{value}";
            my $url = $self->config->script_name
                      . "?"
                      . ucfirst( $args{type} )
                      . "_"
                      . uri_escape(
                                      $formatter->node_name_to_node_param($args{value})
                                  );
            $tt_vars{criterion} = {
                type  => $args{type},
                value => $args{value}, # for RDF version
                name  => CGI->escapeHTML( $name ),
                url   => $url
            };
            $tt_vars{not_editable} = 1;
        }
    } else {
        @selnodes = $wiki->list_all_nodes();
    }

    my @nodes = map {
                        {
                            name      => $_,
                            node_data => { $wiki->retrieve_node( name => $_ ) },
                            param     => $formatter->node_name_to_node_param($_) }
                        } sort @selnodes;

    # Convert the lat+long to WGS84 as required
    for(my $i=0; $i<scalar @nodes;$i++) {
        my $node = $nodes[$i];
        if($node) {
            my %metadata = %{$node->{node_data}->{metadata}};
            my ($wgs84_long, $wgs84_lat);
            eval {
                ($wgs84_long, $wgs84_lat) = OpenGuides::Utils->get_wgs84_coords(
                                      longitude => $metadata{longitude}[0],
                                      latitude => $metadata{latitude}[0],
                                      config => $self->config);
            };
            warn $@." on ".$metadata{latitude}[0]." ".$metadata{longitude}[0] if $@;

            push @{$nodes[$i]->{node_data}->{metadata}->{wgs84_long}}, $wgs84_long;
            push @{$nodes[$i]->{node_data}->{metadata}->{wgs84_lat}},  $wgs84_lat;
        }
    }

    $tt_vars{nodes} = \@nodes;

    my ($template, %conf);

    if ( $args{format} ) {
        if ( $args{format} eq "rdf" ) {
            $template = "rdf_index.tt";
            $conf{content_type} = "application/rdf+xml";
        }
        elsif ( $args{format} eq "plain" ) {
            $template = "plain_index.tt";
            $conf{content_type} = "text/plain";
        } elsif ( $args{format} eq "map" ) {
            my $q = CGI->new;
            $tt_vars{zoom} = $q->param('zoom') || '';
            $tt_vars{lat} = $q->param('lat') || '';
            $tt_vars{long} = $q->param('long') || '';
            $tt_vars{map_type} = $q->param('map_type') || '';
            $tt_vars{centre_long} = $self->config->centre_long;
            $tt_vars{centre_lat} = $self->config->centre_lat;
            $tt_vars{default_gmaps_zoom} = $self->config->default_gmaps_zoom;
            $tt_vars{enable_gmaps} = 1;
            $tt_vars{display_google_maps} = 1; # override for this page
            $template = "map_index.tt";
            
        } elsif( $args{format} eq "rss" || $args{format} eq "atom") {
            # They really wanted a recent changes style rss/atom feed
            my $feed_type = $args{format};
            my ($feed,$content_type) = $self->get_feed_and_content_type($feed_type);
            $feed->set_feed_name_and_url_params(
                        "Index of $args{type} $args{value}",
                        "action=index;index_type=$args{type};index_value=$args{value}"
            );

            # Grab the actual node data out of @nodes
            my @node_data;
            foreach my $node (@nodes) {
                $node->{node_data}->{name} = $node->{name};
                push @node_data, $node->{node_data};
            }

            my $output = "Content-Type: ".$content_type."\n";
            $output .= $feed->build_feed_for_nodes($feed_type, @node_data);

            return $output if $args{return_output};
            print $output;
            return;
        }
    } else {
        $template = "site_index.tt";
    }

    %conf = (
                %conf,
                node        => "$args{type} index", # KLUDGE
                template    => $template,
                tt_vars     => \%tt_vars,
            );

    my $output = $self->process_template( %conf );
    return $output if $args{return_output};
    print $output;
}

=item B<list_all_versions>

  $guide->list_all_versions ( id => "Home Page" );

  # Or return output as a string (useful for writing tests).
  $guide->list_all_versions (
                                id            => "Home Page",
                                return_output => 1,
                            );

  # Or return the hash of variables that will be passed to the template
  # (not including those set additionally by OpenGuides::Template).
  $guide->list_all_versions (
                                id             => "Home Page",
                                return_tt_vars => 1,
                            );

=cut

sub list_all_versions {
    my ($self, %args) = @_;
    my $return_output = $args{return_output} || 0;
    my $node = $args{id};
    my %curr_data = $self->wiki->retrieve_node($node);
    my $curr_version = $curr_data{version};
    my @history;
    for my $version ( 1 .. $curr_version ) {
        my %node_data = $self->wiki->retrieve_node( name    => $node,
                                                    version => $version );
        # $node_data{version} will be zero if this version was deleted.
        push @history, {
            version  => CGI->escapeHTML( $version ),
            modified => CGI->escapeHTML( $node_data{last_modified} ),
            username => CGI->escapeHTML( $node_data{metadata}{username}[0] ),
            comment  => CGI->escapeHTML( $node_data{metadata}{comment}[0] ),
                       } if $node_data{version};
    }
    @history = reverse @history;
    my %tt_vars = (
                      node          => $node,
                      version       => $curr_version,
                      not_deletable => 1,
                      not_editable  => 1,
                      deter_robots  => 1,
                      history       => \@history
                  );
    return %tt_vars if $args{return_tt_vars};
    my $output = $self->process_template(
                                            id       => $node,
                                            template => "node_history.tt",
                                            tt_vars  => \%tt_vars,
                                        );
    return $output if $return_output;
    print $output;
}

=item B<get_feed_and_content_type>

Fetch the OpenGuides feed object, and the output content type, for the
supplied feed type.

Handles all the setup for the OpenGuides feed object.

=cut

sub get_feed_and_content_type {
    my ($self, $feed_type) = @_;

    my $feed = OpenGuides::Feed->new(
                                        wiki       => $self->wiki,
                                        config     => $self->config,
                                        og_version => $VERSION,
                                    );

    my $content_type = $feed->default_content_type($feed_type);

    return ($feed, $content_type);
}

=item B<display_feed>

  # Last ten non-minor edits to Hammersmith pages in RSS 1.0 format
  $guide->display_feed(
                         feed_type          => 'rss',
                         feed_listing       => 'recent_changes',
                         items              => 10,
                         ignore_minor_edits => 1,
                         locale             => "Hammersmith",
                     );

  # All edits bob has made to pub pages in the last week in Atom format
  $guide->display_feed(
                         feed_type    => 'atom',
                         feed_listing => 'recent_changes',
                         days         => 7,
                         username     => "bob",
                         category     => "Pubs",
                     );

C<feed_type> is a mandatory parameter. Supported values at present are 
"rss" and "atom".

C<feed_listing> is a mandatory parameter. Supported values at present 
are "recent_changes". (More values are coming soon though!)

As with other methods, the C<return_output> parameter can be used to
return the output instead of printing it to STDOUT.

=cut

sub display_feed {
    my ($self, %args) = @_;

    my $feed_type = $args{feed_type};
    croak "No feed type given" unless $feed_type;

    my $feed_listing = $args{feed_listing};
    croak "No feed listing given" unless $feed_listing;
    
    my $return_output = $args{return_output} ? 1 : 0;

    # Basic criteria, whatever the feed listing type is
    my %criteria = (
                       feed_type             => $feed_type,
                       feed_listing          => $feed_listing,
                       also_return_timestamp => 1,
                   );

    # Feed listing specific criteria
    if($feed_listing eq "recent_changes") {
        $criteria{items} = $args{items} || "";
        $criteria{days}  = $args{days}  || "";
        $criteria{ignore_minor_edits} = $args{ignore_minor_edits} ? 1 : 0;

        my $username = $args{username} || "";
        my $category = $args{category} || "";
        my $locale   = $args{locale}   || "";

        my %filter;
        $filter{username} = $username if $username;
        $filter{category} = $category if $category;
        $filter{locale}   = $locale   if $locale;
        if ( scalar keys %filter ) {
            $criteria{filter_on_metadata} = \%filter;
        }
    }
    elsif($feed_listing eq "node_all_versions") {
        $criteria{name} = $args{name};
    }


    # Get the feed object, and the content type
    my ($feed,$content_type) = $self->get_feed_and_content_type($feed_type);

    my $output = "Content-Type: ".$content_type;
    if($self->config->http_charset) {
        $output .= "; charset=".$self->config->http_charset;
    }
    $output .= "\n";
    
    # Get the feed, and the timestamp, in one go
    my ($feed_output, $feed_timestamp) = 
        $feed->make_feed( %criteria );
    my $maker = $feed->fetch_maker($feed_type);
 
    $output .= "Last-Modified: " . ($maker->parse_feed_timestamp($feed_timestamp))->strftime('%a, %d %b %Y %H:%M:%S +0000') . "\n\n";
    $output .= $feed_output;

    return $output if $return_output;
    print $output;
}

sub display_about {
    my ($self, %args) = @_;

    my $output;

    if ($args{format} && $args{format} =~ /^rdf$/i) {
        $output = qq{Content-Type: application/rdf+xml

<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns      = "http://usefulinc.com/ns/doap#"
         xmlns:rdf  = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:foaf = "http://xmlns.com/foaf/0.1/">
<Project rdf:ID="OpenGuides">
  <name>OpenGuides</name>

  <created>2003-04-29</created>
  
  <shortdesc xml:lang="en">
    A wiki engine for collaborative description of places with specialised
    geodata metadata features.
  </shortdesc>

  <description xml:lang="en">
    OpenGuides is a collaborative wiki environment, written in Perl, for 
    building guides and sharing information, as both human-readable text 
    and RDF. The engine contains a number of geodata-specific metadata 
    mechanisms such as locale search, node classification and integration 
    with Google Maps.
  </description>

  <homepage rdf:resource="http://openguides.org/" />
  <mailing-list rdf:resource="http://openguides.org/mm/listinfo/openguides-dev/" />
  <mailing-list rdf:resource="http://urchin.earth.li/mailman/listinfo/openguides-commits/" />

  <maintainer>
    <foaf:Person rdf:ID="OpenGuidesMaintainer">
      <foaf:name>Dominic Hargreaves</foaf:name>
      <foaf:homepage rdf:resource="http://www.larted.org.uk/~dom/" />
    </foaf:Person>
  </maintainer>

  <repository>
    <SVNRepository rdf:ID="OpenGuidesSVN">
      <location rdf:resource="https://urchin.earth.li/svn/openguides/" />
      <browse rdf:resource="http://dev.openguides.org/browser" />
    </SVNRepository>
  </repository>

  <release>
    <Version rdf:ID="OpenGuidesVersion">
      <revision>$VERSION</revision>
    </Version>
  </release>

  <download-page rdf:resource="http://search.cpan.org/dist/OpenGuides/" />
  
  <!-- Freshmeat category: Internet :: WWW/HTTP :: Dynamic Content -->
  <category rdf:resource="http://freshmeat.net/browse/92/" />
  
  <license rdf:resource="http://www.opensource.org/licenses/gpl-license.php" />
  <license rdf:resource="http://www.opensource.org/licenses/artistic-license.php" />

</Project>

</rdf:RDF>};
    }
    else {
        my $site_name  = $self->config->{site_name};
        my $script_name = $self->config->{script_name};
        $output = qq{Content-Type: text/html; charset=utf-8

<html>
<head>
  <title>About $site_name</title>
<style type="text/css">
body        { margin: 0px; }
#content    { padding: 50px; margin: auto; width: 50%; }
h1          { margin-bottom: 0px; font-style: italic; }
h2          { margin-top: 0px; }
#logo       { text-align: center; }
#about      { margin: 0em 0em 1em 0em; border-top: 1px solid #ddd; border-bottom: 1px solid #ddd; }
#meta       { font-size: small; text-align: center;}
</style>
<link rel="alternate"
  type="application/rdf+xml"
  title="DOAP (Description Of A Project) profile for this site's software" 
  href="$script_name?action=about;format=rdf" />
</head>
<body>
<div id="content">
<div id="logo">
<a href="http://openguides.org/"><img 
src="http://openguides.org/img/logo.png" alt="OpenGuides"></a>
<h1><a href="$script_name">$site_name</a></h1>
<h2>is powered by <a href="http://openguides.org/">OpenGuides</a> -<br>
the guides made by you.</h2>
<h3>version <a href="http://search.cpan.org/~dom/OpenGuides-$VERSION">$VERSION</a></h3>
</div>
<div id="about">
<p>
<a href="http://www.w3.org/RDF/"><img 
src="http://openguides.org/img/rdf_icon.png" width="44" height="48"
style="float: right; margin-left: 10px; border: 0px"></a> OpenGuides is a 
web-based collaborative <a href="http://wiki.org/wiki.cgi?WhatIsWiki">wiki</a> 
environment for building guides and sharing information, as both 
human-readable text and <a href="http://www.w3.org/RDF/"><acronym 
title="Resource Description Framework">RDF</acronym></a>. The engine contains 
a number of geodata-specific metadata mechanisms such as locale search, node 
classification and integration with <a href="http://maps.google.com/">Google 
Maps</a>.
</p>
<p>
OpenGuides is written in <a href="http://www.perl.org/">Perl</a>, and is
made available under the same license as Perl itself (dual <a
href="http://dev.perl.org/licenses/artistic.html" title='The "Artistic Licence"'>Artistic</a> and <a
href="http://www.opensource.org/licenses/gpl-license.php"><acronym
title="GNU Public Licence">GPL</acronym></a>). Developer information for the 
project is available from the <a href="http://dev.openguides.org/">OpenGuides 
development site</a>.
</p>
<p>
Copyright &copy;2003-2006, <a href="http://openguides.org/">The OpenGuides
Project</a>. "OpenGuides", "[The] Open Guide To..." and "The guides made by
you" are trademarks of The OpenGuides Project. Any uses on this site are made 
with permission.
</p>
</div>
<div id="meta">
<a href="$script_name?action=about;format=rdf"><acronym
title="Description Of A Project">DOAP</acronym> RDF version of this 
information</a>
</div>
</div>
</body>
</html>};
    }
    
    return $output if $args{return_output};
    print $output;
}

=item B<commit_node>

  $guide->commit_node(
                         id      => $node,
                         cgi_obj => $q,
                     );

As with other methods, parameters C<return_tt_vars> and
C<return_output> can be used to return these things instead of
printing the output to STDOUT.

The geographical data that you should provide in the L<CGI> object
depends on the handler you chose in C<wiki.conf>.

=over

=item *

B<British National Grid> - provide either C<os_x> and C<os_y> or
C<latitude> and C<longitude>; whichever set of data you give, it will
be converted to the other and both sets will be stored.

=item *

B<Irish National Grid> - provide either C<osie_x> and C<osie_y> or
C<latitude> and C<longitude>; whichever set of data you give, it will
be converted to the other and both sets will be stored.

=item *

B<UTM ellipsoid> - provide C<latitude> and C<longitude>; these will be
converted to easting and northing and both sets of data will be stored.

=back

=cut

sub commit_node {
    my ($self, %args) = @_;
    my $node = $args{id};
    my $q = $args{cgi_obj};
    my $return_output = $args{return_output};
    my $wiki = $self->wiki;
    my $config = $self->config;

    my $content  = $q->param("content");
    $content =~ s/\r\n/\n/gs;
    my $checksum = $q->param("checksum");

    my %new_metadata = OpenGuides::Template->extract_metadata_vars(
        wiki    => $wiki,
        config  => $config,
        cgi_obj => $q
    );

    delete $new_metadata{website} if $new_metadata{website} eq 'http://';

    $new_metadata{opening_hours_text} = $q->param("hours_text") || "";

    # Pick out the unmunged versions of lat/long if they're set.
    # (If they're not, it means they weren't munged in the first place.)
    $new_metadata{latitude} = delete $new_metadata{latitude_unmunged}
        if $new_metadata{latitude_unmunged};
    $new_metadata{longitude} = delete $new_metadata{longitude_unmunged}
        if $new_metadata{longitude_unmunged};

    # Check to make sure all the indexable nodes are created
    # Skip this for nodes needing moderation - this occurs for them once
    #  they've been moderated
    unless($wiki->node_required_moderation($node)) {
        $self->_autoCreateCategoryLocale(
                                          id       => $node,
                                          metadata => \%new_metadata
        );
    }
    
    foreach my $var ( qw( summary username comment edit_type ) ) {
        $new_metadata{$var} = $q->param($var) || "";
    }
    $new_metadata{host} = $ENV{REMOTE_ADDR};

    # Wiki::Toolkit::Plugin::RSS::ModWiki wants "major_change" to be set.
    $new_metadata{major_change} = ( $new_metadata{edit_type} eq "Normal edit" )
                                    ? 1
                                    : 0;

    my $written = $wiki->write_node( $node, $content, $checksum,
                                     \%new_metadata );

    if ($written) {
        my $output = $self->redirect_to_node($node);
        return $output if $return_output;
        print $output;
    } else {
        return $self->_handle_edit_conflict(
                                             id            => $node,
                                             content       => $content,
                                             new_metadata  => \%new_metadata,
                                             return_output => $return_output,
                                           );
    }
}

sub _handle_edit_conflict {
    my ($self, %args) = @_;
    my $return_output = $args{return_output} || 0;
    my $config = $self->config;
    my $wiki = $self->wiki;
    my $node = $args{id};
    my $content = $args{content};
    my %new_metadata = %{$args{new_metadata}};

    my %node_data = $wiki->retrieve_node($node);
    my %tt_vars = ( checksum       => $node_data{checksum},
                    new_content    => $content,
                    content        => $node_data{content} );
    my %old_metadata = OpenGuides::Template->extract_metadata_vars(
                                           wiki     => $wiki,
                                           config   => $config,
                                           metadata => $node_data{metadata} );
    # Make sure we look at all variables.
    my @tmp = (keys %new_metadata, keys %old_metadata );
    my %tmp_hash = map { $_ => 1; } @tmp;
    my @all_vars = keys %tmp_hash;

    foreach my $mdvar ( keys %new_metadata ) {
        if ($mdvar eq "locales") {
            $tt_vars{$mdvar} = $old_metadata{locales};
            $tt_vars{"new_$mdvar"} = $new_metadata{locale};
        } elsif ($mdvar eq "categories") {
            $tt_vars{$mdvar} = $old_metadata{categories};
            $tt_vars{"new_$mdvar"} = $new_metadata{category};
        } elsif ($mdvar eq "username" or $mdvar eq "comment"
                  or $mdvar eq "edit_type" ) {
            $tt_vars{$mdvar} = $new_metadata{$mdvar};
        } else {
            $tt_vars{$mdvar} = $old_metadata{$mdvar};
            $tt_vars{"new_$mdvar"} = $new_metadata{$mdvar};
        }
    }

    $tt_vars{coord_field_1} = $old_metadata{coord_field_1};
    $tt_vars{coord_field_2} = $old_metadata{coord_field_2};
    $tt_vars{coord_field_1_value} = $old_metadata{coord_field_1_value};
    $tt_vars{coord_field_2_value} = $old_metadata{coord_field_2_value};
    $tt_vars{"new_coord_field_1_value"}
                                = $new_metadata{$old_metadata{coord_field_1}};
    $tt_vars{"new_coord_field_2_value"}
                                = $new_metadata{$old_metadata{coord_field_2}};

    $tt_vars{conflict} = 1;
    return %tt_vars if $args{return_tt_vars};
    my $output = $self->process_template(
                                          id       => $node,
                                          template => "edit_form.tt",
                                          tt_vars  => \%tt_vars,
                                        );
    return $output if $args{return_output};
    print $output;
}

=item B<_autoCreateCategoryLocale>

  $guide->_autoCreateCategoryLocale(
                         id       => "FAQ",
                         metadata => \%metadata,
                     );

When a new node is added, or a previously un-moderated node is moderated,
identifies if any of its Categories or Locales are missing, and creates them.

Guide admins can control the text that gets put into the content field of the
autocreated node by putting it in custom_autocreate_content.tt in their custom
templates directory.  The following TT variables will be available to the
template:

=over

=item * index_type (e.g. C<Category>)

=item * index_value (e.g. C<Vegan-friendly>)

=item * node_name (e.g. C<Category Vegan-Friendly>)

=back

(Note capitalisation - index_value is what they typed in to the form, and
node_name is the fully free-upper-ed name of the autocreated node.)

For nodes not requiring moderation, should be called on writing the node
For nodes requiring moderation, should only be called on moderation

=cut

sub _autoCreateCategoryLocale {
    my ($self, %args) = @_;

    my $wiki = $self->wiki;
    my $id = $args{'id'};
    my %metadata = %{$args{'metadata'}};

    # Check to make sure all the indexable nodes are created
    my $config = $self->config;
    my $template_path = $config->template_path;
    my $custom_template_path = $config->custom_template_path || "";
    my $tt = Template->new( { INCLUDE_PATH =>
                                  "$custom_template_path:$template_path" } );

    foreach my $type (qw(Category Locale)) {
        my $lctype = lc($type);
        foreach my $index (@{$metadata{$lctype}}) {
            $index =~ s/(.*)/\u$1/;
            my $node = $type . " " . $index;
            # Uppercase the node name before checking for existence
            $node = $wiki->formatter->_do_freeupper( $node );
            unless ( $wiki->node_exists($node) ) {
                my $category = $type eq "Category" ? "Category" : "Locales";
                # Try to get the autocreated content from a custom template;
                # if we fail, use some default text.
                my $blurb;
                my %tt_vars = (
                                index_type  => $type,
                                index_value => $index,
                                node_name   => $node,
                              );
                my $ok = $tt->process( "custom_autocreate_content.tt",
                                       \%tt_vars, \$blurb );
                if ( !$ok ) {
                    $blurb = "\@INDEX_LINK [[$node]]";
                }
                $wiki->write_node(
                                     $node,
                                     $blurb,
                                     undef,
                                     {
                                         username => "Auto Create",
                                         comment  => "Auto created $lctype stub page",
                                         category => $category
                                     }
                );
            }
        }
    }
}


=item B<delete_node>

  $guide->delete_node(
                         id       => "FAQ",
                         version  => 15,
                         password => "beer",
                     );

C<version> is optional - if it isn't supplied then all versions of the
node will be deleted; in other words the node will be entirely
removed.

If C<password> is not supplied then a form for entering the password
will be displayed.

As with other methods, parameters C<return_tt_vars> and
C<return_output> can be used to return these things instead of
printing the output to STDOUT.

=cut

sub delete_node {
    my ($self, %args) = @_;
    my $node = $args{id} or croak "No node ID supplied for deletion";
    my $return_tt_vars = $args{return_tt_vars} || 0;
    my $return_output = $args{return_output} || 0;

    my %tt_vars = (
                      not_editable  => 1,
                      not_deletable => 1,
                      deter_robots  => 1,
                  );
    $tt_vars{delete_version} = $args{version} || "";

    my $password = $args{password};

    if ($password) {
        if ($password ne $self->config->admin_pass) {
            return %tt_vars if $return_tt_vars;
            my $output = $self->process_template(
                                                    id       => $node,
                                                    template => "delete_password_wrong.tt",
                                                    tt_vars  => \%tt_vars,
                                                );
            return $output if $return_output;
            print $output;
        } else {
            $self->wiki->delete_node(
                                        name    => $node,
                                        version => $args{version},
                                    );
            # Check whether any versions of this node remain.
            my %check = $self->wiki->retrieve_node( name => $node );
            $tt_vars{other_versions_remain} = 1 if $check{version};
            return %tt_vars if $return_tt_vars;
            my $output = $self->process_template(
                                                    id       => $node,
                                                    template => "delete_done.tt",
                                                    tt_vars  => \%tt_vars,
                                                );
            return $output if $return_output;
            print $output;
        }
    } else {
        return %tt_vars if $return_tt_vars;
        my $output = $self->process_template(
                                                id       => $node,
                                                template => "delete_confirm.tt",
                                                tt_vars  => \%tt_vars,
                                            );
        return $output if $return_output;
        print $output;
    }
}

=item B<set_node_moderation>

  $guide->set_node_moderation(
                         id       => "FAQ",
                         password => "beer",
                         moderation_flag => 1,
                     );

Sets the moderation needed flag on a node, either on or off.

If C<password> is not supplied then a form for entering the password
will be displayed.

=cut

sub set_node_moderation {
    my ($self, %args) = @_;
    my $node = $args{id} or croak "No node ID supplied for node moderation";
    my $return_tt_vars = $args{return_tt_vars} || 0;
    my $return_output = $args{return_output} || 0;

    # Get the moderation flag into something sane
    if($args{moderation_flag} eq "1" || $args{moderation_flag} eq "yes" ||
       $args{moderation_flag} eq "on" || $args{moderation_flag} eq "true") {
        $args{moderation_flag} = 1;
    } else {
        $args{moderation_flag} = 0;
    }

    # Set up the TT variables
    my %tt_vars = (
                      not_editable  => 1,
                      not_deletable => 1,
                      deter_robots  => 1,
                      moderation_action => 'set_moderation',
                      moderation_flag   => $args{moderation_flag},
                      moderation_url_args => 'action=set_moderation;moderation_flag='.$args{moderation_flag},
                  );

    my $password = $args{password};

    if ($password) {
        if ($password ne $self->config->admin_pass) {
            return %tt_vars if $return_tt_vars;
            my $output = $self->process_template(
                                                    id       => $node,
                                                    template => "moderate_password_wrong.tt",
                                                    tt_vars  => \%tt_vars,
                                                );
            return $output if $return_output;
            print $output;
        } else {
            my $worked = $self->wiki->set_node_moderation(
                                        name    => $node,
                                        required => $args{moderation_flag},
                         );
            my $moderation_flag = "changed";
            unless($worked) {
                $moderation_flag = "unknown_node";
                warn("Tried to set moderation status on node '$node', which doesn't exist");
            }

            # Send back to the admin interface
            my $script_url = $self->config->script_url;
            my $script_name = $self->config->script_name;
            my $q = CGI->new;
            my $output = $q->redirect( $script_url.$script_name."?action=admin;moderation=".$moderation_flag );
            return $output if $return_output;
            print $output;
        }
    } else {
        return %tt_vars if $return_tt_vars;
        my $output = $self->process_template(
                                                id       => $node,
                                                template => "moderate_confirm.tt",
                                                tt_vars  => \%tt_vars,
                                            );
        return $output if $return_output;
        print $output;
    }
}

=item B<moderate_node>

  $guide->moderate_node(
                         id       => "FAQ",
                         version  => 12,
                         password => "beer",
                     );

Marks a version of a node as moderated. Will also auto-create and Locales
and Categories for the newly moderated version.

If C<password> is not supplied then a form for entering the password
will be displayed.

=cut

sub moderate_node {
    my ($self, %args) = @_;
    my $node = $args{id} or croak "No node ID supplied for node moderation";
    my $version = $args{version} or croak "No node version supplied for node moderation";
    my $return_tt_vars = $args{return_tt_vars} || 0;
    my $return_output = $args{return_output} || 0;

    # Set up the TT variables
    my %tt_vars = (
                      not_editable  => 1,
                      not_deletable => 1,
                      deter_robots  => 1,
                      version       => $version,
                      moderation_action => 'moderate',
                      moderation_url_args => 'action=moderate;version='.$version
                  );

    my $password = $args{password};
    unless($self->config->moderation_requires_password) {
        $password = $self->config->admin_pass;
    }

    if ($password) {
        if ($password ne $self->config->admin_pass) {
            return %tt_vars if $return_tt_vars;
            my $output = $self->process_template(
                                                    id       => $node,
                                                    template => "moderate_password_wrong.tt",
                                                    tt_vars  => \%tt_vars,
                                                );
            return $output if $return_output;
            print $output;
        } else {
            $self->wiki->moderate_node(
                                        name    => $node,
                                        version => $version
                                    );

            # Create any categories or locales for it
            my %details = $self->wiki->retrieve_node(
                                        name    => $node,
                                        version => $version
                                    );
            $self->_autoCreateCategoryLocale(
                                          id       => $node,
                                          metadata => $details{'metadata'}
            );

            # Send back to the admin interface
            my $script_url = $self->config->script_url;
            my $script_name = $self->config->script_name;
            my $q = CGI->new;
            my $output = $q->redirect( $script_url.$script_name."?action=admin;moderation=moderated" );
            return $output if $return_output;
            print $output;
        }
    } else {
        return %tt_vars if $return_tt_vars;
        my $output = $self->process_template(
                                                id       => $node,
                                                template => "moderate_confirm.tt",
                                                tt_vars  => \%tt_vars,
                                            );
        return $output if $return_output;
        print $output;
    }
}

=item B<show_missing_metadata>

Search for nodes which don't have a certain kind of metadata. Optionally
also excludes Locales and Categories

=cut

sub show_missing_metadata {
    my ($self, %args) = @_;
    my $return_tt_vars = $args{return_tt_vars} || 0;
    my $return_output = $args{return_output} || 0;

    my $wiki = $self->wiki;
    my $formatter = $self->wiki->formatter;
    my $script_name = $self->config->script_name;

    my ($metadata_type, $metadata_value, $exclude_locales, $exclude_categories)
        = @args{ qw( metadata_type metadata_value exclude_locales exclude_categories ) };

    my @nodes;
    my $done_search = 0;

    # Only search if they supplied at least a metadata type
    if($metadata_type) {
        $done_search = 1;
        @nodes = $wiki->list_nodes_by_missing_metadata(
                            metadata_type => $metadata_type,
                            metadata_value => $metadata_value,
                            ignore_case    => 1,
        );

        # Do we need to filter some nodes out?
        if($exclude_locales || $exclude_categories) {
            my @all_nodes = @nodes;
            @nodes = ();

            foreach my $node (@all_nodes) {
                if($exclude_locales && $node =~ /^Locale /) { next; }
                if($exclude_categories && $node =~ /^Category /) { next; }
                push @nodes, $node;
            }
        }
    }

    # Build nice edit etc links for our nodes
    my @tt_nodes;
    for my $node (@nodes) {
        my %n;

        # Make the URLs
        my $node_param = uri_escape( $formatter->node_name_to_node_param( $node ) );

        # Save into the hash
        $n{'name'} = $node;
        $n{'view_url'} = $script_name . "?id=" . $node_param;
        $n{'edit_url'} = $script_name . "?id=" . $node_param . ";action=edit";
        push @tt_nodes, \%n;
    }

    # Set up our TT variables, including the search parameters
    my %tt_vars = (
                      not_editable  => 1,
                      not_deletable => 1,
                      deter_robots  => 1,

                      nodes => \@tt_nodes,
                      done_search    => $done_search,
                      metadata_type  => $metadata_type,
                      metadata_value => $metadata_value,
                      exclude_locales => $exclude_locales,
                      exclude_categories => $exclude_categories,

                      script_name => $script_name
                  );
    return %tt_vars if $return_tt_vars;

    # Render to the page
    my $output = $self->process_template(
                                           id       => "",
                                           template => "missing_metadata.tt",
                                           tt_vars  => \%tt_vars,
                                        );
    return $output if $return_output;
    print $output;
}

=item B<revert_user_interface>

If C<password> is not supplied then a form for entering the password
will be displayed, along with a list of all the edits the user made.

If the password is given, will delete all of these versions.
=cut
sub revert_user_interface {
    my ($self, %args) = @_;

    my $password = $args{password} || '';
    my $return_tt_vars = $args{return_tt_vars} || 0;
    my $return_output = $args{return_output} || 0;

    my $wiki = $self->wiki;
    my $formatter = $self->wiki->formatter;
    my $script_name = $self->config->script_name;

    my ($type,$value);
    if($args{'username'}) {
        ($type,$value) = ('username', $args{'username'});
    }
    if($args{'host'}) {
        ($type,$value) = ('host', $args{'host'});
    }
    unless($type && $value) {
        croak("One of username or host must be given");
    }

    # Grab everything they've touched, ever
    my @user_edits = $self->wiki->list_recent_changes(
                            since => 1,
                            metadata_was => { $type => $value },
    );

    if ($password) {
        if ($password ne $self->config->admin_pass) {
            croak("Bad password supplied");
        } else {
            # Delete all these versions
            foreach my $edit (@user_edits) {
                $self->wiki->delete_node(
                                name => $edit->{name},
                                version => $edit->{version},
                );
            }

            # Grab new list
            @user_edits = $self->wiki->list_recent_changes(
                            since => 1,
                            metadata_was => { $type => $value },
            );
        }
    } else {
        # Don't do anything
    }

    # Set up our TT variables, including the search parameters
    my %tt_vars = (
                      not_editable  => 1,
                      not_deletable => 1,
                      deter_robots  => 1,

                      edits          => \@user_edits,
                      username       => $args{username},
                      host           => $args{host},
                      by_type        => $type,
                      by             => $value,

                      script_name => $script_name
                  );
    return %tt_vars if $return_tt_vars;

    # Render to the page
    my $output = $self->process_template(
                                           id       => "",
                                           template => "admin_revert_user.tt",
                                           tt_vars  => \%tt_vars,
                                        );
    return $output if $return_output;
    print $output;
}

=item B<display_admin_interface>

Fetch everything we need to display the admin interface, and passes it off 
 to the template

=cut

sub display_admin_interface {
    my ($self, %args) = @_;
    my $return_tt_vars = $args{return_tt_vars} || 0;
    my $return_output = $args{return_output} || 0;

    my $wiki = $self->wiki;
    my $formatter = $self->wiki->formatter;
    my $script_name = $self->config->script_name;

    # Grab all the recent nodes
    my @all_nodes = $wiki->list_recent_changes(last_n_changes => 100);

    # Split into nodes, Locales and Categories
    my @nodes;
    my @categories;
    my @locales;
    for my $node (@all_nodes) {
        # Add moderation status
        $node->{'moderate'} = $wiki->node_required_moderation($node->{'name'});

        # Make the URLs
        my $node_param = uri_escape( $formatter->node_name_to_node_param( $node->{'name'} ) );
        $node->{'view_url'} = $script_name . "?id=" . $node_param;
        $node->{'versions_url'} = $script_name .
                        "?action=list_all_versions;id=" . $node_param;
        $node->{'moderation_url'} = $script_name .
                        "?action=set_moderation;id=" . $node_param;
        $node->{'revert_user_url'} = $script_name . "?action=revert_user" .
                        ";username=".$node->{metadata}->{username}->[0];

        # Filter
        if($node->{'name'} =~ /^Category /) {
            $node->{'page_name'} = $node->{'name'};
            $node->{'name'} =~ s/^Category //;
            push @categories, $node;
        } elsif($node->{'name'} =~ /^Locale /) {
            $node->{'page_name'} = $node->{'name'};
            $node->{'name'} =~ s/^Locale //;
            push @locales, $node;
        } else {
            push @nodes, $node;
        }
    }

    # Handle completed notice for actions
    my $completed_action = "";
    if($args{moderation_completed}) {
        if($args{moderation_completed} eq "moderation") {
            $completed_action = "Version moderated";
        }
        if($args{moderation_completed} eq "changed") {
            $completed_action = "Node moderation flag changed";
        }
        if($args{moderation_completed} eq "unknown_node") {
            $completed_action = "Node moderation flag not changed, node not known";
        }
    }

    # Render in a template
    my %tt_vars = (
                      not_editable  => 1,
                      not_deletable => 1,
                      deter_robots  => 1,
                      nodes      => \@nodes,
                      categories => \@categories,
                      locales    => \@locales,
                      completed_action => $completed_action
                  );
    return %tt_vars if $return_tt_vars;
    my $output = $self->process_template(
                                           id       => "",
                                           template => "admin_home.tt",
                                           tt_vars  => \%tt_vars,
                                        );
    return $output if $return_output;
    print $output;
}

sub process_template {
    my ($self, %args) = @_;
    my %output_conf = (
                          wiki     => $self->wiki,
                          config   => $self->config,
                          node     => $args{id},
                          template => $args{template},
                          vars     => $args{tt_vars},
                          cookies  => $args{cookies},
                      );
    if ( $args{content_type} ) {
        $output_conf{content_type} = $args{content_type};
    }
    return OpenGuides::Template->output( %output_conf );
}

sub redirect_to_node {
    my ($self, $node, $redirected_from) = @_;
    
    my $script_url = $self->config->script_url;
    my $script_name = $self->config->script_name;
    my $formatter = $self->wiki->formatter;

    my $id = $formatter->node_name_to_node_param( $node );
    my $oldid;
    $oldid = $formatter->node_name_to_node_param( $redirected_from ) if $redirected_from;

    my $redir_param = "$script_url$script_name?";
    $redir_param .= 'id=' if $oldid;
    $redir_param .= $id;
    $redir_param .= ";oldid=$oldid" if $oldid;
    
    my $q = CGI->new;
    return $q->redirect( $redir_param );
}

sub get_cookie {
    my $self = shift;
    my $config = $self->config;
    my $pref_name = shift or return "";
    my %cookie_data = OpenGuides::CGI->get_prefs_from_cookie(config=>$config);
    return $cookie_data{$pref_name};
}


=head1 BUGS AND CAVEATS

UTF8 data are currently not handled correctly throughout.

Other bugs are documented at
L<http://dev.openguides.org/>

=head1 SEE ALSO

=over 4

=item * L<http://london.openguides.org/|The Open Guide to London>, the first and biggest OpenGuides site.

=item * L<http://openguides.org/|The OpenGuides website>, with a list of all live OpenGuides installs.

=item * L<Wiki::Toolkit>, the Wiki toolkit which does the heavy lifting for OpenGuides

=back

=head1 FEEDBACK

If you have a question, a bug report, or a patch, or you're interested
in joining the development team, please contact openguides-dev@lists.openguides.org
(moderated mailing list, will reach all current developers but you'll have
to wait for your post to be approved) or file a bug report at
L<http://dev.openguides.org/>

=head1 AUTHOR

The OpenGuides Project (openguides-dev@lists.openguides.org)

=head1 COPYRIGHT

     Copyright (C) 2003-2006 The OpenGuides Project.  All Rights Reserved.

The OpenGuides distribution is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 CREDITS

Programming by Dominic Hargreaves, Earle Martin, Kake Pugh, and Ivor
Williams.  Testing and bug reporting by Billy Abbott, Jody Belka,
Kerry Bosworth, Simon Cozens, Cal Henderson, Steve Jolly, and Bob
Walker (among others).  Much of the Module::Build stuff copied from
the Siesta project L<http://siesta.unixbeard.net/>

=cut

1;
