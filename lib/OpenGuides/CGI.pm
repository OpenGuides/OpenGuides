package OpenGuides::CGI;
use strict;
use vars qw( $VERSION );
$VERSION = '0.06';

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
      latlong_traditional    => 1,
      omit_help_links        => 1,
      show_minor_edits_in_rc => 1,
      default_edit_type      => "tidying",
      cookie_expires         => "never",
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
      latlong_traditional    => 1,
      omit_help_links        => 1,
      show_minor_edits_in_rc => 1,
      default_edit_type      => "tidying",
      cookie_expires         => "never",
  );

Croaks unless a L<Config::Tiny> object is supplied as C<config>.
Acceptable values for C<cookie_expires> are C<never>, C<month>,
C<year>; anything else will default to C<month>.

=cut

sub make_prefs_cookie {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config object supplied";
    croak "Config object not a Config::Tiny"
        unless UNIVERSAL::isa( $config, "Config::Tiny" );
    my $cookie_name = $class->_get_cookie_name( config => $config );
    my $expires;
    if ( $args{cookie_expires} and $args{cookie_expires} eq "never" ) {
        # Gosh, a hack.  YES I AM ASHAMED OF MYSELF.
        # Putting no expiry date means cookie expires when browser closes.
        # Putting a date later than 2037 makes it wrap round, at least on Linux
        # I will only be 62 by the time I need to redo this hack, so I should
        # still be alive to fix it.
        $expires = "Thu, 31-Dec-2037 22:22:22 GMT";
    } elsif ( $args{cookie_expires} and $args{cookie_expires} eq "year" ) {
        $expires = "+1y";
    } else {
        $args{cookie_expires} = "month";
        $expires = "+1M";
    }
    # Supply 'default' values to stop CGI::Cookie complaining about
    # uninitialised values.  *Real* default should be applied before
    # calling this method.
    my $cookie = CGI::Cookie->new(
        -name  => $cookie_name,
	-value => { user       => $args{username} || "",
		    gclink     => $args{include_geocache_link} || 0,
                    prevab     => $args{preview_above_edit_box} || 0,
                    lltrad     => $args{latlong_traditional} || 0,
                    omithlplks => $args{omit_help_links} || 0,
                    rcmined    => $args{show_minor_edits_in_rc} || 0,
                    defedit    => $args{default_edit_type} || "normal",
                    exp        => $args{cookie_expires},
                  },
        -expires => $expires,
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
    return ( username               => $data{user}      || "Anonymous",
             include_geocache_link  => $data{gclink}    || 0,
             preview_above_edit_box => $data{prevab}    || 0,
             latlong_traditional    => $data{lltrad}    || 0,
             omit_help_links        => $data{omithlplks}|| 0,
             show_minor_edits_in_rc => $data{rcmined}   || 0,
             default_edit_type      => $data{defedit}   || "normal",
             cookie_expires         => $data{exp}       || "month",
           );
}

sub _get_cookie_name {
    my ($class, %args) = @_;
    my $site_name = $args{config}->{_}->{site_name}
        or croak "No site name in config";
    return $site_name . "_userprefs";
}

=back

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

     Copyright (C) 2003-4 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

