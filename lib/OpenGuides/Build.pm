package OpenGuides::Build;

use strict;
use Module::Build;
use base 'Module::Build';
use Config::Tiny;
use CGI::Wiki::Setup::Pg;

my $config = Config::Tiny->read("wiki.conf");
my $dbname = $config->{_}->{dbname};
my $dbuser = $config->{_}->{dbuser};
my $dbpass = $config->{_}->{dbpass};

sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;
    print "Checking database schema...\n";
    CGI::Wiki::Setup::Pg::setup( $dbname, $dbuser, $dbpass );
}

sub ACTION_fakeinstall {
    my $self = shift;
    $self->SUPER::ACTION_fakeinstall;
    print "Checking database schema...\n";
}

1;
