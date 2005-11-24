package OpenGuides;
use strict;

use Carp "croak";
use CGI;
use CGI::Wiki::Plugin::Diff;
use CGI::Wiki::Plugin::Locator::Grid;
use OpenGuides::CGI;
use OpenGuides::Template;
use OpenGuides::Utils;
use Time::Piece;
use URI::Escape;

use vars qw( $VERSION );

$VERSION = '0.51';

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
        $locator = CGI::Wiki::Plugin::Locator::Grid->new(
                                             x => "os_x",    y => "os_y" );
    } elsif ( $geo_handler == 2 ) {
        $locator = CGI::Wiki::Plugin::Locator::Grid->new(
                                             x => "osie_x",  y => "osie_y" );
    } else {
        $locator = CGI::Wiki::Plugin::Locator::Grid->new(
                                             x => "easting", y => "northing" );
    }
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

An accessor, returns the underlying L<OpenGuides::Config> object.

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

    if ( $id =~ /^(Category|Locale) (.*)$/ ) {
        my $type = $1;
        $tt_vars{is_indexable_node} = 1;
        $tt_vars{index_type} = lc($type);
        $tt_vars{index_value} = $2;
        $tt_vars{"rss_".lc($type)."_url"} =
                           $config->script_name . "?action=rc;format=rss;"
                           . lc($type) . "=" . lc(CGI->escape($2));
    }

    my %current_data = $wiki->retrieve_node( $id );
    my $current_version = $current_data{version};
    undef $version if ($version && $version == $current_version);
    my %criteria = ( name => $id );
    $criteria{version} = $version if $version; # retrieve_node default is current

    my %node_data = $wiki->retrieve_node( %criteria );

    # Fixes passing undefined values to Text::Wikiformat if node doesn't exist.
    my $raw        = $node_data{content} || " ";
    my $content    = $wiki->format($raw);
    my $modified   = $node_data{last_modified};
    my %metadata   = %{$node_data{metadata}};

    if ($args{format} && $args{format} eq 'raw') {
      print "Content-Type: text/plain\n\n";
      print $raw;
      exit 0;
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
                   oldid         => $oldid,
               );

    if ( $raw =~ /^#REDIRECT\s+(.+?)\s*$/ ) {
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
            exit 0;
        }
    }

    # We've undef'ed $version above if this is the current version.
    $tt_vars{current} = 1 unless $version;

    if ($id eq "RecentChanges") {
        $self->display_recent_changes(%args);
    } elsif ( $id eq $self->config->home_name ) {
        my @recent = $wiki->list_recent_changes(
            last_n_changes => 10,
            metadata_was   => { edit_type => "Normal edit" },
        );
        @recent = map {
                          {
                              name          => CGI->escapeHTML($_->{name}),
                              last_modified => CGI->escapeHTML($_->{last_modified}),
                              version       => CGI->escapeHTML($_->{version}),
                              comment       => CGI->escapeHTML($_->{metadata}{comment}[0]),
                              username      => CGI->escapeHTML($_->{metadata}{username}[0]),
                              url           => $config->script_name . "?"
                                               . CGI->escape($wiki->formatter->node_name_to_node_param($_->{name}))
                          }
                      } @recent;
        $tt_vars{recent_changes} = \@recent;
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
    print CGI->redirect( $script_url . "search.cgi?lat=$lat;long=$long;distance_in_metres=$metres" );
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

    $tt_vars{nodes} = \@nodes;

    my ($template, %conf);

    if ( $args{format} ) {
        if ( $args{format} eq "rdf" ) {
            $template = "rdf_index.tt";
            $conf{content_type} = "text/plain";
        }
        elsif ( $args{format} eq "plain" ) {
            $template = "plain_index.tt";
            $conf{content_type} = "text/plain";
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

=item B<display_rss>

  # Last ten non-minor edits to Hammersmith pages.
  $guide->display_rss(
                         items              => 10,
                         ignore_minor_edits => 1,
                         locale             => "Hammersmith",
                     );

  # All edits bob has made to pub pages in the last week.
  $guide->display_rss(
                         days     => 7,
                         username => "bob",
                         category => "Pubs",
                     );

As with other methods, the C<return_output> parameter can be used to
return the output instead of printing it to STDOUT.

=cut

sub display_rss {
    my ($self, %args) = @_;

    my $return_output = $args{return_output} ? 1 : 0;

    my $items = $args{items} || "";
    my $days  = $args{days}  || "";
    my $ignore_minor_edits = $args{ignore_minor_edits} ? 1 : 0;
    my $username = $args{username} || "";
    my $category = $args{category} || "";
    my $locale   = $args{locale}   || "";
    my %criteria = (
                       items              => $items,
                       days               => $days,
                       ignore_minor_edits => $ignore_minor_edits,
                   );
    my %filter;
    $filter{username} = $username if $username;
    $filter{category} = $category if $category;
    $filter{locale}   = $locale   if $locale;
    if ( scalar keys %filter ) {
        $criteria{filter_on_metadata} = \%filter;
    }

    my $rdf_writer = OpenGuides::RDF->new(
                                             wiki       => $self->wiki,
                                             config     => $self->config,
                                             og_version => $VERSION,
                                         );
    my $output = "Content-Type: text/plain\n";
    $output .= "Last-Modified: " . $rdf_writer->rss_timestamp( %criteria ) . "\n\n";
    $output .= $rdf_writer->make_recentchanges_rss( %criteria );
    return $output if $return_output;
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

    my %metadata = OpenGuides::Template->extract_metadata_vars(
        wiki    => $wiki,
        config  => $config,
    cgi_obj => $q
    );

    $metadata{opening_hours_text} = $q->param("hours_text") || "";

    # Pick out the unmunged versions of lat/long if they're set.
    # (If they're not, it means they weren't munged in the first place.)
    $metadata{latitude} = delete $metadata{latitude_unmunged}
        if $metadata{latitude_unmunged};
    $metadata{longitude} = delete $metadata{longitude_unmunged}
        if $metadata{longitude_unmunged};

    # Check to make sure all the indexable nodes are created
    foreach my $type (qw(Category Locale)) {
        my $lctype = lc($type);
        foreach my $index (@{$metadata{$lctype}}) {
            $index =~ s/(.*)/\u$1/;
            my $node = $type . " " . $index;
            # Uppercase the node name before checking for existence
            $node =~ s/ (\S+)/ \u$1/g;
            unless ( $wiki->node_exists($node) ) {
                my $category = $type eq "Category" ? "Category" : "Locales";
                $wiki->write_node(
                                     $node,
                                     "\@INDEX_LINK [[$node]]",
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
    
    foreach my $var ( qw( summary username comment edit_type ) ) {
        $metadata{$var} = $q->param($var) || "";
    }
    $metadata{host} = $ENV{REMOTE_ADDR};

    # CGI::Wiki::Plugin::RSS::ModWiki wants "major_change" to be set.
    $metadata{major_change} = ( $metadata{edit_type} eq "Normal edit" )
                            ? 1
                            : 0;

    my $written = $wiki->write_node($node, $content, $checksum, \%metadata );

    if ($written) {
        my $output = $self->redirect_to_node($node);
        return $output if $return_output;
        print $output;
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
        return %tt_vars if $args{return_tt_vars};
        my $output = $self->process_template(
                                              id       => $node,
                                              template => "edit_conflict.tt",
                                              tt_vars  => \%tt_vars,
                                            );
        return $output if $args{return_output};
        print $output;
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
        $output_conf{content_type} = "";
        my $output = "Content-Type: $args{content_type}\n\n"
                     . OpenGuides::Template->output( %output_conf );
    } else {
        return OpenGuides::Template->output( %output_conf );
    }
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

    return CGI->redirect( $redir_param );
}

sub get_cookie {
    my $self = shift;
    my $config = $self->config;
    my $pref_name = shift or return "";
    my %cookie_data = OpenGuides::CGI->get_prefs_from_cookie(config=>$config);
    return $cookie_data{$pref_name};
}


=back

=head1 BUGS AND CAVEATS

UTF8 data are currently not handled correctly throughout.

Other bugs are documented at
L<http://dev.openguides.org/>

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
to wait for your post to be approved) or file a bug report at
L<http://dev.openguides.org/>

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

     Copyright (C) 2003-2005 The OpenGuides Project.  All Rights Reserved.

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
