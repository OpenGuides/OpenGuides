package OpenGuides::Config;
use strict;

use Carp qw( croak );
use Config::Tiny;

use base qw( Class::Accessor );
my @variables = qw(
   dbtype dbname dbuser dbpass dbhost dbencoding
   script_name install_directory script_url
   custom_lib_path use_plucene indexing_directory enable_page_deletion
   admin_pass stylesheet_url site_name navbar_on_home_page home_name
   site_desc default_city default_country contact_email 
   default_language http_charset ping_services
   formatting_rules_node formatting_rules_link backlinks_in_title template_path
   custom_template_path geo_handler ellipsoid gmaps_api_key centre_long
   centre_lat default_gmaps_zoom default_gmaps_search_zoom force_wgs84
   licence_name licence_url licence_info_url moderation_requires_password
   enable_node_image enable_common_categories enable_common_locales
);
my @questions = map { $_ . "__qu" } @variables;
OpenGuides::Config->mk_accessors( @variables );
OpenGuides::Config->mk_accessors( @questions );

=head1 NAME

OpenGuides::Config - Handle OpenGuides configuration variables.

=head1 DESCRIPTION

Does config stuff for OpenGuides.  Distributed and installed as part of
the OpenGuides project, not intended for independent installation.
This documentation is probably only useful to OpenGuides developers.

=head1 METHODS

=over

=item B<new>

  my $config = OpenGuides::Config->new( file => "wiki.conf" );

Initialises itself from the config file specified.  Variables which
are not set in that file, and which have sensible defaults, will be
initialised as described below in ACCESSORS; others will be given a
value of C<undef>.

  my $config = OpenGuides::Config->new( vars => { dbname => "foo" } );

As above but gets variables from a supplied hashref instead.

=cut

sub new {
    my $class = shift;
    my $self = { };
    bless $self, $class;
    return $self->_init( @_ );
}

sub _init {
    my ($self, %args) = @_;

    # Here are the defaults for the variable values.
    # Don't forget to add to INSTALL when changing these.
    my %defaults = (
                     dbtype => "postgres",
                     script_name => "wiki.cgi",
                     install_directory => "/usr/lib/cgi-bin/openguides/",
                     use_plucene => 1,
                     indexing_directory => "/usr/lib/cgi-bin/openguides/indexes/",
                     enable_page_deletion => 0,
                     moderation_requires_password => 1,
                     admin_pass => "Change This!",
                     enable_node_image => 1,
                     enable_common_categories => 0,
                     enable_common_locales => 0,
                     ping_services => "",
                     site_name => "Unconfigured OpenGuides site",
                     navbar_on_home_page => 1,
                     home_name => "Home",
                     site_desc => "A default configuration of OpenGuides",
                     default_city => "",
                     default_country => "",
                     default_language => "en",
                     http_charset => "",
                     formatting_rules_node => "Text Formatting Examples",
                     formatting_rules_link => "http://openguides.org/page/text_formatting",
                     backlinks_in_title => 0,
                     geo_handler => 1,
                     ellipsoid => "WGS-84",
                     centre_long => 0,
                     centre_lat => 0,
                     default_gmaps_zoom => 5,
                     default_gmaps_search_zoom => 3,
                     force_wgs84 => 0,
                     licence_name => "",
                     licence_url => "",
                     licence_info_url => ""
                   );

    # See if we already have some config variables set.
    my %stored;
    if ( $args{file} ) {
        my $read_config = Config::Tiny->read( $args{file} ) or
            croak "Cannot read config file '$args{file}': $Config::Tiny::errstr";
        %stored = %{$read_config->{_}};
    } elsif ( $args{vars} ) {
        %stored = %{ $args{vars} };
    }

    # Set all defaults first, then set the stored values.  This allows us
    # to make sure that the stored values override the defaults yet be sure
    # to set any variables which have stored values but not defaults.
    foreach my $var ( keys %defaults ) {
        $self->$var( $defaults{$var} );
    }
    foreach my $var ( keys %stored ) {
        if ( $self->can( $var ) ) { # handle any garbage in file gracefully
            $self->$var( $stored{$var} );
	} else {
		use Data::Dumper; die Dumper \%stored;
            warn "Don't know what to do with variable '$var'";
        }
    }

    # And the questions.
    # Don't forget to add to INSTALL when changing these.
    my %questions = (
        dbtype => "What type of database do you want the site to run on?  postgres/mysql/sqlite",
        dbname => "What's the name of the database that this site runs on?",
        dbuser => "...the database user that can access that database?",
        dbpass => "...the password that they use to access the database?",
        dbhost => "...the machine that the database is hosted on? (blank if local)",
        dbencoding => "...the encoding that your database uses? (blank if default)",
        script_name => "What do you want the script to be called?",
        install_directory => "What directory should I install it in?",
        template_path => "What directory should I install the templates in?",
        custom_template_path => "Where should I look for custom templates?",
        script_url => "What URL does the install directory map to?",
        custom_lib_path => "Do you want me to munge a custom lib path into the scripts?  If so, enter it here.  Separate path entries with whitespace.",
        use_plucene => "Do you want to use Plucene for searching? (recommended, but see Changes file before saying yes to this if you are upgrading)",
        indexing_directory => "What directory can I use to store indexes in for searching? ***NOTE*** This directory must exist and be writeable by the user that your script will run as.  See README for more on this.",
        enable_page_deletion => "Do you want to enable page deletion?",
        moderation_requires_password => "Is the admin password required for moderating pages?",
        admin_pass => "Please specify a password for the site admin.",
        stylesheet_url => "What's the URL of the site's stylesheet?",
        enable_node_image => "Should nodes be allowed to have an externally hosted image?",
        enable_common_categories => "Do you want a common list of categories shown on all node pages?",
        enable_common_locales => "Do you want a common list of locales shown on all node pages?",
        ping_services => "Which services do you wish to ping whenever you write a page? Can be pingerati, geourl, or both",
        site_name => "What's the site called? (should be unique)",
        navbar_on_home_page => "Do you want the navigation bar included on the home page?",
        home_name => "What should the home page of the wiki be called?",
        site_desc => "How would you describe the site?",
        default_city => "What city is the site based in?",
        default_country => "What country is the site based in?",
        contact_email => "Contact email address for the site administrator?",
        default_language => "What language will the site be in? (Please give an ISO language code.)",
        http_charset => "What character set should we put in the http headers? (This won't change the character set internally, just what it's reported as). Leave blank for none to be sent",
        formatting_rules_node => "What's the name of the node or page to use for the text formatting rules link (this is by default an external document, but if you make formatting_rules_link empty, it will be a wiki node instead",
        formatting_rules_link => "What URL do you want to use for the text formatting rules (leave blank to use a wiki node instead)?",
        backlinks_in_title => "Make node titles link to node backlinks (C2 style)?",
        ellipsoid => "Which ellipsoid do you want to use? (eg 'Airy', 'WGS-84')",
        gmaps_api_key => "Do you have a Google Maps API key to use with this guide? If you enter it here the Google Maps functionality will be automatically enabled.",
        centre_long => "What is the longitude of the centre point of a map to draw for your guide? (This question can be ignored if you aren't using Google Maps). You may paste in a Google Maps URL here (hint: copy URL from 'Link to this page')",
        centre_lat => "What is the latitude of the centre point of a map to draw for your guide? (This question can be ignored if you aren't using Google Maps)",
        default_gmaps_zoom => "What default zoom level shall we use for Google Maps? (This question can be ignored if you aren't using Google Maps)",
        default_gmaps_search_zoom => "What default zoom level shall we use for Google Maps in the search results? (This question can be ignored if you aren't using Google Maps)",
        force_wgs84 => "Forcibly treat stored lat/long data as if they used the WGS84 ellipsoid?",
        licence_name => "What licence will you use for the guide?",
        licence_url => "What is the URL to your licence?",
        licence_info_url => "What is the URL to your local page about your licensing policy?"
    );

    foreach my $var ( keys %questions ) {
        my $method = $var . "__qu";
        $self->$method( $questions{$var} );
    }

    return $self;
}

