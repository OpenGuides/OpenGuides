#!/usr/local/bin/perl -w

use strict;

use CGI;
use Config::Tiny;
use OpenGuides::SuperSearch;

my $config = Config::Tiny->read( "wiki.conf" );
my $search = OpenGuides::SuperSearch->new( config => $config );
my %vars = CGI::Vars();
$search->run( vars => \%vars );
