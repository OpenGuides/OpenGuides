use Module::Build;
use Data::Dumper;
use strict;

eval "use Config::Tiny";
die "Config::Tiny is required to configure this application.\n" if $@;

# Create the build object.
my $build = Module::Build->new(
    dist_name => "OpenGuides",
    dist_version_from => "wiki.cgi",
    license => "perl",
    script_files => [ "wiki.cgi", "wiki.conf", "username.cgi",
		      "supersearch.cgi",
		      "templates/backlink_results.tt",
		      "templates/display_metadata.tt",
                      "templates/edit_conflict.tt",
                      "templates/edit_form.tt",
                      "templates/footer.tt",
                      "templates/header.tt",
                      "templates/home_node.tt",
                      "templates/navbar.tt",
                      "templates/node.tt",
                      "templates/node_history.tt",
                      "templates/rdf_index.tt",
                      "templates/recent_changes.tt",
                      "templates/search_results.tt",
                      "templates/site_index.tt",
                      "templates/userstats.tt"
		      ],
    requires => {
	'CGI' => 0,
	'CGI::Carp' => 0,
	'CGI::Cookie' => 0,
	'CGI::Wiki' => '0.28',
	'CGI::Wiki::Formatter::UseMod' => '0.02',
	'CGI::Wiki::Plugin::Locator::UK' => '0.04',
	'CGI::Wiki::Plugin::RSS::ModWiki' => '0.01',
	'Config::Tiny' => 0,
	'Data::Dumper' => 0,
	'File::Spec::Functions' => 0,
	'Geography::NationalGrid' => 0,
	'Parse::RecDescent' => 0,
	'Template' => 0,
	'Time::Piece' => 0,
	'URI::Escape' => 0
	},
    dynamic_config => 1
);

#print Dumper $build;

# See if we already have some config variables set.
use lib "lib";
my %existing_config;
eval "use OpenGuides::Config";
%existing_config = %OpenGuides::Config::config unless $@;

my @questions = (
{ question => "what do you want the script to be called?",
  variable => "script_name",
  default  => "wiki.cgi"
  },
{ question => "what directory should I install it in?",
  variable => "install_directory",
  default  => "/usr/lib/cgi-bin/openguides/"
  },
{ question => "what URL does the install directory map to?",
  variable => "script_url",
  },
{ question => "what directory can I use to store indexes in for searching?",
  variable => "indexing_directory",
  default  => "/usr/lib/cgi-bin/openguides/indexes/"
  },
{ question => "what's the URL of the wiki's stylesheet?",
  variable => "stylesheet_url"
},
{ question =>
        "what's the name of the postgres database that this site runs on?",
  variable => "dbname"
},
{ question => "and the database user that can access that database?",
  variable => "dbuser"
  },
{ question => "and the password that they use to access the database?",
  variable => "dbpass"
  },
{ question => "what's the wiki called?",
  variable => "site_name",
  default  => "OpenGuides Wiki"
  },
{ question => "what should the home page of the wiki be called?",
  variable => "home_name",
  default  => "Home"
  },
{ question => "how would you describe the wiki?",
  variable => "site_desc",
  default  => "Development site for openguides.org's software"
  },
{ question => "what city is the wiki based in?",
  variable => "default_city",
  default  => "London"
  },
{ question => "what country is the wiki based in?",
  variable => "default_country",
  default  => "United Kingdom"
  },
{ question => "contact email address for the wiki admin?",
  variable => "contact_email"
  }
);

my $skip_config = $build->y_n("Skip OpenGuides configuration?", "n");
if ( $skip_config ) {
    print <<EOF;
===========================================================================
Skipping OpenGuides configuration - any configuration options previously
saved will be used instead.  You may tweak your configuration now by
editing the 'wiki.conf' file produced by this script, but changes made to
that file will *not* stick around for the next time you install OpenGuides.
===========================================================================
EOF
}

my @answers;
foreach my $qset (@questions) {
    my $qu  = $qset->{question};
    my $var = $qset->{variable};
    my $def = $existing_config{$var} || $qset->{default};
    my $val = $def;
    unless ( $skip_config ) {
        $val = $build->prompt("\n$qu ", $def);
    }
    push @answers, { question => $qu,
		     variable => $var,
		     value    => $val };

    # For now we put the templates in the same place as the script, since I
    # can't figure out how to get Module::Build to put them in a subdirectory.
    if ( $var eq "install_directory" ) {
        push @answers, { question => "what directory are the templates in?",
			 variable => "template_path",
			 value    => $val };
    }
}

open FILE, ">wiki.conf" or die "Can't open wiki.conf for writing: $!";
foreach my $ans (@answers) {
    print FILE "# $ans->{question}\n";
    print FILE "$ans->{variable} = $ans->{value}\n\n";
}
close FILE or die "Can't close wiki.conf: $!";
$build->add_to_cleanup( "wiki.conf" );

# Now use Config::Tiny to read it all back in - bit convoluted I know.
my $read_config = Config::Tiny->read('wiki.conf');
%existing_config = %{ $read_config->{_} };

# And pop it in OpenGuides::Config
%OpenGuides::Config::config = %existing_config;
open OUT, ">lib/OpenGuides/Config.pm"
    or die "Can't open lib/OpenGuides/Config.pm for writing: $!";

# Sigh, I am still cargo culting this line; one day I will figure out
# how it works (Kake).
print OUT Data::Dumper->new([ \%OpenGuides::Config::config ],
                            [ '*OpenGuides::Config::config' ]
                           )->Dump,
    "\n1;\n";

# Set the install directory:
#  - scripts go in the actual directory.
$build->{config}{installscript} = $existing_config{install_directory};
#  - and modules go in lib/
$build->{config}{sitelib} = $existing_config{install_directory} . "/lib";

#print Dumper $build;

# Finally write the build script.
$build->create_build_script;
                    
