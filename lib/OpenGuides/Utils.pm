package OpenGuides::Utils;

use strict;
use vars qw( $VERSION );
$VERSION = '0.09';

use Carp qw( croak );
use Wiki::Toolkit;
use Wiki::Toolkit::Formatter::UseMod;
use Wiki::Toolkit::Plugin::RSS::Reader;
use URI::Escape;

=head1 NAME

OpenGuides::Utils - General utility methods for OpenGuides scripts.

=head1 DESCRIPTION

Provides general utility methods for OpenGuides scripts.  Distributed
and installed as part of the OpenGuides project, not intended for
independent installation.  This documentation is probably only useful
to OpenGuides developers.

=head1 SYNOPSIS

  use OpenGuide::Config;
  use OpenGuides::Utils;

  my $config = OpenGuides::Config->new( file => "wiki.conf" );
  my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

=head1 METHODS

=over 4

=item B<make_wiki_object>

  my $config = OpenGuides::Config->new( file => "wiki.conf" );
  my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

Croaks unless an C<OpenGuides::Config> object is supplied.  Returns a
C<Wiki::Toolkit> object made from the given config file on success,
croaks if any other error occurs.

The config file needs to define at least the following variables:

=over

=item *

dbtype - one of C<postgres>, C<mysql> and C<sqlite>

=item *

dbname

=item *

indexing_directory - for the L<Search::InvertedIndex> or L<Plucene> files to go

=back

=cut

