package OpenGuides::Template;

use strict;
use vars qw( $VERSION );
$VERSION = '0.01';

use Carp qw( croak );
use CGI; # want to get rid of this and put the burden on the templates
use Template;

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
        $header = "Content-Type: text/html\n\n";
    }
    my $output;
    $tt->process( $args{template}, $tt_vars, \$output );

    $output ||= qq(<html><head><title>ERROR</title></head><body><p>
                   Failed to process template: )
              . $tt->error
              . qq(</p></body></html>);

    return $header . $output;
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
