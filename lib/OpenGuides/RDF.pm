package OpenGuides::RDF;

use strict;

use vars qw( $VERSION );
$VERSION = '0.04';

use CGI::Wiki::Plugin::RSS::ModWiki;
use Time::Piece;
use URI::Escape;
use Carp qw( croak );

=head1 NAME

OpenGuides::RDF - An OpenGuides plugin to output RDF/XML.

=head1 DESCRIPTION

Does all the RDF stuff for OpenGuides.  Distributed and installed as
part of the OpenGuides project, not intended for independent
installation.  This documentation is probably only useful to OpenGuides
developers.

=head1 SYNOPSIS

  use CGI::Wiki;
  use Config::Tiny;
  use OpenGuides::RDF;

  my $wiki = CGI::Wiki->new( ... );
  my $config = Config::Tiny->read( "wiki.conf" );
  my $rdf_writer = OpenGuides::RDF->new( wiki   => $wiki,
                                         config => $config ); 

  print "Content-type: text/plain\n\n";
  print $rdf_writer->emit_rdfxml( node => "Masala Zone, N1 0NU" );

=head1 METHODS

=over 4

=item B<new>

  my $rdf_writer = OpenGuides::RDF->new( wiki   => $wiki,
                                         config => $config ); 

C<wiki> must be a L<CGI::Wiki> object and C<config> must be a
L<Config::Tiny> object.  Both arguments mandatory.

=cut

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self, $class;
    return $self->_init(@args);
}

sub _init {
    my ($self, %args) = @_;

    my $wiki = $args{wiki};
    unless ( $wiki && UNIVERSAL::isa( $wiki, "CGI::Wiki" ) ) {
        croak "No CGI::Wiki object supplied.";
    }
    $self->{wiki} = $wiki;

    my $config = $args{config};
    unless ( $config && UNIVERSAL::isa( $config, "Config::Tiny" ) ) {
        croak "No Config::Tiny object supplied.";
    }
    $self->{config} = $config;

    $self->{site_name} = $config->{_}->{site_name};
    $self->{make_node_url} = sub {
        my ($node_name, $version) = @_;
	if ( defined $version ) {
	    return $config->{_}->{script_url} . uri_escape($config->{_}->{script_name}) . "?id=" . uri_escape($wiki->formatter->node_name_to_node_param($node_name)) . ";version=" . uri_escape($version);
	} else {
	    return $config->{_}->{script_url} . uri_escape($config->{_}->{script_name}) . "?id=" . uri_escape($wiki->formatter->node_name_to_node_param($node_name));
        }
    };
    $self->{default_city}     = $config->{_}->{default_city}     || "";
    $self->{default_country}  = $config->{_}->{default_country}  || "";
    $self->{site_description} = $config->{_}->{site_description} || "";

    return $self;
}

=back

=cut

=item B<emit_rdfxml>

  $wiki->write_node( "Masala Zone, N1 0NU",
		     "Quick and tasty Indian food",
		     $checksum,
		     { comment  => "New page",
		       username => "Kake",
		       locale   => "Islington"
                     }
  );

  print "Content-type: text/plain\n\n";
  print $rdf_writer->emit_rdfxml( node => "Masala Zone, N1 0NU" );

B<Note:> Some of the fields emitted by the RDF/XML generator are taken
from the node metadata. The form of this metadata is I<not> mandated
by L<CGI::Wiki>. Your wiki application should make sure to store some or
all of the following metadata when calling C<write_node>:

=over 4

=item B<postcode> - The postcode or zip code of the place discussed by the node.  Defaults to the empty string.

=item B<city> - The name of the city that the node is in.  If not supplied, then the value of C<default_city> in the config object supplied to C<new>, if available, otherwise the empty string.

=item B<country> - The name of the country that the node is in.  If not supplied, then the value of C<default_country> in the config object supplied to C<new> will be used, if available, otherwise the empty string.

=item B<username> - An identifier for the person who made the latest edit to the node.  This person will be listed as a contributor (Dublin Core).  Defaults to empty string.

