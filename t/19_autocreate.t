use strict;
use Cwd;
use OpenGuides;
use OpenGuides::Test;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    my ($error) = $@ =~ /^(.*?)\n/;
    plan skip_all =>
        "DBD::SQLite could not be used - no database to test with. ($error)";
}

plan tests => 4;

my $config = OpenGuides::Test->make_basic_config;
$config->custom_template_path( cwd . "/t/templates/" );
my $guide = OpenGuides->new( config => $config );
my $wiki = $guide->wiki;

# Clear out the database from any previous runs.
OpenGuides::Test::refresh_db();

# Write a custom template to autofill content in autocreated nodes.
eval {
    unlink cwd . "/t/templates/custom_autocreate_content.tt";
};
open( FILE, ">", cwd . "/t/templates/custom_autocreate_content.tt" )
  or die $!;
print FILE <<EOF;
Auto-generated list of places in
[% IF index_type == "Category" %]this category[% ELSE %][% index_value %][% END %]:
\@INDEX_LIST [[[% node_name %]]]
EOF
close FILE or die $!;

# Check that autocapitalisation works correctly in categories with hyphens.
OpenGuides::Test->write_data(
                              guide => $guide,
                              node  => "Vivat Bacchus",
                              categories => "Restaurants\r\nVegan-friendly",
                              locales => "Farringdon",
                            );

ok( $wiki->node_exists( "Category Vegan-Friendly" ),
    "Categories with hyphens in are auto-created correctly." );

# Check that the custom autocreate template was picked up.
my $content = $wiki->retrieve_node( "Category Vegan-Friendly" );
$content =~ s/\s+$//s;
$content =~ s/\s+/ /gs;
is( $content, "Auto-generated list of places in this category: "
              . "\@INDEX_LIST [[Category Vegan-Friendly]]",
    "Custom autocreate template works properly for categories" );

$content = $wiki->retrieve_node( "Locale Farringdon" );
$content =~ s/\s+$//s;
$content =~ s/\s+/ /gs;
is( $content, "Auto-generated list of places in Farringdon: "
              . "\@INDEX_LIST [[Locale Farringdon]]",
    "...and locales" );

# Now make sure that we have a fallback if there's no autocreate template.
unlink cwd . "/t/templates/custom_autocreate_content.tt";

OpenGuides::Test->write_data(
                              guide => $guide,
                              node  => "Bleeding Heart",
                              categories => "Pubs",
                            );
$content = $wiki->retrieve_node( "Category Pubs" );
$content =~ s/\s+$//s;
$content =~ s/\s+/ /gs;
is( $content, "\@INDEX_LINK [[Category Pubs]]",
    "Default content is picked up if autocreate template doesn't exist" );
