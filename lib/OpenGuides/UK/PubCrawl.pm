package OpenGuides::UK::PubCrawl;
use strict;

use vars qw( $VERSION @ISA );
$VERSION = '0.01';

use Carp qw( croak );
use CGI::Wiki::Plugin;
use CGI::Wiki::Plugin::Locator::UK;

@ISA = qw( CGI::Wiki::Plugin );

=head1 NAME

OpenGuides::UK::PubCrawl - An OpenGuides plugin to generate pub crawls.

=head1 DESCRIPTION

Generates pub crawls for OpenGuides installations based in the United
Kingdom.  Distributed and installed as part of the OpenGuides project,
not intended for independent installation.  This documentation is
probably only useful to OpenGuides developers.

=head1 SYNOPSIS

  use CGI::Wiki;
  use CGI::Wiki::Plugin::Locator::UK;
  use OpenGuides::UK::PubCrawl;

  my $wiki = CGI::Wiki->new( ... );
  my $locator = CGI::Wiki::Plugin::Locator::UK->new;
  $wiki->register_plugin( plugin => $locator );
  my $categoriser = CGI::Wiki::Plugin::Categoriser->new;
  $wiki->register_plugin( plugin => $categoriser );

  my $crawler = OpenGuides::UK::PubCrawl->new(
      locator     => $locator,
      categoriser => $categoriser );
  $wiki->register_plugin( plugin => $crawler );
 
=head1 METHODS

=over 4

=item B<new>

  my $crawler = OpenGuides::UK::PubCrawl->new(
      locator     => $locator,
      categoriser => $categoriser );

  my $crawler = OpenGuides::UK::PubCrawl->new( locator => $locator );

Croaks unless a C<CGI::Wiki::Plugin::Locator::UK> object and a
C<CGI::Wiki::Plugin::Categoriser> object are supplied.

=cut

sub new {
    my ($class, %args) = @_;
    my $locator = $args{locator}
      or croak "No locator parameter supplied";
    croak "Locator parameter is not a CGI::Wiki::Plugin::Locator::UK"
      unless UNIVERSAL::isa( $locator, "CGI::Wiki::Plugin::Locator::UK" );
    my $categoriser = $args{categoriser}
      or croak "No categoriser parameter supplied";
    croak "Categoriser parameter is not a CGI::Wiki::Plugin::Categoriser"
      unless UNIVERSAL::isa( $categoriser, "CGI::Wiki::Plugin::Categoriser" );
    my $self = { _locator     => $locator,
                 _categoriser => $categoriser };
    bless $self, $class;
    return $self;
}

=item B<locator>

Returns locator object.

=cut

sub locator {
    my $self = shift;
    return $self->{_locator};
}

=item B<categoriser>

Returns categoriser object.

=cut

sub categoriser {
    my $self = shift;
    return $self->{_categoriser};
}

=item B<generate_crawl>

  my @crawl = $crawler->generate_crawl( start_location =>
                                            { os_x => 528385,
                                              os_y => 180605  },
                                        max_km_between => 0.5,
                                        num_pubs => 5,
                                        omit => "Ivy House"
                                      );

These are the only options so far.  Returns an array of nodenames.
C<num_pubs> will default to 5, for the sake of your liver.  If it
can't find a crawl as long as you asked for, returns the longest one
it could find.

=cut

sub generate_crawl {
    my ($self, %args) = @_;
    my $x = $args{start_location}{os_x} or croak "No os_x";
    my $y = $args{start_location}{os_y} or croak "No os_y";
    my $km = $args{max_km_between} or croak "No max_km_between";
    my $num_pubs = $args{num_pubs} || 5;
    my $locator = $self->locator;
    my $categoriser = $self->categoriser;
    my @firsts = $locator->find_within_distance( os_x       => $x,
                                                 os_y       => $y,
                                                 kilometres => $km );
    my %omit = map { $_ => 1 } @{ $args{omit} || [] };
    @firsts = grep { !$omit{$_}
                     and $categoriser->in_category( category => "Pubs",
                                                    node     => $_      )
                   } @firsts;
    return () unless scalar @firsts;

    # If we're only after one pub (bottom of recursion) return one now.
    return $firsts[0] if $num_pubs == 1;

    # Be prepared to save the longest crawl found, in case we can't find
    # one as long as requested.
    my @fallback = ();

    foreach my $first ( @firsts ) {
        my @coords = $locator->coordinates( node => $first );
        my @tail = $self->generate_crawl(
            start_location => { os_x => $coords[0],
				os_y => $coords[1] },
	    max_km_between => $km,
	    omit => [ $first, keys %omit ],
            num_pubs => $num_pubs - 1
        );
        if ( scalar @tail and scalar @tail == ( $num_pubs - 1 ) ) {
            return ( $first, @tail );
        } elsif ( scalar @tail + 1 > scalar @fallback ) {
            @fallback = ( $first, @tail );
        }
    }
    return @fallback;
}

=back

=head1 AUTHOR

The OpenGuides Project (grubstreet@hummous.earth.li)

=head1 COPYRIGHT

     Copyright (C) 2003 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
