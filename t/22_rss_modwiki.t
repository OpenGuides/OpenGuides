use strict;
use CGI::Wiki::Formatter::UseMod;
use CGI::Wiki::TestConfig::Utilities;
use CGI::Wiki;
use Config::Tiny;

use Test::More tests =>
  (1 + 2 * $CGI::Wiki::TestConfig::Utilities::num_stores);

use_ok( "OpenGuides::RDF" );

my %stores = CGI::Wiki::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
  SKIP: {
      skip "$store_name storage backend not configured for testing", 2
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $wiki = CGI::Wiki->new(
          store     => $store,
          formatter => CGI::Wiki::Formatter::UseMod->new );
      my $config = Config::Tiny->read( "t/21_wiki.conf" );
      my $rdf_writer = OpenGuides::RDF->new( wiki   => $wiki,
                                             config => $config );
      isa_ok( $rdf_writer, "OpenGuides::RDF" );

      my $rss = eval { $rdf_writer->make_recentchanges_rss; };
      is( $@, "", "->make_recentchanges_rss doesn't croak" );

#      print $rss;

  } # end of SKIP
}