=back

=head1 ACCESSORS

Each of the accessors described below is read-write.  Additionally,
for each of them, there is also a read-write accessor called, for
example, C<dbname__qu>.  This will contain an English-language
question suitable for asking for a value for that variable.  You
shouldn't write to them, but this is not enforced.

The defaults mentioned below are those which are applied when
C<< ->new >> is called, to variables which are not supplied in
the config file.

=over

=item * dbname

=item * dbuser

=item * dbpass

=item * dbhost

=item * dbencoding

=item * script_name (default: C<wiki.cgi>)

=item * install_directory (default: C</usr/lib/cgi-bin/openguides/>)

=item * script_url (this is constrained to always end in C</>)

=cut

sub script_url {
    my $self = shift;
    # See perldoc Class::Accessor - can't just use SUPER.
    my $url = $self->_script_url_accessor( @_ );
    $url .= "/" unless $url =~ /\/$/;
    return $url;
}

=item * custom_lib_path

=item * use_plucene (default: true)

=item * indexing_directory (default: C</usr/lib/cgi-bin/openguides/indexes>)

=item * enable_page_deletion (default: false)

=item * admin_pass (default: C<Change This!>)

=item * stylesheet_url

=item * site_name (default: C<Unconfigured OpenGuides site>)

=item * navbar_on_home_page (default: true)

=item * home_name (default: C<Home>)

=item * site_desc (default: C<A default configuration of OpenGuides>)

=item * default_city (default: C<London>)

=item * default_country (default: C<United Kingdom>)

=item * default_language (default: C<en>)

=item * http_charset

=item * contact_email

=item * formatting_rules_node (default: C<Text Formatting Examples>)

=item * formatting_rules_link (default: C<http://openguides.org/page/text_formatting>

=item * backlinks_in_title (default: false)

=item * geo_handler (default: C<1>)

=item * ellipsoid (default: C<WGS-84>)

=item * gmaps_api_key

=item * centre_long

=item * centre_lat

=item * default_gmaps_zoom

=item * default_gmaps_search_zoom

=item * force_wgs84

=item * licence_name

=item * licence_url

=item * licence_info_url

=back

=head1 AUTHOR

The OpenGuides Project (openguides-dev@lists.openguides.org)

=head1 COPYRIGHT

     Copyright (C) 2004-2006 The OpenGuides Project.  All Rights Reserved.

The OpenGuides distribution is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<OpenGuides>

=cut

1;