sub make_wiki_object {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config param supplied";
    croak "config param isn't an OpenGuides::Config object"
	unless UNIVERSAL::isa( $config, "OpenGuides::Config" );

    # Require in the right database module.
    my $dbtype = $config->dbtype;

    my %wiki_toolkit_exts = (
                          postgres => "Pg",
		          mysql    => "MySQL",
                          sqlite   => "SQLite",
                        );

    my $wiki_toolkit_module = "Wiki::Toolkit::Store::" . $wiki_toolkit_exts{$dbtype};
    eval "require $wiki_toolkit_module";
    croak "Can't 'require' $wiki_toolkit_module.\n" if $@;

    # Make store.
    my $store = $wiki_toolkit_module->new(
        dbname  => $config->dbname,
        dbuser  => $config->dbuser,
        dbpass  => $config->dbpass,
        dbhost  => $config->dbhost,
        dbport  => $config->dbport,
        charset => $config->dbencoding,
    );

    # Make search.
    my $search;
    if ( $config->use_plucene
         && ( lc($config->use_plucene) eq "y"
              || $config->use_plucene == 1 )
       ) {
        require Wiki::Toolkit::Search::Plucene;
        $search = Wiki::Toolkit::Search::Plucene->new(
                                       path => $config->indexing_directory,
                                                 );
    } else {
        require Wiki::Toolkit::Search::SII;
        require Search::InvertedIndex::DB::DB_File_SplitHash;
        my $indexdb = Search::InvertedIndex::DB::DB_File_SplitHash->new(
            -map_name  => $config->indexing_directory,
            -lock_mode => "EX"
        );
        $search = Wiki::Toolkit::Search::SII->new( indexdb => $indexdb );
    }

    # Make formatter.
    my $script_name = $config->script_name;
    my $search_url = $config->script_url . "search.cgi";

    my %macros = (
        '@SEARCHBOX' =>
            qq(<form action="$search_url" method="get"><input type="text" size="20" name="search"><input type="submit" name="Go" value="Search"></form>),
        qr/\@INDEX_LINK\s+\[\[(Category|Locale)\s+([^\]|]+)\|?([^\]]+)?\]\]/ =>
            sub {
                  # We may be being called by Wiki::Toolkit::Plugin::Diff,
                  # which doesn't know it has to pass us $wiki - and
                  # we don't use it anyway.
                  if ( UNIVERSAL::isa( $_[0], "Wiki::Toolkit" ) ) {
                      shift; # just throw it away
                  }
                  my $link_title = $_[2] || "View all pages in $_[0] $_[1]";
                  return qq(<a href="$script_name?action=index;index_type=) . uri_escape(lc($_[0])) . qq(;index_value=) . uri_escape($_[1]) . qq(">$link_title</a>);
                },
        qr/\@INDEX_LIST\s+\[\[(Category|Locale)\s+([^\]]+)]]/ =>
             sub {
                   my ($wiki, $type, $value) = @_;

                   # We may be being called by Wiki::Toolkit::Plugin::Diff,
                   # which doesn't know it has to pass us $wiki
                   unless ( UNIVERSAL::isa( $wiki, "Wiki::Toolkit" ) ) {
                       return "(unprocessed INDEX_LIST macro)";
		   }

                   my @nodes = sort $wiki->list_nodes_by_metadata(
                       metadata_type  => $type,
                       metadata_value => $value,
                       ignore_case    => 1,
                   );
                   unless ( scalar @nodes ) {
                       return "\n* No pages currently in "
                              . lc($type) . " $value\n";
                   }
                   my $return = "\n";
                   foreach my $node ( @nodes ) {
                       $return .= "* "
                               . $wiki->formatter->format_link(
                                                                wiki => $wiki,
                                                                link => $node,
                                                              )
                                . "\n";
	           }
                   return $return;
                 },
        qr/\@MAP_LINK\s+\[\[(Category|Locale)\s+([^\]|]+)\|?([^\]]+)?\]\]/ =>
                sub {
                      if ( UNIVERSAL::isa( $_[0], "Wiki::Toolkit" ) ) {
                          shift; # don't need $wiki
                      }
                      my $link_title = $_[2]
                                       || "View map of pages in $_[0] $_[1]";
                      return qq(<a href="$script_name?action=index;format=map;index_type=) . uri_escape(lc($_[0])) . qq(;index_value=) . uri_escape($_[1]) . qq(">$link_title</a>);
                },
        qr/\@RANDOM_PAGE_LINK(?:\s+\[\[(Category|Locale)\s+([^\]|]+)\|?([^\]]+)?\]\])?/ =>
                sub {
                      if ( UNIVERSAL::isa( $_[0], "Wiki::Toolkit" ) ) {
                          shift; # don't need $wiki
                      }
                      my ( $type, $value, $link_title ) = @_;
                      my $link = "$script_name?action=random";

                      if ( $type && $value ) {
                          $link .= ";" . lc( uri_escape( $type ) ) . "="
                                . lc( uri_escape( $value ) );
                          $link_title ||= "View a random page in $type $value";
                      } else {
                          $link_title ||= "View a random page on this guide";
                      }
                      return qq(<a href="$link">$link_title</a>);
                },
        qr/\@INCLUDE_NODE\s+\[\[([^\]|]+)\]\]/ => 
            sub {
                  my ($wiki, $node) = @_;
                  my %node_data = $wiki->retrieve_node( $node );
                  return $node_data{content};
                },
	qr/\@RSS\s+(.+)/ => sub {
                    # We may be being called by Wiki::Toolkit::Plugin::Diff,
                    # which doesn't know it has to pass us $wiki - and
                    # we don't use it anyway.
                    if ( UNIVERSAL::isa( $_[0], "Wiki::Toolkit" ) ) {
                        shift; # just throw it away
                    }

                    my $url = shift;

                    # The URL will already have been processed as an inline
                    # link, so transform it back again.
                    if ( $url =~ m/href="([^"]+)/ ) {
                        $url = $1;
                    }

                    my $rss = Wiki::Toolkit::Plugin::RSS::Reader->new(url => $url);
                    my @items = $rss->retrieve;

                    # Ten items only at this till.
                    $#items = 10 if $#items > 10;

                    # Make a UseMod-formatted list with them - macros are
                    # processed *before* UseMod formatting is applied but
                    # *after* inline links like [http://foo/ bar]
                    my $list = "\n";
                    foreach (@items) {
                        my $link        = $_->{link};
                        my $title       = $_->{title};
                        my $description = $_->{description};
                        $list .= qq{* <a href="$link">$title</a>};
                        $list .= " - $description" if $description;
                        $list .= "\n";
                    }
                    $list .= "</ul>\n";
        },
    );

    my $formatter = Wiki::Toolkit::Formatter::UseMod->new(
        extended_links      => 1,
        implicit_links      => 0,
        allowed_tags        => [qw(a p b strong i em pre small img table td
                                   tr th br hr ul li center blockquote kbd
                                   div code strike sub sup font)],
        macros              => \%macros,
        pass_wiki_to_macros => 1,
        node_prefix         => "$script_name?",
        edit_prefix         => "$script_name?action=edit;id=",
        munge_urls          => 1,
    );

    my %conf = ( store     => $store,
                 search    => $search,
                 formatter => $formatter );

    my $wiki = Wiki::Toolkit->new( %conf );
    return $wiki;
}

