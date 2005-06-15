use strict;
use lib "lib";
use OpenGuides::Build;
use OpenGuides::Config;
use Data::Dumper;

eval "use Config::Tiny";
die "Config::Tiny is required to configure this application.\n" if $@;

print <<EOF;

Beginning install process... if you already have an OpenGuides
configuration file and you don't want to have to type in all your config
parameters over again, abort this process now, copy that file to this
directory, and start again.

EOF

my $continue = Module::Build->y_n("Continue with install?", "y");
exit 0 unless $continue;

my $existing_config = OpenGuides::Config->new( file => "wiki.conf" );

my %yn_vars = map { $_ => 1 }
   qw(use_plucene enable_page_deletion navbar_on_home_page backlinks_in_title);

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
my $dbtype_qu = $existing_config->dbtype__qu;
if ( $skip_config ) {
    $dbtype = $existing_config->dbtype;
} else {
    until ( $dbtype ) {
        my $def = $existing_config->dbtype;
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
warn "$drivers{$dbtype} is needed to run a $dbtype database" if $@;

push @answers, { question => $dbtype_qu,
                 variable => "dbtype",
                 value    => $dbtype };

my $install_directory; # used to suggest template paths
my $use_plucene; # keep track of this so we know what to put in prereqs
foreach my $var ( qw(
   dbname dbuser dbpass dbhost script_name
   install_directory template_path custom_template_path script_url
   custom_lib_path use_plucene indexing_directory enable_page_deletion
   admin_pass stylesheet_url site_name navbar_on_home_page home_name
   site_desc default_city default_country contact_email default_language
   formatting_rules_node backlinks_in_title
  ) ) {
    my $q_method = $var . "__qu";
    my $qu  = $existing_config->$q_method;
    my $type = $yn_vars{$var} ? "y_n" : "";
    my $def = $existing_config->$var;
    my $val = $def;

    # Override dbname question for SQLite only.
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

    # Make sensible suggestions for template paths if we don't already
    # have them stored.  Not really a default, but a useful hint/shortcut.
    if ( $var eq "template_path" && !defined $existing_config->$var ) {
        $def = $install_directory;
        $def .= "/" unless $def =~ m|/$|;
        $def .= "templates";
    }
    if ( $var eq "custom_template_path" && !defined $existing_config->$var ) {
        $def = $install_directory;
        $def .= "/" unless $def =~ m|/$|;
        $def .= "custom-templates";
    }

    # Here is where we actually ask the questions.
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

    # Store install_directory so we can use it to suggest template paths.
    $install_directory = $val if $var eq "install_directory";

    # Keep track of chosen search method so we know what to put in prereqs.
    # From Module::Build docs: ->y_n returns a Perl boolean true or false.
    $use_plucene = 1 if $var eq "use_plucene" and $val;

    # Make sure that script_url ends in a /
    if ( $var eq "script_url" and $val !~ /\/$/ ) {
        $val .= "/";
    }

    push @answers, { question => $qu,
		     variable => $var,
		     value    => $val };
}

# Now deal with the geo stuff.
my $geo_handler;
my $geo_handler_qu = "Distance calculation methods available are:"
                   . "\n  1) British National Grid"
                   . "\n  2) Irish National Grid"
                   . "\n  3) UTM ellipsoid"
                   . "\nWhich would you like to use?";

if ( $skip_config ) {
    # We default to GB National Grid for historical reasons.
    $geo_handler = $existing_config->geo_handler;
} else {
    my $choice;
    until ( $choice ) {
        my $def = $existing_config->geo_handler;
	$choice = Module::Build->prompt("\n".$geo_handler_qu, $def);
	$choice =~ s/^\s*//;
	$choice =~ s/\s*$//;
	unless ( $choice eq "1" or $choice eq "2" or $choice eq "3" ) {
            undef $choice;
	}
    }
    $geo_handler = $choice;
}

$geo_handler_qu =~ s/\n//gs;
push @answers, {
                 question => $geo_handler_qu,
                 variable => "geo_handler",
                 value    => $geo_handler,
               };

if ( $geo_handler eq "3" ) {
    my $qu = $existing_config->ellipsoid__qu;
    my $ellipsoid;
    if ( $skip_config ) {
        $ellipsoid = $existing_config->ellipsoid;
    } else {
        my $def = $existing_config->ellipsoid;
        $ellipsoid = Module::Build->prompt("\n".$qu, $def);
	$ellipsoid =~ s/^\s*//;
	$ellipsoid =~ s/\s*$//;
    }
    push @answers, {
                     question => $qu,
                     variable => "ellipsoid",
                     value    => $ellipsoid,
                   };
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

my $search_module = $use_plucene ? "Plucene" : "Search::InvertedIndex";

# Create the build object.
my $build = OpenGuides::Build->new(
    sign => 1,
    dist_name => "OpenGuides",
    dist_version_from => "wiki.cgi",
    license => "perl",
    requires => {
        'Algorithm::Diff'                 => '0.13', # for sdiff 
	'CGI'                             => '2.92', # avoid escapeHTML bug
	'CGI::Carp'                       => 0,
	'CGI::Cookie'                     => 0,
	'CGI::Wiki'                       => '0.62', # fixed delete version
	'CGI::Wiki::Formatter::UseMod'    => '0.16', # macros
        'CGI::Wiki::Plugin::Categoriser'  => 0,
	'CGI::Wiki::Plugin::Diff'         => '0.07', # earlier buggy
	'CGI::Wiki::Plugin::Locator::Grid'=> '0.02', # cope with sqlite 3
	'CGI::Wiki::Plugin::RSS::ModWiki' => '0.071', # provides RSS timestamp
        'CGI::Wiki::Plugin::RSS::Reader'  => '1.3',  # earlier versions don't support RSS 2.0
        'Class::Accessor'                 => 0,
	'Config::Tiny'                    => 0,
	'Data::Dumper'                    => 0,
        $drivers{$dbtype}                 => 0,
	'File::Spec::Functions'           => 0,
        'File::Temp'                      => 0,
	'Geography::NationalGrid'         => 0,
        'LWP::Simple'                     => 0,
	'Parse::RecDescent'               => 0,
	$search_module                    => 0,
	'Template'                        => 0,
        'Test::MockObject'                => '0.07', # earlier doesn't use 'mock'
	'Time::Piece'                     => 0,
	'URI::Escape'                     => 0,
        'XML::RSS'                        => 0,
	},
    build_requires => {
        'Module::Build' => '0.18', # earlier doesn't install script files
        },
    recommends => {
        'DBD::SQLite'         => 0, # for testing
        'Test::HTML::Content' => 0, # for testing, oddly enough
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
