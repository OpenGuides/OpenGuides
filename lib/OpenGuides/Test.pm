package OpenGuides::Test;

use OpenGuides::Config;

use strict;
use vars qw( $VERSION );
$VERSION = '0.02';

use CGI;

=head1 NAME

OpenGuides::Test - Methods to help test OpenGuides applications.

=head1 DESCRIPTION

Provides methods to help when writing tests for OpenGuides.
Distributed and installed as part of the OpenGuides project, not
intended for independent installation.  This documentation is probably
only useful to OpenGuides developers.

=head1 SYNOPSIS

  use OpenGuides;
  use OpenGuides::Test;

  my $config = OpenGuides::Test->make_basic_config;
  $config->default_language( "nl" );

  my $guide = OpenGuides->new( config => $config );

  OpenGuides::Test->write_data(
                                guide      => $guide,
                                node       => "Crabtree Tavern",
                                os_x       => 523465,
                                os_y       => 177490,
                                categories => "Pubs",
                              );

=head1 METHODS

=over 4

=item B<make_basic_config>

  my $config = OpenGuides::Test->make_basic_config;
  $config->default_language( "nl" );

Makes an L<OpenGuides::Config> object with needed fields pre-filled.  You can
mess with it as you like then.

=cut

sub make_basic_config {
    my $config = OpenGuides::Config->new(
           vars => {
                     dbtype               => "sqlite",
                     dbname               => "t/node.db",
                     indexing_directory   => "t/indexes",
                     script_url           => "",
                     script_name          => "",
                     site_name            => "Test",
                     template_path        => "./templates",
                     custom_template_path => "./custom-templates",
                     home_name            => "Home",
                     geo_handler          => 1,
                   }
    );

    eval { require Wiki::Toolkit::Search::Plucene; };
    if ( $@ ) { $config->use_plucene ( 0 ) };
	
    return $config;
}

=item B<write_data>

  my $config = OpenGuides::Test->make_basic_config;
  my $guide = OpenGuides->new( config => $config );

  OpenGuides::Test->write_data(
                                guide      => $guide,
                                node       => "Crabtree Tavern",
                                os_x       => 523465,
                                os_y       => 177490,
                                categories => "Pubs\r\nPub Food",
                              );

You can supply values for the following keys: C<content>,
C<categories>, C<locales>, C<os_x>, C<os_y>, C<osie_x>, C<osie_y>,
C<latitude>, C<longitude>.  You should supply them exactly as they
would come from a CGI form, eg lines in a textarea are separated by C<\r\n>.

=cut

sub write_data {
    my ($class, %args) = @_;

    # Set up CGI parameters ready for a node write.
    # Most of these are in here to avoid uninitialised value warnings.
    my $q = CGI->new( "" );
    $q->param( -name => "content", -value => $args{content} || "foo" );
    $q->param( -name => "categories", -value => $args{categories} || "" );
    $q->param( -name => "locales", -value => $args{locales} || "" );
    $q->param( -name => "phone", -value => "" );
    $q->param( -name => "fax", -value => "" );
    $q->param( -name => "website", -value => "" );
    $q->param( -name => "hours_text", -value => "" );
    $q->param( -name => "address", -value => "" );
    $q->param( -name => "postcode", -value => "" );
    $q->param( -name => "map_link", -value => "" );
    $q->param( -name => "os_x", -value => $args{os_x} || "" );
    $q->param( -name => "os_y", -value => $args{os_y} || "" );
    $q->param( -name => "osie_x", -value => $args{osie_x} || "" );
    $q->param( -name => "osie_y", -value => $args{osie_y} || "" );
    $q->param( -name => "latitude", -value => $args{latitude} || "" );
    $q->param( -name => "longitude", -value => $args{longitude} || "" );
    $q->param( -name => "username", -value => "Kake" );
    $q->param( -name => "comment", -value => "foo" );
    $q->param( -name => "edit_type", -value => "Normal edit" );
    $ENV{REMOTE_ADDR} = "127.0.0.1";
    
    # Get the checksum of the current contents if necessary.
    my $wiki = $args{guide}->wiki;
    if ( $wiki->node_exists( $args{node} ) ) {
        my %data = $wiki->retrieve_node( $args{node} );
        $q->param( -name => "checksum", -value => $data{checksum} );
    }

    $args{guide}->commit_node(
                               return_output => 1,
                               id => $args{node},
                               cgi_obj => $q,
                             );
}

=back

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

  Copyright (C) 2004 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
