package OpenGuides::CGI;
use strict;
use vars qw( $VERSION );
$VERSION = '0.02';

use Carp qw( croak );
use CGI::Cookie;

=head1 NAME

OpenGuides::CGI - An OpenGuides helper for CGI-related things.

=head1 DESCRIPTION

Does CGI stuff for OpenGuides.  Distributed and installed as part of
the OpenGuides project, not intended for independent installation.
This documentation is probably only useful to OpenGuides developers.

=head1 SYNOPSIS

  use Config::Tiny;
  use OpenGuides::CGI;
  use OpenGuides::Template;
  use OpenGuides::Utils;

  my $config = Config::Tiny->read( "wiki.conf" );

  my $cookie = OpenGuides::CGI->make_prefs_cookie(
      config                 => $config,
      username               => "Kake",
      include_geocache_link  => 1,
      preview_above_edit_box => 1,
      latlong_traditional    => 1
  );

  my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );
  print OpenGuides::Template->output( wiki     => $wiki,
                                      config   => $config,
                                      template => "preferences.tt",
                                      cookies  => $cookie
  );

  # and to retrive prefs later:
  my %prefs = OpenGuides::CGI->get_prefs_from_cookie(
      config => $config
  );

=head1 METHODS

=over 4

=item B<make_prefs_cookie>

  my $cookie = OpenGuides::CGI->make_prefs_cookie(
      config                 => $config,
      username               => "Kake",
      include_geocache_link  => 1,
      preview_above_edit_box => 1,
      latlong_traditional    => 1
  );

Croaks unless a L<Config::Tiny> object is supplied as C<config>.

=cut

sub make_prefs_cookie {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config object supplied";
    croak "Config object not a Config::Tiny"
        unless UNIVERSAL::isa( $config, "Config::Tiny" );
    my $cookie_name = $class->_get_cookie_name( config => $config );
    my $cookie = CGI::Cookie->new(
        -name  => $cookie_name,
	-value => { user   => $args{username},
		    gclink => $args{include_geocache_link},
                    prevab => $args{preview_above_edit_box},
                    lltrad => $args{latlong_traditional} }
    );
    return $cookie;
}

=item B<get_prefs_from_cookie>

  my %prefs = OpenGuides::CGI->get_prefs_from_cookie(
      config => $config
  );

Croaks unless a L<Config::Tiny> object is supplied as C<config>.
Returns default values for any parameter not specified in cookie.

=cut

sub get_prefs_from_cookie {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config object supplied";
    croak "Config object not a Config::Tiny"
        unless UNIVERSAL::isa( $config, "Config::Tiny" );
    my %cookies = CGI::Cookie->fetch;
    my $cookie_name = $class->_get_cookie_name( config => $config );
    my %data;
    if ( $cookies{$cookie_name} ) {
        %data = $cookies{$cookie_name}->value; # call ->value in list context
    }
    return ( username               => $data{user} || "Anonymous",
             include_geocache_link  => $data{gclink} || 0,
             preview_above_edit_box => $data{prevab} || 0,
             latlong_traditional    => $data{lltrad} || 0  );
}

sub _get_cookie_name {
    my ($class, %args) = @_;
    my $site_name = $args{config}->{_}->{site_name}
        or croak "No site name in config";
    return $site_name . "_userprefs";
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

