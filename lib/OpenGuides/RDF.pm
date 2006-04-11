package OpenGuides::RDF;

use strict;

use vars qw( $VERSION );
$VERSION = '0.09';

use CGI::Wiki::Plugin::RSS::ModWiki;
use Time::Piece;
use URI::Escape;
use Carp 'croak';

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self, $class;
    $self->_init(@args);
}

sub _init {
    my ($self, %args) = @_;

    my $wiki = $args{wiki};
    
    unless ( $wiki && UNIVERSAL::isa( $wiki, "CGI::Wiki" ) ) {
      croak "No CGI::Wiki object supplied.";
    }
    $self->{wiki} = $wiki;

    my $config = $args{config};

    unless ( $config && UNIVERSAL::isa( $config, "OpenGuides::Config" ) ) {
        croak "No OpenGuides::Config object supplied.";
    }
    $self->{config} = $config;

    $self->{make_node_url} = sub {
        my ($node_name, $version) = @_;

        my $config = $self->{config};
    
        my $node_url = $config->script_url . uri_escape($config->script_name) . '?';
        $node_url .= 'id=' if defined $version;
        $node_url .= uri_escape($self->{wiki}->formatter->node_name_to_node_param($node_name));
        $node_url .= ';version=' . uri_escape($version) if defined $version;

        $node_url;
      };  
    $self->{site_name}        = $config->site_name;
    $self->{default_city}     = $config->default_city     || "";
    $self->{default_country}  = $config->default_country  || "";
    $self->{site_description} = $config->site_desc        || "";
    $self->{og_version}       = $args{og_version};

    $self;
}

