package OpenGuides::Feed;

use strict;

use vars qw( $VERSION );
$VERSION = '0.01';

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

sub make_feed {
    my ($self, %args) = @_;
    
    my $feed_type = $args{feed_type};
    
    my %known_types = (
                          'rss'  => 1,
                      );
                      
    croak "No feed type specified" unless $feed_type;
    croak "Unknown feed type: $feed_type" unless $known_types{$feed_type};

    if ($feed_type eq 'rss') {
        return $self->rss_maker->recent_changes(%args);
    }
}

sub rss_maker {
    my $self = shift;

    unless ($self->{rss_maker}) {
        $self->{rss_maker} = CGI::Wiki::Plugin::RSS::ModWiki->new(
            wiki                => $self->{wiki},
            site_name           => $self->{site_name},
            site_url            => $self->{config}->script_url,
            site_description    => $self->{site_description},
            make_node_url       => $self->{make_node_url},
            recent_changes_link => $self->{config}->script_url . '?action=rc',
            software_name       => 'OpenGuides',
            software_homepage   => 'http://openguides.org/',
            software_version    => $self->{og_version},
        );
    }
    
    $self->{rss_maker};
}

sub feed_timestamp {
    my ($self, %args) = @_;

    # The timestamp methods in our feeds are equivalent, we might as well
    # use the RSS one.
    $self->rss_maker->rss_timestamp(%args);
}

=head1 NAME

OpenGuides::Feed - generate data feeds for OpenGuides in various formats.

=head1 DESCRIPTION

Produces RSS 1.0 feeds for OpenGuides.  Distributed and 
installed as part of the OpenGuides project, not intended for independent
installation.  This documentation is probably only useful to OpenGuides
developers.

=head1 SYNOPSIS

    use CGI::Wiki;
    use OpenGuides::Config;
    use OpenGuides::Feed;

    my $wiki = CGI::Wiki->new( ... );
    my $config = OpenGuides::Config->new( file => "wiki.conf" );
    my $feed = OpenGuides::Feed->new( wiki       => $wiki,
                                      config     => $config,
                                      og_version => '1.0', ); 

    # Ten most recent changes in RSS format.
    print "Content-Type: application/rdf+xml\n";
    print "Last-Modified: " . $self->feed_timestamp( items => 10 ) . "\n\n";
    my %args = ( items     => 10,
                 feed_type => 'rss', );
    print $feed->make_feed( %args );

=head1 METHODS

=over 4

=item B<new>

    my $feed = OpenGuides::Feed->new( wiki       => $wiki,
                                      config     => $config,
                                      og_version => '1.0', ); 

C<wiki> must be a L<CGI::Wiki> object and C<config> must be an
L<OpenGuides::Config> object.  Both of these arguments are mandatory.
C<og_version> is an optional argument specifying the version of
OpenGuides for inclusion in the feed.

=item B<rss_maker>

Returns a raw L<CGI::Wiki::Plugin::RSS::ModWiki> object created with the values you
invoked this module with.

=item B<make_feed>

    # Ten most recent changes in RSS format.
    print "Content-Type: application/rdf+xml\n";
    print "Last-Modified: " . $feed->feed_timestamp( items => 10 ) . "\n\n";
    my %args = ( items     => 10,
                 feed_type => 'rss', );
    print $rdf_writer->make_feed( %args );

=item B<feed_timestamp>

    print "Last-Modified: " . $feed->feed_timestamp( %args ) . "\n\n";

Returns the timestamp of the data feed in POSIX::strftime style ("Tue, 29 Feb 2000 
12:34:56 GMT"), which is equivalent to the timestamp of the most recent item
in the feed. Takes the same arguments as make_recentchanges_rss(). You will most 
likely need this to print a Last-Modified HTTP header so user-agents can determine
whether they need to reload the feed or not.

=back

=head1 SEE ALSO

=over 4

=item * L<CGI::Wiki> and L<CGI::Wiki::Plugin::RSS::ModWiki>

=item * L<http://openguides.org/>

=back

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

Copyright (C) 2003-2006 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CREDITS

Written by Earle Martin, based on the original OpenGuides::RDF by Kake Pugh.

=cut

1;
