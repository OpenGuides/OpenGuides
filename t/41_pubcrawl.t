use strict;
use CGI::Wiki;
use CGI::Wiki::TestConfig::Utilities;
use Test::More tests =>
  (1 + 12 * $CGI::Wiki::TestConfig::Utilities::num_stores);

use_ok( "OpenGuides::UK::PubCrawl" );

my %stores = CGI::Wiki::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
  SKIP: {
      skip "$store_name storage backend not configured for testing", 12
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $wiki = CGI::Wiki->new( store => $store );
      my $locator = CGI::Wiki::Plugin::Locator::UK->new;
      $wiki->register_plugin( plugin => $locator );

      # Test unsuccessful creation.
      eval { OpenGuide::UK::PubCrawl->new; };
      ok( $@, "->new dies if no locator parameter supplied" );
      eval { OpenGuide::UK::PubCrawl->new( locator => "foo" ); };
      ok ($@, "...and if locator param isn't a locator" );

      # Test successful creation.
      my $crawler = eval {
          OpenGuides::UK::PubCrawl->new( locator => $locator );
      };
      is ($@, "",
          "...but not if a CGI::Wiki::Plugin::Locator::UK is supplied" );
      isa_ok( $crawler, "OpenGuides::UK::PubCrawl" );
      $wiki->register_plugin( plugin => $crawler );

      # Put in some test data.
      $wiki->write_node( "Cittie Of Yorke", "pub", undef,
                         { os_x => 531035, os_y => 181648,
                           category => [ "Pubs" ] } )
        or die "Couldn't write node";
      $wiki->write_node( "Ivy House", "pub", undef,
                         { os_x => 530503, os_y => 181602,
                           category => [ "Pubs" ] } )
        or die "Couldn't write node";
      $wiki->write_node( "Knights Templar", "pub", undef,
                         { os_x => 531137, os_y => 181222,
                           category => [ "Pubs" ] } )
        or die "Couldn't write node";
      $wiki->write_node( "Penderel's Oak", "pub", undef,
                         { os_x => 530860, os_y => 181576,
                           category => [ "Pubs" ] } )
        or die "Couldn't write node";
      $wiki->write_node( "Princess Louise", "pub", undef,
                         { os_x => 530424, os_y => 181489,
                           category => [ "Pubs" ] } )
        or die "Couldn't write node";

      # Try a very simple crawl.
      my @crawl = eval {
          $crawler->generate_crawl( start_location => {
                                        os_x => 530666, os_y => 181565 },
                                    max_km_between => 1,
                                    num_pubs => 1 );
      };
      is( $@, "", "generate_crawl doesn't die" );
      is( scalar @crawl, 1,
          "...and found a 1-pub crawl starting at the Japanese Canteen" );
      print "# $crawl[0]\n";

      # And a more complicated one.
      @crawl = $crawler->generate_crawl( start_location => {
                                        os_x => 530666, os_y => 181565 },
                                    max_km_between => 1,
                                    num_pubs => 2 );
      is( scalar @crawl, 2,
          "...and found a 2-pub crawl starting at the Japanese Canteen" );
      print "# $crawl[0], $crawl[1]\n";

      # And one that should pick up all five pubs we have so far.
      @crawl = $crawler->generate_crawl( start_location => {
                                        os_x => 530666, os_y => 181565 },
                                    max_km_between => 1,
                                    num_pubs => 5 );
      is( scalar @crawl, 5,
          "...and found a 5-pub crawl starting at the Japanese Canteen" );
      is_deeply( [ sort @crawl ], [ "Cittie Of Yorke", "Ivy House",
                   "Knights Templar", "Penderel's Oak", "Princess Louise" ],
                 "...which contains the five expected pubs" );

      # Check that a shorter crawl is returned if we can't find as many
      # as we were asked for.
      @crawl = $crawler->generate_crawl( start_location => {
                                        os_x => 530666, os_y => 181565 },
                                    max_km_between => 1,
                                    num_pubs => 6 );
      is( scalar @crawl, 5,
          "shorter crawl returned if 6-pub crawl not found" );
      is_deeply( [ sort @crawl ], [ "Cittie Of Yorke", "Ivy House",
                   "Knights Templar", "Penderel's Oak", "Princess Louise" ],
                 "...which contains the five expected pubs" );

      # Now put in something that isn't a pub, and make sure it's not included
      # in crawls.
      $wiki->write_node( "Coffee Matters", "coffee shop", undef,
                         { os_x => 530526, os_y => 181571,
                           category => [ "Cafes" ] } )
        or die "Couldn't write node";
      @crawl = $crawler->generate_crawl( start_location => {
                                        os_x => 530666, os_y => 181565 },
                                    max_km_between => 1,
                                    num_pubs => 6 );
      my %places = map { $_ => 1 } @crawl;
      ok( !$places{"Coffee Matters"}, "non-pubs not included in crawls" );

  }
}