=item B<locale> - The value of this can be a scalar or an arrayref, since some places have a plausible claim to being in more than one locale.  Each of these is put in as a C<Neighbourhood> attribute.

=item B<phone> - Only one number supported at the moment.  No validation.

=item B<website> - No validation.

=item B<opening_hours_text> - A freeform text field.

=back

=cut

sub emit_rdfxml {
    my ($self, %args) = @_;

    my $node_name = $args{node};
    my $wiki = $self->{wiki};

   my %node_data = $wiki->retrieve_node( $node_name );
    my $phone     = $node_data{metadata}{phone}[0] || "";
    my $website   = $node_data{metadata}{website}[0] || "";
    my $opening_hours_text = $node_data{metadata}{opening_hours_text}[0] || "";
    my $postcode  = $node_data{metadata}{postcode}[0] || "";
    my $city      = $node_data{metadata}{city}[0]
                     || $self->{default_city} || "";
    my $country   = $node_data{metadata}{country}[0]
                     || $self->{default_country} || "";
    my $latitude  = $node_data{metadata}{latitude}[0] || "";
    my $longitude = $node_data{metadata}{longitude}[0] || "";
    my $version   = $node_data{version};
    my $username  = $node_data{metadata}{username}[0] || "";

    my $catrefs  = $node_data{metadata}{category};
    my @locales  = @{ $node_data{metadata}{locale} || [] };

    my $timestamp = $node_data{last_modified};
    # Make a Time::Piece object.
    my $timestamp_fmt = $CGI::Wiki::Store::Database::timestamp_fmt;
#        my $timestamp_fmt = $wiki->{store}->timestamp_fmt;
    if ( $timestamp ) {
        my $time = Time::Piece->strptime( $timestamp, $timestamp_fmt );
        $timestamp = $time->strftime( "%Y-%m-%dT%H:%M:%S" );
    }

    my $url = $self->{make_node_url}->( $node_name, $version );
    my $version_indpt_uri = $self->{make_node_url}->( $node_name );

    my $rdf = qq{<?xml version="1.0"?>
  <rdf:RDF
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:wiki="http://purl.org/rss/1.0/modules/wiki/"
  xmlns:chefmoz="http://chefmoz.org/rdf/elements/1.0/"
  xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#" >
  <rdf:Description rdf:about="$url">
    <dc:title>} . $self->{site_name} . qq{ review: $node_name</dc:title>
    <dc:date>$timestamp</dc:date>
    <dcterms:modified>$timestamp</dcterms:modified>
    <dc:contributor>$username</dc:contributor>
    <dc:source rdf:resource="$version_indpt_uri" />
    <wiki:version>$version</wiki:version>
    <foaf:homepage>$website</foaf:homepage>
    <foaf:topic>
      <chefmoz:Restaurant>
	<dc:title>$node_name</dc:title>
	<chefmoz:Country>$country</chefmoz:Country>
        <chefmoz:City>$city</chefmoz:City>
	<chefmoz:Zip>$postcode</chefmoz:Zip>
	<chefmoz:Phone>$phone</chefmoz:Phone>
	<chefmoz:Hours>$opening_hours_text</chefmoz:Hours>
};
    foreach my $locale (@locales) {
        $rdf .= "        <chefmoz:Neighborhood>$locale</chefmoz:Neighborhood>\n";
    }
    $rdf .= qq{        <geo:lat>$latitude</geo:lat>
        <geo:long>$longitude</geo:long>
      </chefmoz:Restaurant>
    </foaf:topic>
  </rdf:Description>
</rdf:RDF>

};

    return $rdf;
}

=back

=head1 SEE ALSO

=over 4

=item * L<CGI::Wiki>

=item * The OpenGuides website which we haven't written yet.

=item * L<http://chefmoz.org/>

=back

=head1 AUTHOR

The OpenGuides Project (grubstreet@hummous.earth.li)

=head1 COPYRIGHT

     Copyright (C) 2003 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CREDITS

Code in this module written by Kake Pugh and Earle Martin.  Dan
Brickley, Matt Biddulph and other inhabitants of #core gave useful
feedback and advice.

=cut

1;