sub emit_rdfxml {
    my ($self, %args) = @_;

    my $node_name = $args{node};
    my $wiki = $self->{wiki};

    my %node_data          = $wiki->retrieve_node( $node_name );
    my $phone              = $node_data{metadata}{phone}[0]              || '';
    my $fax                = $node_data{metadata}{fax}[0]                || '';
    my $website            = $node_data{metadata}{website}[0]            || '';
    my $opening_hours_text = $node_data{metadata}{opening_hours_text}[0] || '';
    my $address            = $node_data{metadata}{address}[0]            || '';
    my $postcode           = $node_data{metadata}{postcode}[0]           || '';
    my $city               = $node_data{metadata}{city}[0]               || $self->{default_city};
    my $country            = $node_data{metadata}{country}[0]            || $self->{default_country};
    my $latitude           = $node_data{metadata}{latitude}[0]           || '';
    my $longitude          = $node_data{metadata}{longitude}[0]          || '';
    my $version            = $node_data{version};
    my $username           = $node_data{metadata}{username}[0]           || '';
    my $os_x               = $node_data{metadata}{os_x}[0]               || '';
    my $os_y               = $node_data{metadata}{os_y}[0]               || '';
    my @categories         = @{ $node_data{metadata}{category} || [] };
    my @locales            = @{ $node_data{metadata}{locale} || [] };
    my $summary            = $node_data{metadata}{summary}[0]            || '';

    # replace any errant characters in data to prevent illegal XML
    foreach ($phone, $fax, $website, $opening_hours_text, $address, $postcode, 
             $city, $country, $latitude, $longitude, $version, $os_x, $os_y, 
             @categories, @locales, $summary)
    {
      if ($_)
      {
        $_ =~ s/&/&amp;/g;
        $_ =~ s/</&lt;/g;
        $_ =~ s/>/&gt;/g;
      }
    }
    
    my ($is_geospatial, $objType);

    if ($os_x || $os_y || $latitude || $longitude || $address || $postcode || @locales || $opening_hours_text) {
        $is_geospatial = 1;
        $objType    = 'geo:SpatialThing';
    } else {
        $objType = 'rdf:Description';
    }

    my $timestamp = $node_data{last_modified};
    
    # Make a Time::Piece object.
    my $timestamp_fmt = $CGI::Wiki::Store::Database::timestamp_fmt;

    if ( $timestamp ) {
        my $time   = Time::Piece->strptime($timestamp, $timestamp_fmt);
        $timestamp = $time->strftime("%Y-%m-%dT%H:%M:%S");
    }

    my $user_id = $username;
    $user_id =~ s/ /_/g;
    
    my $url               = $self->{make_node_url}->( $node_name, $version );
    my $version_indpt_url = $self->{make_node_url}->( $node_name );
    my $rdf = qq{<?xml version="1.0"?>
<rdf:RDF
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:wiki="http://purl.org/rss/1.0/modules/wiki/"
  xmlns:chefmoz="http://chefmoz.org/rdf/elements/1.0/"
  xmlns:wn="http://xmlns.com/wordnet/1.6/"
  xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
  xmlns:os="http://downlode.org/rdf/os/0.1/"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns="http://www.w3.org/2000/10/swap/pim/contact#"
>

  <rdf:Description rdf:about="">
    <dc:title>} . $self->{site_name} . qq{: $node_name</dc:title>
    <dc:date>$timestamp</dc:date>
    <dcterms:modified>$timestamp</dcterms:modified>

    <dc:contributor>
      <foaf:Person rdf:ID="$user_id">
        <foaf:nick>$username</foaf:nick>
      </foaf:Person>
    </dc:contributor>

    <dc:source rdf:resource="$version_indpt_url" />
    <wiki:version>$version</wiki:version>
    <foaf:topic rdf:resource="#obj" />
  </rdf:Description>

  <$objType rdf:ID="obj" dc:title="$node_name">
};
    $rdf .= "    <dc:description>$summary</dc:description>\n" if $summary;

    $rdf .= "\n    <!-- categories -->\n\n" if @categories;
    $rdf .= "    <dc:subject>$_</dc:subject>\n" foreach @categories;
    
    if ($is_geospatial)
    {
      $rdf .= "\n    <!-- address and geospatial data -->\n\n";
      $rdf .= "    <address>$address</address>\n"        if $address;
      $rdf .= "    <city>$city</city>\n"                 if $city;
      $rdf .= "    <postalCode>$postcode</postalCode>\n" if $postcode;
      $rdf .= "    <country>$country</country>\n"        if $country;

    foreach (@locales)
    { 
      my $locale_id = $_;
      $locale_id =~ s/ /_/g;
   
      $rdf .= qq{
    <foaf:based_near>
      <wn:Neighborhood rdf:ID="$locale_id">
        <dc:title>$_</dc:title>
      </wn:Neighborhood>
    </foaf:based_near>\n};
    }
    
      if ( $latitude && $longitude ) {
          $rdf .= qq{
    <geo:lat>$latitude</geo:lat>
    <geo:long>$longitude</geo:long>\n};
      }

      if ( $os_x && $os_y ) {
          $rdf .= qq{
    <os:x>$os_x</os:x>
    <os:y>$os_y</os:y>};
      }
    }
    
    $rdf .= "\n\n    <!-- contact information -->\n\n" if ($phone || $fax || $website || $opening_hours_text);
    $rdf .= "    <phone>$phone</phone>\n"                              if $phone;
    $rdf .= "    <fax>$fax</fax>\n"                                    if $fax;
    $rdf .= "    <foaf:homepage rdf:resource=\"$website\" />\n"        if $website;
    $rdf .= "    <chefmoz:Hours>$opening_hours_text</chefmoz:Hours>\n" if $opening_hours_text;

    if ($node_data{content} =~ /^\#REDIRECT \[\[(.*?)]\]$/)
    {
      my $redirect = $1;
      
      $rdf .= qq{    <owl:sameAs rdf:resource="} . $self->{config}->script_url
      . uri_escape($self->{config}->script_name) . '?id='
      . uri_escape($wiki->formatter->node_name_to_node_param($redirect))
      . ';format=rdf#obj';
      $rdf .= qq{" />\n};
    }
    
    $rdf .= qq{  </$objType>
</rdf:RDF>

};

    return $rdf;
}

=head1 NAME

OpenGuides::RDF - An OpenGuides plugin to output RDF/XML.

=head1 DESCRIPTION

Does all the RDF stuff for OpenGuides.  Distributed and installed as
part of the OpenGuides project, not intended for independent
installation.  This documentation is probably only useful to OpenGuides
developers.

=head1 SYNOPSIS

    use CGI::Wiki;
    use OpenGuides::Config;
    use OpenGuides::RDF;

    my $wiki = CGI::Wiki->new( ... );
    my $config = OpenGuides::Config->new( file => "wiki.conf" );
    my $rdf_writer = OpenGuides::RDF->new( wiki   => $wiki,
                                         config => $config ); 

    # RDF version of a node.
    print "Content-Type: application/rdf+xml\n\n";
    print $rdf_writer->emit_rdfxml( node => "Masala Zone, N1 0NU" );

=head1 METHODS

=over 4

=item B<new>

    my $rdf_writer = OpenGuides::RDF->new( wiki   => $wiki,
                                           config => $config ); 

C<wiki> must be a L<CGI::Wiki> object and C<config> must be an
L<OpenGuides::Config> object.  Both arguments mandatory.


=item B<emit_rdfxml>

    $wiki->write_node( "Masala Zone, N1 0NU",
		     "Quick and tasty Indian food",
		     $checksum,
		     { comment  => "New page",
		       username => "Kake",
		       locale   => "Islington" }
    );

    print "Content-Type: application/rdf+xml\n\n";
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

=head1 SEE ALSO

=over 4

=item * L<CGI::Wiki>

=item * L<http://openguides.org/>

=item * L<http://chefmoz.org/>

=back

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

Copyright (C) 2003-2006 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CREDITS

Code in this module written by Kake Pugh and Earle Martin.  Dan Brickley, Matt 
Biddulph and other inhabitants of #swig on irc.freenode.net gave useful feedback 
and advice.

=cut

1;
