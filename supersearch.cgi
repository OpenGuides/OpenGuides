#!/usr/local/bin/perl

use warnings;
use strict;

use CGI;
use OpenGuides::Config;
use OpenGuides::SuperSearch;

my $config_file = $ENV{OPENGUIDES_CONFIG_FILE} || "wiki.conf";
my $config = OpenGuides::Config->new( file => $config_file );
my $search = OpenGuides::SuperSearch->new( config => $config );
my %vars = CGI::Vars();
$search->run( vars => \%vars );
