#!/usr/local/bin/perl

use warnings;
use strict;

use CGI;
use OpenGuides::Config;
use OpenGuides::SuperSearch;

my $config = OpenGuides::Config->new( file => "wiki.conf" );
my $search = OpenGuides::SuperSearch->new( config => $config );
my %vars = CGI::Vars();
$search->run( vars => \%vars );
