#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Cookie;
use Config::Tiny;
use Template;

my $cgi = CGI->new();
my $action = $cgi->param('action') || '';

if ( $action eq "set_preferences" ) {
    set_preferences();
} else {
    show_form();
}

exit 0;

sub set_preferences {
    my $username = $cgi->param("username") || "";
    my $gc_link  = $cgi->param('include_geocache_link') || 0,
    my @cookies;
    push @cookies, CGI::Cookie->new( -name    => 'username',
				     -value   => $username,
				     -expires => '+12M',
    );

    push @cookies, CGI::Cookie->new( -name    => 'include_geocache_link',
				     -value   => $gc_link,
				     -expires => '+12M',
    );
    print $cgi->header( -cookie => \@cookies );

    process_prefs_template( username              => $username,
			    include_geocache_link => $gc_link );
}


sub show_form {
    # Get defaults for form fields from cookies.
    my %cookies = CGI::Cookie->fetch;
    my $username = $cookies{"username"} ? $cookies{"username"}->value : "";
    my $gc_link  = $cookies{"include_geocache_link"} ? $cookies{"include_geocache_link"}->value : 0;

    print $cgi->header;
    process_prefs_template( show_form             => 1,
			    username              => $username,
			    include_geocache_link => $gc_link );
}


sub process_prefs_template {
    # Some TT params are passed in to the sub.
    my %tt_vars = @_;

    # Others are global and we get them from the config file.
    my $config = Config::Tiny->read("wiki.conf");
    foreach my $param ( qw( site_name stylesheet_url script_name home_name
			    ) ) {
        $tt_vars{$param} = $config->{_}->{$param};
    }

    # This isn't a page you can edit.
    $tt_vars{not_editable} = 1;

    my %tt_conf = ( INCLUDE_PATH => $config->{_}->{template_path},
    );

    my $tt = Template->new( \%tt_conf );
    $tt->process( "preferences.tt", \%tt_vars ) or warn $tt->error;
}
 
