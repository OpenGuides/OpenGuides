package OpenGuides::Build;

use strict;
use Module::Build;
use OpenGuides::Config;
use base 'Module::Build';

sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;
    $self->ACTION_install_extras;

    eval "use Config::Tiny";
    die "Config::Tiny is required to set up this application.\n" if $@;

    my $config = OpenGuides::Config->new( file => "wiki.conf" );

    # Initialise the database if necessary.
    my $dbname = $config->dbname;
    my $dbuser = $config->dbuser;
    my $dbpass = $config->dbpass;
    my $dbhost = $config->dbhost;
    my $dbtype = $config->dbtype;

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

    my $config = OpenGuides::Config->new( file => "wiki.conf" );

    # Install the scripts where we were told to.
    my $install_directory    = $config->install_directory;
    my $script_name          = $config->script_name;
    my $template_path        = $config->template_path;
    my $custom_template_path = $config->custom_template_path;
    my $custom_lib_path      = $config->custom_lib_path;
    my @extra_scripts        = @{ $self->{config}{__extra_scripts} };
    my @templates            = @{ $self->{config}{__templates} };

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
            $self->add_custom_lib_path( $copy, $custom_lib_path )
              if $custom_lib_path;
        } else {
            print "Skipping $install_directory/$script_filename (unchanged)\n";
        }
        print "(Really: wiki.cgi -> $install_directory/$script_filename)\n"
            unless $script_filename eq "wiki.cgi";
    }

    if ( $FAKE ) {
        print "Trying to ensure that wiki.conf is protected.\n";
    } else {
        my $mentionswikidotconf = 0;
        print "Trying to ensure that wiki.conf is protected by .htaccess.. ";
        if (-f "$install_directory/.htaccess") {
	    if (open HTACCESS, "$install_directory/.htaccess") {
                while (<HTACCESS>) {
                    if (/wiki\.conf/) {
                        $mentionswikidotconf = 1;
                    }
                }
	        close HTACCESS;
            } else {
                warn "Could not open $install_directory/.htaccess for reading: $!";
            }
        }
        if ($mentionswikidotconf == 0) {
            if (open HTACCESS, ">>$install_directory/.htaccess") {
                print HTACCESS "# Added by OpenGuides installer\n";
                print HTACCESS "<Files wiki.conf>\ndeny from all\n</Files>";
                close HTACCESS;
                print "apparent success. You should check that this is working!\n";
            } else {
                warn "Could not open $install_directory/.htaccess for writing: $!";
            }
        } else {
            print ".htaccess appears to already mention wiki.conf.\n";
        }
    }

    foreach my $script ( @extra_scripts ) {
        if ( $FAKE ) {
	    print "$script -> $install_directory/$script (FAKE)\n";
        } else {
	    my $copy = $self->copy_if_modified( $script, $install_directory );
	    if ( $copy ) {
		$self->fix_shebang_line($copy);
		$self->make_executable($copy) unless $script eq "wiki.conf";
                $self->add_custom_lib_path( $copy, $custom_lib_path )
                  if $custom_lib_path;
	    } else {
		print "Skipping $install_directory/$script (unchanged)\n";
	    }
        }
    }

    print "Installing templates to $template_path:\n";
    foreach my $template ( @templates ) {
        if ( $FAKE ) {
            print "templates/$template -> $template_path/$template (FAKE)\n";
	} else {
	    $self->copy_if_modified(from => "templates/$template", to_dir => $template_path, flatten => 1)
                or print "Skipping $template_path/$template (unchanged)\n";
        }
    }
    if ( $FAKE ) {
        print "Making $custom_template_path.\n";
    } else {
        unless (-d $custom_template_path) {
            print "Creating directory $custom_template_path.\n";
            mkdir $custom_template_path or warn "Could not make $custom_template_path";
        }
    }
}

sub add_custom_lib_path {
    my ($self, $copy, $lib_path) = @_;
    local $/ = undef;
    open my $fh, $copy or die $!;
    my $content = <$fh>;
    close $fh or die $!;
    $content =~ s|use strict;|use strict\;\nuse lib qw( $lib_path )\;|s;
    open $fh, ">$copy" or die $!;
    print $fh $content;
    close $fh or die $!;
    return 1;
}

1;
