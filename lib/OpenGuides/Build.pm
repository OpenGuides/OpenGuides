package OpenGuides::Build;

use strict;
use Module::Build;
use base 'Module::Build';

sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;
    $self->ACTION_install_extras;

    eval "use Config::Tiny";
    die "Config::Tiny is required to set up this application.\n" if $@;

    my $config = Config::Tiny->read("wiki.conf");

    # Initialise the database if necessary.
    my $dbname = $config->{_}->{dbname};
    my $dbuser = $config->{_}->{dbuser};
    my $dbpass = $config->{_}->{dbpass};
    my $dbhost = $config->{_}->{dbhost};
    my $dbtype = $config->{_}->{dbtype};

    my %cgi_wiki_exts = ( postgres => "Pg",
			  mysql    => "MySQL",
			  sqlite   => "SQLite" );

    my $cgi_wiki_module = "CGI::Wiki::Setup::" . $cgi_wiki_exts{$dbtype};
    eval "require $cgi_wiki_module";
    die "There was a problem: $@" if $@;

    print "Checking database schema...\n";
    {
	no strict 'refs';
        &{$cgi_wiki_module . "::setup"}( $dbname, $dbuser, $dbpass, $dbhost );
    }
}

sub ACTION_fakeinstall {
    my $self = shift;
    $self->SUPER::ACTION_fakeinstall;
    $self->ACTION_install_extras( fake => 1 );
    print "Checking database schema...\n";
}

sub ACTION_install_extras {
    my ($self, %args) = @_;
    my $FAKE = $args{fake} || 0;

    eval "use Config::Tiny";
    die "Config::Tiny is required to set up this application.\n" if $@;

    my $config = Config::Tiny->read("wiki.conf");

    # Install the scripts where we were told to.
    my $install_directory = $config->{_}->{install_directory};
    my $script_name       = $config->{_}->{script_name};
    my $template_path     = $config->{_}->{template_path};
    my @extra_scripts     = @{ $self->{config}{__extra_scripts} };
    my @templates         = @{ $self->{config}{__templates} };

    print "Installing scripts to $install_directory:\n";
    # Allow for blank script_name - assume "index.cgi".
        my $script_filename = $script_name || "index.cgi";
    if ( $FAKE ) {
        print "wiki.cgi -> $install_directory/$script_filename (FAKE)\n";
    } else {
        if ( $script_filename ne "wiki.cgi" ) {
            File::Copy::copy("wiki.cgi", $script_filename)
	        or die "Can't copy('wiki.cgi', '$script_filename'): $!";
	}
        my $copy = $self->copy_if_modified(
                                            $script_filename,
                                            $install_directory
                                          );
        if ( $copy ) {
            $self->fix_shebang_line($copy);
	    $self->make_executable($copy);
        } else {
            print "Skipping $install_directory/$script_filename (unchanged)\n";
        }
        print "(Really: wiki.cgi -> $install_directory/$script_filename)\n"
            unless $script_filename eq "wiki.cgi";
    }

    foreach my $script ( @extra_scripts ) {
        if ( $FAKE ) {
	    print "$script -> $install_directory/$script (FAKE)\n";
        } else {
	    my $copy = $self->copy_if_modified( $script, $install_directory );
	    if ( $copy ) {
		$self->fix_shebang_line($copy);
		$self->make_executable($copy) unless $script eq "wiki.conf";
	    } else {
		print "Skipping $install_directory/$script (unchanged)\n";
	    }
        }
    }

    print "Installing templates to $install_directory/templates:\n";
    foreach my $template ( @templates ) {
        if ( $FAKE ) {
            print "templates/$template -> $install_directory/templates/$template (FAKE)\n";
	} else {
	    $self->copy_if_modified("templates/$template", $install_directory)
                or print "Skipping $install_directory/templates/$template (unchanged)\n";
        }
    }
}

1;
