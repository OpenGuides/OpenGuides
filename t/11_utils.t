use strict;
use Config::Tiny;
use Test::More tests => 9;

# Need to use a BEGIN block for the test or we get "Too late to run INIT block"
# from Class::Delegation

BEGIN {
  use_ok( "OpenGuides::Utils" );
}

eval { my $wiki = OpenGuides::Utils->make_wiki_object; };
ok( $@, "->make_wiki_object croaks if no config param supplied" );

eval { my $wiki = OpenGuides::Utils->make_wiki_object( config => "foo" ); };
ok( $@, "...and if config param isn't a Config::Tiny object" );

my $config = Config::Tiny->read( "wiki.conf" )
    or die "Couldn't read wiki.conf";
my $wiki = eval { OpenGuides::Utils->make_wiki_object( config => $config ); };
is( $@, "", "...but not if a Config::Tiny object is supplied" );
isa_ok( $wiki, "CGI::Wiki" );

ok( $wiki->store,      "...and store defined" );
ok( $wiki->search_obj, "...and search defined" );
ok( $wiki->formatter,  "...and formatter defined" );

# Ensure that we take note of any defined dbhost - note that this test
# is only useful if we've defined a dbhost during perl Build.PL
is( $wiki->store->dbhost, $config->{_}->{dbhost}, "dbhost taken note of" );
