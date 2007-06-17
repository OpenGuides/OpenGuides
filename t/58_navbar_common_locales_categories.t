use strict;
use OpenGuides;
use OpenGuides::Test;
use Test::More;
use Wiki::Toolkit::Setup::SQLite;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD::SQLite not installed - no database to test with";
    exit 0;
}

eval { require Test::HTML::Content; };
if ( $@ ) {
    plan skip_all => "Test::HTML::Content not installed";
    exit 0;
}

sub get_recent_changes {
    my ($guide) = @_;

    my $output = $guide->display_recent_changes( return_output => 1 );
    $output =~ s/^Content-Type.*[\r\n]+//m;
    
    return $output;
}

sub get_preferences {
    my ($guide) = @_;

    return OpenGuides::Template->output(
        wiki         => $guide->wiki,
        config       => $guide->config,
        template     => "preferences.tt",
        content_type => '',
        vars         => {
                          not_editable => 1,
                          show_form    => 1
                        },
    );
}

my %pages = (
    recent_changes => \&get_recent_changes,
    preferences    => \&get_preferences,
);

plan tests => 4 * keys %pages;

my ( $config, $guide, $wiki, $output );

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;
Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );

while (my ($page, $get_content) = each %pages) {

    # Make a guide with common categories and locales enabled.
    $config = OpenGuides::Test->make_basic_config;
    $config->enable_common_categories( 1 );
    $config->enable_common_locales( 1 );
    $guide = OpenGuides->new( config => $config );

    # Make sure common categories and locales show up.
    $output = $get_content->($guide);

    Test::HTML::Content::tag_ok( $output, "div", { id => "navbar_categories" },
                                 "common categories in $page navbar" );
    Test::HTML::Content::tag_ok( $output, "div", { id => "navbar_locales" },
                                 "...common locales too" );

    # Now make a guide with common categories and locales disabled.
    $config = OpenGuides::Test->make_basic_config;
    $guide = OpenGuides->new( config => $config );

    # Make sure common categories/locales are omitted.
    $output = $get_content->($guide);

    Test::HTML::Content::no_tag( $output, "div", { id => "navbar_categories" },
                                 "common categories in $page navbar" );
    Test::HTML::Content::no_tag( $output, "div", { id => "navbar_locales" },
                                 "...common locales too" );
}
