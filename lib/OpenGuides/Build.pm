package OpenGuides::Build;

use strict;
use Module::Build;
use base 'Module::Build';

sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;

    eval "use Config::Tiny";
    die "Config::Tiny is required to set up this application.\n" if $@;

    eval "use CGI::Wiki::Setup::Pg";
    die "CGI::Wiki is required to set up this application.\n" if $@;

    my $config = Config::Tiny->read("wiki.conf");
    my $dbname = $config->{_}->{dbname};
    my $dbuser = $config->{_}->{dbuser};
    my $dbpass = $config->{_}->{dbpass};
    my $dbhost = $config->{_}->{dbhost};

    print "Checking database schema...\n";
    CGI::Wiki::Setup::Pg::setup( $dbname, $dbuser, $dbpass, $dbhost );
}

sub ACTION_fakeinstall {
    my $self = shift;
    $self->SUPER::ACTION_fakeinstall;
    print "Checking database schema...\n";
}

1;
