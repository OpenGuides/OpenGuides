use strict;
use lib "lib";
use OpenGuides::Build;
use Data::Dumper;

eval "use Config::Tiny";
die "Config::Tiny is required to configure this application.\n" if $@;

##### Find out where to install, etc.

# See if we already have some config variables set.
use lib "lib";
my %existing_config;
eval "use OpenGuides::Config";
%existing_config = %OpenGuides::Config::config unless $@;

my @questions = (
{ question =>
        "what's the name of the database that this site runs on?",
  variable => "dbname"
},
{ question => "and the database user that can access that database?",
  variable => "dbuser"
  },
{ question => "and the password that they use to access the database?",
  variable => "dbpass"
  },
{ question => "and the machine that the database is hosted on? (blank if local)",
  variable => "dbhost"
  },
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
{ question => "what directory can I use to store indexes in for searching? "
            . "***NOTE*** this directory must exist and be writeable by the "
            . "user that your script will run as.  See README for more ",
  variable => "indexing_directory",
  default  => "/usr/lib/cgi-bin/openguides/indexes/"
  },
{ question => "what's the URL of the wiki's stylesheet?",
  variable => "stylesheet_url"
},
{ question => "what's the wiki called? (should be unique)",
  variable => "site_name",
  default  => "OpenGuides Wiki"
  },
{ question => "do you want the navigation bar included on the home page?",
  variable => "navbar_on_home_page",
  default  => "y",
  type     => "y_n"
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
  },
{ question => "what's the name of the node to use for the text formatting rules link?",
  variable => "formatting_rules_node",
  default  => "Text Formatting Examples"
  },
);

my $skip_config = Module::Build->y_n("Skip OpenGuides configuration?", "n");
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

# Database type is speshull - can be one of two.
my $dbtype;
my $dbtype_qu = "what type of database do you want the site to run on?  postgres/mysql";
if ( $skip_config ) {
    $dbtype = $existing_config{dbtype} || "postgres";
} else {
    until ( $dbtype ) {
        my $def = $existing_config{dbtype} || "postgres";
	$dbtype = Module::Build->prompt("\n$dbtype_qu", $def);
	$dbtype = lc($dbtype);
	$dbtype =~ s/^\s*//;
	$dbtype =~ s/\s*$//;
	unless ( $dbtype eq "postgres" or $dbtype eq "mysql" ) {
	    undef $dbtype;
	}
    }
}

# Check they have the relevant DBD driver installed.
my %drivers = ( postgres => "DBD::Pg",
                mysql    => "DBD::mysql" );
eval "require $drivers{$dbtype}";
die "$drivers{$dbtype} is needed to run a $dbtype database" if $@;

push @answers, { question => $dbtype_qu,
                 variable => "dbtype",
                 value    => $dbtype };

foreach my $qset (@questions) {
    my $qu  = $qset->{question};
    my $type = $qset->{type} || "";
    my $var = $qset->{variable};
    my $def = $existing_config{$var} || $qset->{default};
    my $val = $def;
    unless ( $skip_config ) {
        if ( $type eq "y_n" ) {
            $val = Module::Build->y_n("\n$qu ", $def);
	} else {
            $val = Module::Build->prompt("\n$qu ", $def);
	}
    }

    # Make sure that script_url ends in a /
    if ( $var eq "script_url" and $val !~ /\/$/ ) {
        $val .= "/";
    }

    push @answers, { question => $qu,
		     variable => $var,
		     value    => $val };

    if ( $var eq "install_directory" ) {
        push @answers, {
            question => "what directory should I install the templates in?",
            variable => "template_path",
            value    => $val . "/templates" };
    }
}

# Create a user-friendly config file from answers to prompts.
open FILE, ">wiki.conf" or die "Can't open wiki.conf for writing: $!";
foreach my $ans (@answers) {
    print FILE "# $ans->{question}\n";
    print FILE "$ans->{variable} = $ans->{value}\n\n";
}
close FILE or die "Can't close wiki.conf: $!";

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

#####
##### When updating the prepreqs PLEASE REMEMBER to update PREREQUISITES.
#####

# Create the build object.
my $build = OpenGuides::Build->new(
    dist_name => "OpenGuides",
    dist_version_from => "wiki.cgi",
    license => "perl",
    requires => {
        'Algorithm::Diff' => '0.13', # for sdiff 
	'CGI' => '2.76', # unescape not in early versions, picked random
	'CGI::Carp' => 0,
	'CGI::Cookie' => 0,
	'CGI::Wiki' => '0.44',
	'CGI::Wiki::Formatter::UseMod' => '0.04', # for correct FreeUpper
        'CGI::Wiki::Plugin::Categoriser' => 0,
	'CGI::Wiki::Plugin::GeoCache' => 0,
	'CGI::Wiki::Plugin::Locator::UK' => '0.06',
	'CGI::Wiki::Plugin::RSS::ModWiki' => '0.02',
	'Config::Tiny' => 0,
	'Data::Dumper' => 0,
        $drivers{$dbtype} => 0,
	'File::Spec::Functions' => 0,
	'Geography::NationalGrid' => 0,
	'Parse::RecDescent' => 0,
	'Search::InvertedIndex' => 0,
	'Template' => 0,
        'Test::MockObject' => '0.07', # earlier doesn't use 'mock'
	'Time::Piece' => 0,
	'URI::Escape' => 0,
        'VCS::Lite' => '0.04'
	},
    build_requires => {
        'Module::Build' => '0.18', # earlier doesn't install script files
        },
    dynamic_config => 1,
    create_makefile_pl => "traditional",
);

$build->add_to_cleanup( "wiki.conf" );

# Tell OpenGuides::Build which additional scripts and templates to install.
$build->{config}{__extra_scripts}     = 
                      [ "wiki.conf", "preferences.cgi", "supersearch.cgi",
                        "newpage.cgi", "pubcrawl.cgi" ];
$build->{config}{__templates}         = [
		      "backlink_results.tt",
                      "differences.tt",
		      "display_categories.tt",
		      "display_metadata.tt",
                      "edit_conflict.tt",
                      "edit_form.tt",
                      "error.tt",
                      "footer.tt",
                      "header.tt",
                      "home_node.tt",
                      "navbar.tt",
                      "newpage.tt",
                      "node.tt",
                      "node_history.tt",
                      "openguides_information_boxes.tt",
		      "preferences.tt",
                      "pubcrawl.tt",
                      "rdf_index.tt",
                      "recent_changes.tt",
                      "search_results.tt",
                      "site_index.tt",
                      "userstats.tt",
                      "wanted_pages.tt"
    ];

# Finally write the build script.
$build->create_build_script;
