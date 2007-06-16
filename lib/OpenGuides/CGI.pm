package OpenGuides::CGI;
use strict;
use vars qw( $VERSION );
$VERSION = '0.07';

use Carp qw( croak );
use CGI::Cookie;

=head1 NAME

OpenGuides::CGI - An OpenGuides helper for CGI-related things.

=head1 DESCRIPTION

Does CGI stuff for OpenGuides.  Distributed and installed as part of
the OpenGuides project, not intended for independent installation.
This documentation is probably only useful to OpenGuides developers.

=head1 SYNOPSIS

Saving preferences in a cookie:

  use OpenGuides::CGI;
  use OpenGuides::Config;
  use OpenGuides::Template;
  use OpenGuides::Utils;

  my $config = OpenGuides::Config->new( file => "wiki.conf" );

  my $cookie = OpenGuides::CGI->make_prefs_cookie(
      config                     => $config,
      username                   => "Kake",
      include_geocache_link      => 1,
      preview_above_edit_box     => 1,
      latlong_traditional        => 1,
      omit_help_links            => 1,
      show_minor_edits_in_rc     => 1,
      default_edit_type          => "tidying",
      cookie_expires             => "never",
      track_recent_changes_views => 1,
      display_google_maps        => 1
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

Tracking visits to Recent Changes:

  use OpenGuides::CGI;
  use OpenGuides::Config;
  use OpenGuides::Template;
  use OpenGuides::Utils;

  my $config = OpenGuides::Config->new( file => "wiki.conf" );

  my $cookie = OpenGuides::CGI->make_recent_changes_cookie(
      config => $config,
  );

=head1 METHODS

=over 4

=item B<make_prefs_cookie>

  my $cookie = OpenGuides::CGI->make_prefs_cookie(
      config                     => $config,
      username                   => "Kake",
      include_geocache_link      => 1,
      preview_above_edit_box     => 1,
      latlong_traditional        => 1,
      omit_help_links            => 1,
      show_minor_edits_in_rc     => 1,
      default_edit_type          => "tidying",
      cookie_expires             => "never",
      track_recent_changes_views => 1,
      display_google_maps        => 1
  );

Croaks unless an L<OpenGuides::Config> object is supplied as C<config>.
Acceptable values for C<cookie_expires> are C<never>, C<month>,
C<year>; anything else will default to C<month>.

=cut

sub make_prefs_cookie {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config object supplied";
    croak "Config object not an OpenGuides::Config"
        unless UNIVERSAL::isa( $config, "OpenGuides::Config" );
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
                    trackrc    => $args{track_recent_changes_views} || 0,
                    gmaps      => $args{display_google_maps} || 0
                  },
        -expires => $expires,
    );
    return $cookie;
}

=item B<get_prefs_from_cookie>

  my %prefs = OpenGuides::CGI->get_prefs_from_cookie(
      config => $config,
      cookies => \@cookies
  );

Croaks unless an L<OpenGuides::Config> object is supplied as C<config>.
Returns default values for any parameter not specified in cookie.

If C<cookies> is provided, this overrides any cookies submitted by the
browser.

=cut

sub get_prefs_from_cookie {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config object supplied";
    croak "Config object not an OpenGuides::Config"
        unless UNIVERSAL::isa( $config, "OpenGuides::Config" );
    my $cookie_name = $class->_get_cookie_name( config => $config );
    my %cookies;
    if ( my $cookies = $args{cookies} ) {
        if (ref $cookies ne 'ARRAY') {
            $cookies = [ $cookies ];
        }
        %cookies = map { $_->name => $_ } @{ $cookies };
    }
    else {
        %cookies = CGI::Cookie->fetch;
    }
    my %data;
    if ( $cookies{$cookie_name} ) {
        %data = $cookies{$cookie_name}->value; # call ->value in list context
    }

    my %long_forms = (
                       user       => "username",
                       gclink     => "include_geocache_link",
                       prevab     => "preview_above_edit_box",
                       lltrad     => "latlong_traditional",
                       omithlplks => "omit_help_links",
                       rcmined    => "show_minor_edits_in_rc",
                       defedit    => "default_edit_type",
                       exp        => "cookie_expires",
                       trackrc    => "track_recent_changes_views",
                       gmaps      => "display_google_maps",
                     );
    my %long_data = map { $long_forms{$_} => $data{$_} } keys %long_forms;

    return $class->get_prefs_from_hash( %long_data );
}

sub get_prefs_from_hash {
    my ($class, %data) = @_;
    my %defaults = (
                     username                   => "Anonymous",
                     include_geocache_link      => 0,
                     preview_above_edit_box     => 0,
                     latlong_traditional        => 0,
                     omit_help_links            => 0,
                     show_minor_edits_in_rc     => 0,
                     default_edit_type          => "normal",
                     cookie_expires             => "month",
                     track_recent_changes_views => 0,
                     display_google_maps        => 1,
                   );
    my %return;
    foreach my $key ( keys %data ) {
        $return{$key} = defined $data{$key} ? $data{$key} : $defaults{$key};
    }

    return %return;
}


=item B<make_recent_changes_cookie>

  my $cookie = OpenGuides::CGI->make_recent_changes_cookie(
      config => $config,
  );

Makes a cookie that stores the time now as the time of the latest
visit to Recent Changes.  Or, if C<clear_cookie> is specified and
true, makes a cookie with an expiration date in the past:

  my $cookie = OpenGuides::CGI->make_recent_changes_cookie(
      config       => $config,
      clear_cookie => 1,
  );

=cut

sub make_recent_changes_cookie {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config object supplied";
    croak "Config object not an OpenGuides::Config"
        unless UNIVERSAL::isa( $config, "OpenGuides::Config" );
    my $cookie_name = $class->_get_rc_cookie_name( config => $config );
    # See explanation of expiry date hack above in make_prefs_cookie.
    my $expires;
    if ( $args{clear_cookie} ) {
        $expires = "-1M";
    } else {
        $expires = "Thu, 31-Dec-2037 22:22:22 GMT";
    }
    my $cookie = CGI::Cookie->new(
        -name  => $cookie_name,
	-value => {
                    time => time,
                  },
        -expires => $expires,
    );
    return $cookie;
}


=item B<get_last_recent_changes_visit_from_cookie>

  my %prefs = OpenGuides::CGI->get_last_recent_changes_visit_from_cookie(
      config => $config
  );

Croaks unless an L<OpenGuides::Config> object is supplied as C<config>.
Returns the time (as seconds since epoch) of the user's last visit to
Recent Changes.

=cut

sub get_last_recent_changes_visit_from_cookie {
    my ($class, %args) = @_;
    my $config = $args{config} or croak "No config object supplied";
    croak "Config object not an OpenGuides::Config"
        unless UNIVERSAL::isa( $config, "OpenGuides::Config" );
    my %cookies = CGI::Cookie->fetch;
    my $cookie_name = $class->_get_rc_cookie_name( config => $config );
    my %data;
    if ( $cookies{$cookie_name} ) {
        %data = $cookies{$cookie_name}->value; # call ->value in list context
    }
    return $data{time};
}


sub _get_cookie_name {
    my ($class, %args) = @_;
    my $site_name = $args{config}->site_name
        or croak "No site name in config";
    return $site_name . "_userprefs";
}

sub _get_rc_cookie_name {
    my ($class, %args) = @_;
    my $site_name = $args{config}->site_name
        or croak "No site name in config";
    return $site_name . "_last_rc_visit";
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

