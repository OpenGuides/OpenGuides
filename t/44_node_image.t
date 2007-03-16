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

plan tests => 28;

my ( $config, $guide, $wiki );

# Clear out the database from any previous runs.
unlink "t/node.db";
unlink <t/indexes/*>;
Wiki::Toolkit::Setup::SQLite::setup( { dbname => "t/node.db" } );

# Make sure node image fields don't show up in edit form if config says
# they shouldn't.
$config = OpenGuides::Test->make_basic_config;
$config->enable_node_image( 0 );
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;

my $output = $guide->display_edit_form(
                                        id => "Red Lion",
                                        return_output => 1,
                                      );

# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::no_tag( $output, "input", { name => "node_image" },
    "node_image field not in edit form if config says it shouldn't be" );
Test::HTML::Content::no_tag( $output, "input",
                             { name => "node_image_licence" },
                             "...ditto node_image_licence" );
Test::HTML::Content::no_tag( $output, "input",
                             { name => "node_image_copyright" },
                             "...ditto node_image_copyright" );
Test::HTML::Content::no_tag( $output, "input",
                             { name => "node_image_url" },
                             "...ditto node_image_url" );

# And make sure they do if it says they should.
$config->enable_node_image( 1 );
$guide = OpenGuides->new( config => $config );
$wiki = $guide->wiki;

$output = $guide->display_edit_form(
                                     id => "Red Lion",
                                     return_output => 1,
                                   );

# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "input", { name => "node_image" },
    "node_image field appears in edit form if config says it should" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "node_image_licence" },
                             "...ditto node_image_licence" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "node_image_copyright" },
                             "...ditto node_image_copyright" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "node_image_url" },
                             "...ditto node_image_url" );

# Write all four fields to database, and make sure they're there.
OpenGuides::Test->write_data(
                              guide => $guide,
                              node  => "Red Lion",
                              node_image => "http://example.com/foo.jpg",
                              node_image_licence => "http://example.com/bar/",
                              node_image_copyright => "Kake L Pugh",
                              node_image_url => "http://example.com/~kake/",
                            );

my %node_data = $wiki->retrieve_node( "Red Lion" );
is( $node_data{metadata}{node_image}[0], "http://example.com/foo.jpg",
    "node_image saved to database on node write" );
is( $node_data{metadata}{node_image_licence}[0], "http://example.com/bar/",
    "...node_image_licence too" );
is( $node_data{metadata}{node_image_copyright}[0], "Kake L Pugh",
    "...node_image_copyright too" );
is( $node_data{metadata}{node_image_url}[0], "http://example.com/~kake/",
    "...node_image_url too" );

# Make sure their content shows up in the edit form.
$output = $guide->display_edit_form(
                                     id => "Red Lion",
                                     return_output => 1,
                                   );

# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "input",
                             { name  => "node_image",
                               value => "http://example.com/foo.jpg" },
                             "node_image field has correct value in edit form",
                           );
Test::HTML::Content::tag_ok( $output, "input",
                             { name  => "node_image_licence",
                               value => "http://example.com/bar/" },
                             "...ditto node_image_licence" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name  => "node_image_copyright",
                               value => "Kake L Pugh" },
                             "...ditto node_image_copyright" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name  => "node_image_url",
                               value => "http://example.com/~kake/" },
                             "...ditto node_image_url" );

# Make sure they're displayed when a page is viewed.
my $output = $guide->display_node(
                                   id            => "Red Lion",
                                   return_output => 1,
                                 );

# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "img",
                             { src => "http://example.com/foo.jpg" },
                             "node_image displayed on page" );
Test::HTML::Content::tag_ok( $output, "a",
                             { href => "http://example.com/bar/" },
                             "...ditto node_image_licence" );
Test::HTML::Content::text_ok( $output, "Kake L Pugh",
                              "...ditto node_image_copyright" );
Test::HTML::Content::tag_ok( $output, "a",
                             { href => "http://example.com/~kake/" },
                             "...ditto node_image_url" );

# Now try to commit some edits without giving the checksum.
$output = OpenGuides::Test->write_data( 
                                        guide => $guide,
                                        node => "Red Lion",
                                        node_image => "http://eg.com/foo.jpg",
                                        node_image_licence
                                                     => "http://eg.com/bar/",
                                        node_image_copyright => "NotKakeNo",
                                        node_image_url
                                                     => "http://eg.com/~kake/",
                                        omit_checksum => 1,
                                        return_output => 1,
                                      );

# Strip Content-Type header to stop Test::HTML::Content getting confused.
$output =~ s/^Content-Type.*[\r\n]+//m;

Test::HTML::Content::tag_ok( $output, "input",
                             { name => "node_image",
                               value => "http://example.com/foo.jpg" },
                             "Edit conflict form has input box with old "
                             . "node_image value in" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "node_image_licence",
                               value => "http://example.com/bar/" },
                              "...and one with old node_image_licence value" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "node_image_copyright",
                               value => "Kake L Pugh" },
                            "...and one with old node_image_copyright value" );
Test::HTML::Content::tag_ok( $output, "input",
                             { name => "node_image_url",
                               value => "http://example.com/~kake/" },
                              "...and one with old node_image_url value" );
Test::HTML::Content::text_ok( $output, "http://eg.com/foo.jpg",
                              "...new node_image value appears too" );
Test::HTML::Content::text_ok( $output, "http://eg.com/bar/",
                              "...as does new node_image_licence value" );
Test::HTML::Content::text_ok( $output, "NotKakeNo",
                              "...as does new node_image_copyright value" );
Test::HTML::Content::text_ok( $output, "http://eg.com/~kake/",
                              "...as does new node_image_url value" );
