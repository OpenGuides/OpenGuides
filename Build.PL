use File::Copy;
use File::Spec;
use Module::Build;
use strict;

# This magically subclasses Module::Build. We override the install action
# to install the template files for us.
my $class = Module::Build->subclass(
  code => q{
    sub ACTION_install {
      my $self = shift;
      my $ret = $self->SUPER::ACTION_install(@_);

      # Slightly hacky. We require one of the modules that we just installed.
      # then, we pull its path out of %INC, strip off the filename, and
      # install the templates there. Well, they have to go _somewhere_, and
      # perl doesn't have a good place for this stuff otherwise.

      require OpenGuides or die;
      my (undef, $path, undef) = File::Spec->splitpath($INC{'OpenGuides.pm'});

      mkdir( File::Spec->catfile( $path, "OpenGuides" ) );
      die "Can't make template install folder: $!\n" unless (-d File::Spec->catfile( $path, "OpenGuides" ) );

      my $templ_dir = File::Spec->catfile( $path, "OpenGuides", "templates" );

      mkdir( $templ_dir );
      die "Can't make template install folder: $!\n" unless (-d $templ_dir );

      print "Installing templates to $templ_dir\n";
      opendir TEMPLATES, "templates"
        or die "Can't open template source folder: $!\n";

      for (grep { /\.(tt)$/ } readdir(TEMPLATES)) {
        #print "  installing template $_\n";
        File::Copy::copy(
          File::Spec->catfile( "templates", $_ ),
          File::Spec->catfile( $templ_dir, $_ )
        ) or die "Error copying $_: $!\n";;
      }
      closedir(TEMPLATES);
      print "Done!\n";

      return $ret;
    }
  },
);

#####
##### When updating the prereqs PLEASE REMEMBER to update PREREQUISITES.
#####

# Create the build object.
my $build = $class->new(
    sign => 1,
    dist_name => "OpenGuides",
    module_name => "OpenGuides",
    dist_version_from => "lib/OpenGuides.pm",
    license => "perl",
    requires => {
        'Algorithm::Diff'                     => '0.13',  # for sdiff 
        'CGI'                                 => '2.92',  # avoid escapeHTML bug
        'CGI::Carp'                           => 0,
        'CGI::Cookie'                         => 0,
        'Wiki::Toolkit'                       => '0.74',  # for dbport
        'Wiki::Toolkit::Feed::Atom'           => 0,
        'Wiki::Toolkit::Feed::RSS'            => 0,
        'Wiki::Toolkit::Formatter::UseMod'    => 0,
        'Wiki::Toolkit::Plugin::Categoriser'  => 0,
        'Wiki::Toolkit::Plugin::Diff'         => 0,
        'Wiki::Toolkit::Plugin::Locator::Grid'=> 0,
        'Wiki::Toolkit::Plugin::RSS::Reader'  => 0,
        'Class::Accessor'                     => 0,
        'Config::Tiny'                        => 0,
        'Data::Dumper'                        => 0,
        'File::Spec::Functions'               => 0,
        'File::Temp'                          => 0,
        'Geo::Coordinates::UTM'               => 0,
        'Geography::NationalGrid'             => 0,
        'HTML::Entities'                      => 0,
        'LWP::Simple'                         => 0,
        'MIME::Lite'                          => 0,
        'Parse::RecDescent'                   => 0,
        'POSIX'                               => 0,
        'Template'                            => '2.15', # for hash.delete and string.remove vmethods
        'Term::Prompt'                        => 0,
        'Time::Piece'                         => 0,
        'URI::Escape'                         => 0,
        'XML::RSS'                            => 0,
        },
    build_requires => {
        'Module::Build' => '0.26', # API change for accessing config data
        },
    recommends => {
        'DBD::SQLite'         => 0, # for testing
        'Test::HTML::Content' => 0, # for testing, oddly enough
        'Wiki::Toolkit::Plugin::Ping' => 0, # for pinging external services
        'Geo::HelmertTransform'  => 0,      # for correct WGS84 lat/long
                                            # when using grid systems
        'Plucene'             => 0,

    },
    create_makefile_pl => "passthrough",
    script_files => [
                      "bin/openguides-install",
                      "bin/openguides-newpage-script",
                      "bin/openguides-preferences-script",
                      "bin/openguides-search-script",
                      "bin/openguides-wiki-script",
                    ],
);

$build->add_to_cleanup( "t/indexes/" );
$build->add_to_cleanup( "t/node.db" );
$build->add_to_cleanup( "t/templates/tmp/" );

# Finally write the build script.
$build->create_build_script;
