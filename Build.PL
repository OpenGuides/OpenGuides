use strict;
use lib "lib";
use OpenGuides::Build;
use Data::Dumper;

eval "use Config::Tiny";
die "Config::Tiny is required to configure this application.\n" if $@;

##### Find out where to install, etc.

# See if we already have some config variables set.
my $read_config = Config::Tiny->read('wiki.conf');
my %existing_config = $read_config ? %{ $read_config->{_} } : ();

my @questions = (
{ question =>
        "What's the name of the database that this site runs on?",
  variable => "dbname"
},
{ question => "...the database user that can access that database?",
  variable => "dbuser"
  },
{ question => "...the password that they use to access the database?",
  variable => "dbpass"
  },
{ question => "...the machine that the database is hosted on? (blank if local)",
  variable => "dbhost"
  },
{ question => "What do you want the script to be called?",
  variable => "script_name",
  default  => "wiki.cgi"
  },
{ question => "What directory should I install it in?",
  variable => "install_directory",
  default  => "/usr/lib/cgi-bin/openguides/"
  },
{ question => "What URL does the install directory map to?",
  variable => "script_url",
  },
{ question => "What directory can I use to store indexes in for searching? "
            . "***NOTE*** This directory must exist and be writeable by the "
            . "user that your script will run as.  See README for more on this.",
  variable => "indexing_directory",
  default  => "/usr/lib/cgi-bin/openguides/indexes/"
  },
{ question => "Do you want to enable page deletion?",
  variable => "enable_page_deletion",
  default  => "n",
  type     => "y_n"
  },
{ question => "Please specify a password for the site admin:",
  variable => "admin_pass",
  default  => "Change this!"
  },
{ question => "What's the URL of the site's stylesheet?",
  variable => "stylesheet_url"
  },
{ question => "What's the site called? (should be unique)",
  variable => "site_name",
  default  => "My OpenGuides Site"
  },
{ question => "Do you want the navigation bar included on the home page?",
  variable => "navbar_on_home_page",
  default  => "y",
  type     => "y_n"
  },
{ question => "What should the home page of the wiki be called?",
  variable => "home_name",
  default  => "Home"
  },
{ question => "How would you describe the site?",
  variable => "site_desc",
  default  => "A guide to [my city]"
  },
{ question => "What city is the site based in?",
  variable => "default_city",
  default  => "London"
  },
{ question => "What country is the site based in?",
  variable => "default_country",
  default  => "United Kingdom"
  },
{ question => "What language will the site be in? (Please give an ISO language code.)",
  variable => "default_language",
  default  => "en"
  },
{ question => "Contact email address for the site administrator?",
  variable => "contact_email"
  },
{ question => "What's the name of the node to use for the text formatting rules link?",
  variable => "formatting_rules_node",
  default  => "Text Formatting Examples"
  },
);

print <<EOF;

Beginning install process... if you already have an OpenGuides
configuration file and you don't want to have to type in all your config
parameters over again, abort this process now, copy that file to this
directory, and start again.

EOF

my $continue = Module::Build->y_n("Continue with install?", "y");
exit 0 unless $continue;

my $skip_config = Module::Build->y_n("Skip OpenGuides configuration?", "n");
if ( $skip_config ) {
    print <<EOF;
===========================================================================
Skipping OpenGuides configuration - any configuration options previously
saved will be used instead.  You may tweak your configuration now by
editing the 'wiki.conf' file produced by this script.
===========================================================================
EOF
}

my @answers;

# It is an ancient Configurer, and he chooseth one of three. 
my $dbtype;
my $dbtype_qu = "what type of database do you want the site to run on?  postgres/mysql/sqlite";
if ( $skip_config ) {
    $dbtype = $existing_config{dbtype} || "postgres";
} else {
    until ( $dbtype ) {
        my $def = $existing_config{dbtype} || "postgres";
	$dbtype = Module::Build->prompt("\n$dbtype_qu", $def);
	$dbtype = lc($dbtype);
	$dbtype =~ s/^\s*//;
	$dbtype =~ s/\s*$//;
	unless ( $dbtype eq "postgres" or $dbtype eq "mysql"
                 or $dbtype eq "sqlite" ) {
	    undef $dbtype;
	}
    }
}

