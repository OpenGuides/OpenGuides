package OpenGuides::Build;

use strict;
use Module::Build;
use base 'Module::Build';

sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;

    eval "use Config::Tiny";
    die "Config::Tiny is required to set up this application.\n" if $@;

    my $config = Config::Tiny->read("wiki.conf");
    my $dbname = $config->{_}->{dbname};
    my $dbuser = $config->{_}->{dbuser};
    my $dbpass = $config->{_}->{dbpass};
    my $dbhost = $config->{_}->{dbhost};
    my $dbtype = $config->{_}->{dbtype};

    my %cgi_wiki_exts = ( postgres => "Pg",
			  mysql    => "MySQL" );

    my $cgi_wiki_module = "CGI::Wiki::Setup::" . $cgi_wiki_exts{$dbtype};
    eval "require $cgi_wiki_module";
    die "CGI::Wiki is required to set up this application.\n" if $@;

    print "Checking database schema...\n";
    {
	no strict 'refs';
        &{$cgi_wiki_module . "::setup"}( $dbname, $dbuser, $dbpass, $dbhost );
    }
}

sub ACTION_fakeinstall {
    my $self = shift;
    $self->SUPER::ACTION_fakeinstall;
    print "Checking database schema...\n";
}

1;
