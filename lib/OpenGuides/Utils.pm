package OpenGuides::Utils;

use strict;
use vars qw( $VERSION );
$VERSION = '0.08';

use Carp qw( croak );
use CGI::Wiki;
use CGI::Wiki::Formatter::UseMod;
use CGI::Wiki::Plugin::RSS::Reader;
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
C<CGI::Wiki> object made from the given config file on success,
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

    my %cgi_wiki_exts = (
                          postgres => "Pg",
		          mysql    => "MySQL",
                          sqlite   => "SQLite",
                        );

    my $cgi_wiki_module = "CGI::Wiki::Store::" . $cgi_wiki_exts{$dbtype};
    eval "require $cgi_wiki_module";
    croak "Can't 'require' $cgi_wiki_module.\n" if $@;

    # Make store.
    my $store = $cgi_wiki_module->new(
        dbname => $config->dbname,
        dbuser => $config->dbuser,
        dbpass => $config->dbpass,
        dbhost => $config->dbhost,
    );

    # Make search.
    my $search;
    if ( $config->use_plucene
         && ( lc($config->use_plucene) eq "y"
              || $config->use_plucene == 1 )
       ) {
        require CGI::Wiki::Search::Plucene;
        $search = CGI::Wiki::Search::Plucene->new(
                                       path => $config->indexing_directory,
                                                 );
    } else {
        require CGI::Wiki::Search::SII;
        require Search::InvertedIndex::DB::DB_File_SplitHash;
        my $indexdb = Search::InvertedIndex::DB::DB_File_SplitHash->new(
            -map_name  => $config->indexing_directory,
            -lock_mode => "EX"
        );
        $search = CGI::Wiki::Search::SII->new( indexdb => $indexdb );
    }

    # Make formatter.
    my $script_name = $config->script_name;
    my $search_url = $config->script_url . "supersearch.cgi";

    my %macros = (
        '@SEARCHBOX' =>
            qq(<form action="$search_url" method="get"><input type="text" size="20" name="search"><input type="submit" name="Go" value="Search"></form>),
        qr/\@INDEX_LINK\s+\[\[(Category|Locale)\s+([^\]|]+)\|?([^\]]+)?\]\]/ =>
            sub {
                  # We may be being called by CGI::Wiki::Plugin::Diff,
                  # which doesn't know it has to pass us $wiki - and
                  # we don't use it anyway.
                  if ( UNIVERSAL::isa( $_[0], "CGI::Wiki" ) ) {
                      shift; # just throw it away
                  }
                  my $link_title = $_[2] || "View all pages in $_[0] $_[1]";
                  return qq(<a href="$script_name?action=index;index_type=) . uri_escape(lc($_[0])) . qq(;index_value=) . uri_escape($_[1]) . qq(">$link_title</a>);
                },
        qr/\@INDEX_LIST\s+\[\[(Category|Locale)\s+([^\]]+)]]/ =>
             sub {
                   my ($wiki, $type, $value) = @_;

                   # We may be being called by CGI::Wiki::Plugin::Diff,
                   # which doesn't know it has to pass us $wiki
                   unless ( UNIVERSAL::isa( $wiki, "CGI::Wiki" ) ) {
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
	qr/\@RSS\s+(.+)/ => sub {
                    # We may be being called by CGI::Wiki::Plugin::Diff,
                    # which doesn't know it has to pass us $wiki - and
                    # we don't use it anyway.
                    if ( UNIVERSAL::isa( $_[0], "CGI::Wiki" ) ) {
                        shift; # just throw it away
                    }

                    my $url = shift;

                    # The URL will already have been processed as an inline
                    # link, so transform it back again.
                    if ( $url =~ m/href="([^"]+)/ ) {
                        $url = $1;
                    }

                    my $rss = CGI::Wiki::Plugin::RSS::Reader->new(url => $url);
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

    my $formatter = CGI::Wiki::Formatter::UseMod->new(
        extended_links      => 1,
        implicit_links      => 0,
        allowed_tags        => [qw(a p b strong i em pre small img table td
                                   tr th br hr ul li center blockquote kbd
                                   div code strike sub sup font)],
        macros              => \%macros,
        pass_wiki_to_macros => 1,
        node_prefix         => "$script_name?",
        edit_prefix         => "$script_name?action=edit&id=",
        munge_urls          => 1,
    );

    my %conf = ( store     => $store,
                 search    => $search,
                 formatter => $formatter );

    my $wiki = CGI::Wiki->new( %conf );
    return $wiki;
}


=back

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

     Copyright (C) 2003-2004 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