=item B<get_wgs84_coords>

Returns coordinate data suitable for use with Google Maps (and other GIS
systems that assume WGS-84 data).

    my ($wgs84_long, $wgs84_lat) = OpenGuides::Utils->get_wgs84_coords(
                                        longitude => $longitude,
                                        latitude => $latitude,
                                        config => $config
                                   );

=cut

sub get_wgs84_coords {
    my ($self, %args) = @_;
    my ($longitude, $latitude, $config) = ($args{longitude}, $args{latitude},
                                           $args{config})
       or croak "No longitude supplied to get_wgs84_coords";
    croak "geo_handler not defined!" unless $config->geo_handler;

    if ($config->force_wgs84) {
        # Only as a rough approximation, good enough for large scale guides
        return ($longitude, $latitude);
    }

    # If we don't have a lat and long, return undef right away
    unless($args{longitude} || $args{latitude}) {
        return undef;
    }

    # Try to load a provider of Helmert Transforms
    my $helmert;
    # First up, try the MySociety Geo::HelmertTransform
    unless($helmert) {
        eval {
            require Geo::HelmertTransform;
            $helmert = sub($$$) {
                my ($datum,$oldlat,$oldlong) = @_;
                if ($datum eq 'Airy') {
                    $datum = 'Airy1830';
                }
                my $datum_helper = new Geo::HelmertTransform::Datum(Name=>$datum);
                my $wgs84_helper = new Geo::HelmertTransform::Datum(Name=>'WGS84');
                unless($datum_helper) {
                    croak("No convertion helper for datum '$datum'");
                    return undef;
                }

                my ($lat,$long,$h) = 
                    Geo::HelmertTransform::convert_datum($datum_helper,$wgs84_helper,$oldlat,$oldlong,0);
                return ($long,$lat);
            };
        };
    }
    # Give up, return undef
    unless($helmert) {
       return undef; 
    }
    

    if ($config->geo_handler == 1) {
        # Do conversion here
        return &$helmert('Airy1830',$latitude,$longitude);
    } elsif ($config->geo_handler == 2) {
        # Do conversion here
        return &$helmert('Airy1830Modified',$latitude,$longitude);
    } elsif ($config->geo_handler == 3) {
        if ($config->ellipsoid eq "WGS-84") {
            return ($longitude, $latitude);
        } else {
            # Do conversion here
            return &$helmert($config->ellipsoid,$latitude,$longitude);
        }
    } else {
        croak "Invalid geo_handler config option $config->geo_handler";
    }
}

=item B<detect_redirect>

    $redir = OpenGuides::Utils->detect_redirect( content => "foo" );

Checks the content of a node to see if the node is a redirect to another
node.  If so, returns the name of the node that this one redirects to.  If
not, returns false.

(Also returns false if no content is provided.)

=cut

sub detect_redirect {
    my ( $self, %args ) = @_;
    return unless $args{content};

    if ( $args{content} =~ /^#REDIRECT\s+(.+?)\s*$/ ) {
        my $redirect = $1;

        # Strip off enclosing [[ ]] in case this is an extended link.
        $redirect =~ s/^\[\[//;
        $redirect =~ s/\]\]\s*$//;

        return $redirect;
    }
}

=back

=head1 AUTHOR

The OpenGuides Project (openguides-dev@lists.openguides.org)

=head1 COPYRIGHT

     Copyright (C) 2003-2007 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
