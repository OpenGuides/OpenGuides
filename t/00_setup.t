use strict;
use Test::More tests => 1;
use CGI::Wiki;
use CGI::Wiki::TestConfig::Utilities;

# Reinitialise every configured storage backend.
CGI::Wiki::TestConfig::Utilities->reinitialise_stores;

pass( "Reinitialised stores" );
