package OpenGuides::Utils;

use strict;
use vars qw( $VERSION );
$VERSION = '0.06';

use lib '/home/earle/lib';
use Carp qw( croak );
use CGI::Wiki;
use CGI::Wiki::Formatter::UseMod;
use CGI::Wiki::Plugin::RSS::Reader;
use CGI::Wiki::Search::SII;
use Search::InvertedIndex::DB::DB_File_SplitHash;
use URI::Escape;

=head1 NAME

OpenGuides::Utils - General utility methods for OpenGuides scripts.

=head1 DESCRIPTION

Provides general utility methods for OpenGuides scripts.  Distributed
and installed as part of the OpenGuides project, not intended for
independent installation.  This documentation is probably only useful
to OpenGuides developers.

=head1 SYNOPSIS

  use CGI::Wiki;
  use Config::Tiny;
  use OpenGuides::Utils;

  my $config = Config::Tiny->read( "wiki.conf" );
  my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

=head1 METHODS

=over 4

=item B<make_wiki_object>

  my $config = Config::Tiny->read( "wiki.conf" );
  my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

Croaks unless a C<Config::Tiny> object is supplied.  Returns a
C<CGI::Wiki> object made from the given config file on success,
croaks if any other error occurs.

The config file needs to define at least the following variables:

=over

=item *

dbtype - one of C<postgres>, C<mysql> and C<sqlite>

=item *

dbname

=item *

indexing_directory - for the L<Search::InvertedIndex> files to go

=back

=cut

sub make_wiki_object {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config param supplied";
    croak "config param isn't a Config::Tiny object"
	unless UNIVERSAL::isa( $config, "Config::Tiny" );

    # Require in the right database module.
    my $dbtype = $config->{_}->{dbtype};

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
        dbname => $config->{_}{dbname},
        dbuser => $config->{_}{dbuser},
        dbpass => $config->{_}{dbpass},
        dbhost => $config->{_}{dbhost},
    );

    # Make search.
    my $indexdb = Search::InvertedIndex::DB::DB_File_SplitHash->new(
        -map_name  => $config->{_}{indexing_directory},
        -lock_mode => "EX"
    );
    my $search  = CGI::Wiki::Search::SII->new( indexdb => $indexdb );

    # Make formatter.
    my $script_name = $config->{_}->{script_name};
    my $search_url = $config->{_}->{script_url} . "supersearch.cgi";

    my %macros = (
        '@SEARCHBOX' =>
            qq(<form action="$search_url" method="get"><input type="text" size="20" name="search"><input type="submit" name="Go" value="Search"></form>),
        qr/\@INDEX_LINK\s+\[\[(Category|Locale)\s+([^\]|]+)\|?([^\]]+)?\]\]/ =>
            sub {
                  my $link_title = $_[2] || "View all pages in $_[0] $_[1]";
                  return qq(<a href="$script_name?action=index;index_type=) . uri_escape(lc($_[0])) . qq(;index_value=) . uri_escape($_[1]) . qq(">$link_title</a>);
                },
	qr/\@RSS\s+\[(.*?)\]/ => sub { 
                                      # Get the URL. It's already been formatted into a 
                                      # hyperlink so we need to reverse that.
                                      my $url_raw = $_[0];
                                      $url_raw =~ />(.*?)</;
                                      my $url = $1;

                                      # Retrieve the RSS from the given URL.
                                      my $rss = CGI::Wiki::Plugin::RSS::Reader->new(url => $url);
                                      my @items = $rss->retrieve;

                                      # Ten items only at this till.
                                      $#items = 10 if $#items > 10;

                                      # Make an HTML list with them.
                                      my $list  = "<ul>\n";
                                      foreach (@items)
                                      {
                                        my $link  = $_->{link};
                                        my $title = $_->{title};
                                        $list .= qq{\t<li><a href="$link">$title</a></li>\n};
                                      }
                                      $list .= "</ul>\n";
                                    }
    );

    my $formatter = CGI::Wiki::Formatter::UseMod->new(
        extended_links      => 1,
        implicit_links      => 0,
        allowed_tags        => [qw(a p b strong i em pre small img table td
                                   tr th br hr ul li center blockquote kbd
                                   div code strike sub sup font)],
        macros              => \%macros,
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

     Copyright (C) 2003 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
