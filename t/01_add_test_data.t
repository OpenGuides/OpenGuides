use strict;

use CGI::Wiki::TestConfig::Utilities;
use CGI::Wiki;

use Test::More tests => $CGI::Wiki::TestConfig::Utilities::num_stores;

# Add test data to the stores.
my %stores = CGI::Wiki::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
    SKIP: {
      skip "$store_name storage backend not configured for testing", 1
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $wiki = CGI::Wiki->new( store => $store );

      $wiki->write_node( "Test Node 1",
                         "Just a plain test",
			 undef,
			 { username => "Kake",
			   comment  => "new node",
			 }
		       );

      $wiki->write_node( "Calthorpe Arms",
		         "CAMRA-approved pub near King's Cross",
		         undef,
		         { comment   => "Stub page, please update!",
		           username  => "Kake",
			   postcode  => "WC1X 8JR",
			   locale    => [ "Bloomsbury", "St Pancras" ],
                           phone     => "test phone number",
			   website   => "test website",
			   opening_hours_text => "test hours",
			   latitude  => "51.524193",
			   longitude => "-0.114436"
                         }
      );

      pass "$store_name test backend primed with test data";
    }
}