# Check they have the relevant DBD driver installed.
my %drivers = ( postgres => "DBD::Pg",
                mysql    => "DBD::mysql",
                sqlite   => "DBD::SQLite",
              );
eval "require $drivers{$dbtype}";
die "$drivers{$dbtype} is needed to run a $dbtype database" if $@;

push @answers, { question => $dbtype_qu,
                 variable => "dbtype",
                 value    => $dbtype };

foreach my $qset (@questions) {
    my $qu  = $qset->{question};
    my $type = $qset->{type} || "";
    my $var = $qset->{variable};
    my $def = defined $existing_config{$var} ? $existing_config{$var}
                                             : $qset->{default};
    my $val = $def;

    if ( $dbtype eq "sqlite" and $var eq "dbname" ) {
        $qu = "what's the full filename of the SQLite database this site runs on?";
    }

    if ( $dbtype eq "sqlite" and
         ( $var eq "dbuser" or $var eq "dbpass" or $var eq "dbhost" )
       ) {
        print "$var not relevant for SQLite... skipping...\n";
        push @answers, { question => $qu,
	   	         variable => $var,
		         value    => "not-used" };
        next;
    }

    unless ( $skip_config ) {
        if ( $type eq "y_n" ) {
            # may be stored as true/false integer value
            if ( $def =~ /^\d+$/ ) {
                $def = $def ? "y" : "n";
            }
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

#####
##### When updating the prereqs PLEASE REMEMBER to update PREREQUISITES.
#####

# Create the build object.
my $build = OpenGuides::Build->new(
    dist_name => "OpenGuides",
    dist_version_from => "wiki.cgi",
    license => "perl",
    requires => {
        'Algorithm::Diff'                 => '0.13', # for sdiff 
	'CGI'                             => '2.92', # avoid escapeHTML bug
	'CGI::Carp'                       => 0,
	'CGI::Cookie'                     => 0,
	'CGI::Wiki'                       => '0.54',
	'CGI::Wiki::Formatter::UseMod'    => '0.09',
        'CGI::Wiki::Plugin::Categoriser'  => 0,
	'CGI::Wiki::Plugin::Diff'         => '0.07', # earlier buggy
	'CGI::Wiki::Plugin::GeoCache'     => 0,
	'CGI::Wiki::Plugin::Locator::UK'  => '0.09',
	'CGI::Wiki::Plugin::RSS::ModWiki' => '0.02',
        'CGI::Wiki::Plugin::RSS::Reader'  => '1.3',  # earlier versions don't support RSS 2.0
	'Config::Tiny'                    => 0,
	'Data::Dumper'                    => 0,
        $drivers{$dbtype}                 => 0,
	'File::Spec::Functions'           => 0,
	'Geography::NationalGrid'         => 0,
        'LWP::Simple'                     => 0,
	'Parse::RecDescent'               => 0,
	'Search::InvertedIndex'           => 0,
	'Template'                        => 0,
        'Test::MockObject'                => '0.07', # earlier doesn't use 'mock'
	'Time::Piece'                     => 0,
	'URI::Escape'                     => 0,
        'XML::RSS'                        => 0,
	},
    build_requires => {
        'Module::Build' => '0.18', # earlier doesn't install script files
        },
    dynamic_config => 1,
    create_makefile_pl => "passthrough"
);

$build->add_to_cleanup( "t/indexes/" );
$build->add_to_cleanup( "t/node.db" );

# Tell OpenGuides::Build which additional scripts and templates to install.
$build->{config}{__extra_scripts}     = 
                      [ "wiki.conf", "preferences.cgi", "supersearch.cgi",
                        "newpage.cgi" ];
$build->{config}{__templates}         = [
		      "backlink_results.tt",
		      "banner.tt",
                      "delete_confirm.tt",
                      "delete_done.tt",
                      "delete_password_wrong.tt",
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
                      "rdf_index.tt",
                      "recent_changes.tt",
                      "search_results.tt",
                      "site_index.tt",
                      "supersearch.tt",
                      "userstats.tt",
                      "wanted_pages.tt"
    ];

# Finally write the build script.
$build->create_build_script;
