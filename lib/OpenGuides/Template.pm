package OpenGuides::Template;

use strict;
use vars qw( $VERSION );
$VERSION = '0.04';

use Carp qw( croak );
use CGI; # want to get rid of this and put the burden on the templates
use Geography::NationalGrid;
use Geography::NationalGrid::GB;
use Template;
use URI::Escape;

=head1 NAME

OpenGuides::Template - Do Template Toolkit related stuff for OpenGuides applications.

=head1 DESCRIPTION

Does all the Template Toolkit stuff for OpenGuides.  Distributed and
installed as part of the OpenGuides project, not intended for
independent installation.  This documentation is probably only useful
to OpenGuides developers.

=head1 SYNOPSIS

  use Config::Tiny;
  use OpenGuides::Utils;
  use OpenGuides::Template;

  my $config = Config::Tiny->read('wiki.conf');
  my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

  print OpenGuides::Template->output( wiki     => $wiki,
                                      config   => $config,
                                      template => "node.tt",
                                      vars     => { foo => "bar" }
  );

=head1 METHODS

=over 4

=item B<output>

  print OpenGuides::Template->output( wiki         => $wiki,
                                      config       => $config,
                                      template     => "node.tt",
                                      content_type => "text/html",
                                      cookies      => $cookie,
                                      vars         => { foo => "bar" }
  );

Returns everything you need to send to STDOUT, including the
Content-Type: header. Croaks unless C<template> is supplied.

Content-Type: defaults to C<text/html> and is omitted if the
C<content_type> arg is explicitly set to the blank string.

=cut

sub output {
    my ($class, %args) = @_;
    croak "No template supplied" unless $args{template};
    my $config = $args{config} or croak "No config supplied";
    my $template_path = $config->{_}->{template_path};
    my $tt = Template->new( { INCLUDE_PATH => $template_path } );
    my $tt_vars = $args{vars} || {};

    my $script_name = $config->{_}->{script_name};
    $tt_vars = { %$tt_vars,
		 site_name     => $config->{_}->{site_name},
		 cgi_url       => $script_name,
		 full_cgi_url  => $config->{_}->{script_url} . $script_name,
		 contact_email => $config->{_}->{contact_email},
		 stylesheet    => $config->{_}->{stylesheet_url},
		 home_link     => $script_name,
		 home_name     => $config->{_}->{home_name}
    };

    if ($args{node}) {
        $tt_vars->{node_name} = CGI->escapeHTML($args{node});
        $tt_vars->{node_param} = CGI->escape($args{wiki}->formatter->node_name_to_node_param($args{node}));
    }

    my $header = "";
    unless ( defined $args{content_type} and $args{content_type} eq "" ) {
        $header = CGI::header( -cookie => $args{cookies} );
    }
    my $output;
    $tt->process( $args{template}, $tt_vars, \$output );

    $output ||= qq(<html><head><title>ERROR</title></head><body><p>
                   Failed to process template: )
              . $tt->error
              . qq(</p></body></html>);

    return $header . $output;
}

=item B<extract_metadata_vars>

  my %node_data = $wiki->retrieve_node( "Home Page" );

  my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
                                        wiki     => $wiki,
                                        config   => $config,
                                        metadata => $node_data{metadata} );

  # -- or --

  my %metadata_vars = OpenGuides::Template->extract_metadata_vars(
                                        wiki     => $wiki,
                                        config   => $config,
					cgi_obj  => $q );

  # -- then --

  print OpenGuides::Template->output( wiki     => $wiki,
                                      config   => $config,
                                      template => "node.tt",
                                      vars     => { foo => "bar",
                                                    %metadata_vars }
				     );

Picks out things like categories, locales, phone number etc from
EITHER the metadata hash returned by L<CGI::Wiki> OR the query
parameters in a L<CGI> object, and packages them nicely for passing to
templates or storing in L<CGI::Wiki> datastore.  If you supply both
C<metadata> and C<cgi_obj> then C<metadata will take precedence, but
don't do that.

=cut

sub extract_metadata_vars {
    my ($class, %args) = @_;
    my %metadata = %{$args{metadata} || {} };
    my $q = $args{cgi_obj};
    my $formatter = $args{wiki}->formatter;
    my $config = $args{config};
    my $script_name = $config->{_}->{script_name};

    # Categories and locales are displayed as links in the page footer.
    my (@catlist, @loclist);
    if ( $args{metadata} ) {
        @catlist = @{ $metadata{category} || [] };
        @loclist = @{ $metadata{locale}   || [] };
    } else {
	my $categories_text = $q->param('categories');
	my $locales_text    = $q->param('locales');
	@catlist = sort split("\r\n", $categories_text);
	@loclist = sort split("\r\n", $locales_text);
    }

    my @categories = map { { name => $_,
                             url  => "$script_name?Category_"
            . uri_escape($formatter->node_name_to_node_param($_)) } } @catlist;

    my @locales    = map { { name => $_,
                             url  => "$script_name?Locale_"
            . uri_escape($formatter->node_name_to_node_param($_)) } } @loclist;

    # The 'website' attribute might contain a URL so we wiki-format it here
    # rather than just CGI::escapeHTMLing it all in the template.
    my $website = $args{metadata} ? $metadata{website}[0]
                                  : $q->param("website");
    my $formatted_website_text = "";
    if ( $website ) {
        $formatted_website_text = $class->format_website_text(
            formatter => $formatter,
            text      => $website );
    }

    my $hours_text = $args{metadata} ? $metadata{opening_hours_text}[0]
   	                             : $q->param("hours_text");
    my %vars = (
        categories             => \@categories,
	locales                => \@locales,
	formatted_website_text => $formatted_website_text,
	hours_text             => $hours_text
    );

    if ( $args{metadata} ) {
        foreach my $var ( qw( phone fax address postcode os_x os_y latitude
                                                               longitude ) ) {
            $vars{$var} = $metadata{$var}[0];
        }
    } else {
        foreach my $var ( qw( phone fax address postcode ) ) {
            $vars{$var} = $q->param($var);
        }

	my $os_x = $q->param("os_x");
	my $os_y = $q->param("os_y");
	# Work out latitude and longitude for the preview display.
	if ($os_x and $os_y) {
	    my $point = Geography::NationalGrid::GB->new( Easting  => $os_x,
							  Northing => $os_y );
	    %vars = ( %vars,
		      latitude  => sprintf("%.6f", $point->latitude),
		      longitude => sprintf("%.6f", $point->longitude),
		      os_x      => $os_x,
		      os_y      => $os_y
	    );
	}
    }

    return %vars;
}

sub format_website_text {
    my ($class, %args) = @_;
    my ($formatter, $text) = @args{ qw( formatter text ) };
    my $formatted = $formatter->format($text);

    # Strip out paragraph markers put in by formatter since we want this
    # to be a single string to put in a <ul>.
    $formatted =~ s/<p>//g;
    $formatted =~ s/<\/p>//g;

    return $formatted;
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
