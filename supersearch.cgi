#!/usr/local/stow/perl-5.8.0/bin/perl 

use strict;
use warnings;

our $VERSION = '1.05';

use CGI qw(:standard *ol *div);
use CGI::Carp qw(fatalsToBrowser);	#Remove fatalsToBrowser if paranoid

use Parse::RecDescent;
use Data::Dumper;
use File::Spec::Functions qw(:ALL);
use Config::Tiny;
use OpenGuides::Utils;

my $config = Config::Tiny->read('wiki.conf');

my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

use vars qw($wiki_dbpath $wikimain $css $head %wikitext);

$wikimain = $config->{_}->{script_url} . $config->{_}->{script_name};
$css = $config->{_}->{stylesheet_url};
$head = $config->{_}->{site_name} . " Search";

# sub matched_items is called with parse tree. Uses horrible subname concatenation - this
# could be rewritten to us OO instead and be much neater. This would be a major refactor:
# need to address design issues - patterns?

sub matched_items {
	my $op = shift;
	
	no strict 'subs';
	goto &{matched_.$op};
}

# sub mungepage is used to filter out undesirable markup from the raw wiki text

sub mungepage {
	my $text = shift;

# Remove HTML tags (sort of)

	$text =~ s/<.*?>//g;

# Change WikiLinks into plain text

	# titled WikiLink
	$text =~ s/\[\[(.*?)\|(.*?)\]\]/$2/g;

	# normal WikiLink
	$text =~ s/\[\[(.*?)\]\]/$1/g;

	# titled web link
	$text =~ s/\[(.*?) (.*?)\]/$2/g;
	

# Remove WikiFormatting

	$text =~ s/=//g;	# heading
	$text =~ s/'''//g;	# bold
	$text =~ s/''//g;	# italic
	$text =~ s/\*//g;	# bullet point
	$text =~ s/----//g;	# horizontal rule

# Change "#REDIRECT" to something prettier

	$text =~ s/\#REDIRECT/\(redirect\)/g;

	$text;
}

sub prime_wikitext {
	my $search = shift;

	my %res = $wiki->search_nodes($search,' ','or');

	for (keys %res) {
		$wikitext{$wiki->formatter->node_name_to_node_param($_)} 
			||= mungepage($_ . ' ' . $wiki->retrieve_node($_));
	}
}
	
# Build HTML search form with appropriate headers.
# Don't output it just yet

my $outstr = header . start_html(-style => {src => $css}, -title => $head) .
              div({ -id => 'header'}, h1($head)) . start_div({-id => 'content'}) .

		p(small("Version $VERSION. See the <a
href=\"http://grault.net/cgi-bin/grubstreet.pl?Search_Script\">information
page</a> for help and more details.")). "\n".
		start_form( -method => "GET" ) . 
		textfield(
			-name=>'search',
			-size=>50,
			-maxlength=>80) . " " .
			submit('go','Go') .
		end_form . "\n";

# Do we have an existing search? if so, do it.

my $q = CGI->new;
my $srh = $q->param('search');

RESULTS:
{
	if ($srh) {
		
# Check for only valid characters in tainted search param
# (quoted literals are OK, as they are escaped)

		if ($srh !~ /^("[^"]*"|[\w \-'&|()!*%\[\]])+$/i) { #"
			print $outstr,h1("Search expression contains invalid character");
			last RESULTS;
		}

# Build RecDescent grammar for search syntax.
# Note: '&' and '|' can be replaced with other non-alpha. This may be needed if
# you need to call the script from METHOD=GET (as & is a separator)
# Also, word: pattern could be changed to include numbers and handle locales properly.
# However, quoted literals are usually good enough for most odd characters.
	
		my $parse = Parse::RecDescent->new(q{

			search: list eostring {$return = $item[1]}

			list: <leftop: comby '|' comby> 
				{$return = (@{$item[1]}>1) ? ['OR', @{$item[1]}] : $item[1][0]}

			comby: <leftop: term '&' term> 
				{$return = (@{$item[1]}>1) ? ['AND', @{$item[1]}] : $item[1][0]}

			term: '(' list ')' {$return = $item[2]}
			|		'!' term {$return = ['NOT', @{$item[2]}]}
			|		'"' /[^"]*/ '"' {$return = ['literal', $item[2]]}
			|		word(s) {$return = ['word', @{$item[1]}]}
			|		'[' word(s) ']' {$return = ['title', @{$item[2]}]}

			word: /[\w'*%]+/ {$return = $item[1]}
			
			eostring: /^\Z/

		}) or die $@;  

# Turn search string into parse tree
	
		my $tree = $parse->search($srh) or (print $outstr,h1("Search syntax error")),last RESULTS;
#		print $outstr,pre(Dumper($tree));

		my $startpos = $q->param('next') || 0;

# Apply search
# Do different things depending on how many results:

		my %results = matched_items(@$tree);
		my $numres = scalar(keys %results);

# 0 results - 'No items matched'

		(print $outstr,hr,h2('No items matched')),last RESULTS if !$numres;

# 1 result - redirect to the page

		if ($numres == 1) {
			my ($pag) = each %results;
			print redirect($wikimain.'?'.$pag);
			exit;
		}

# Otherwise browse selection of results, 20 at a time

		print $outstr,hr,h2('Search Results'),start_ol({start=>$startpos+1}),"\n";

# Sort the results - first index of array in HoA is the score.

		my @res_selected = sort {$results{$b}[0] <=> $results{$a}[0]} keys %results;
		my $tot_results = @res_selected;

# Skip those before $startpos

		splice @res_selected,0,$startpos;

# Display 20

		for (@res_selected[0..19]) {
			(print end_ol,"\n"),last RESULTS if !$_;
			
			print p(li(a({href=>$wikimain."?$_"},b($_)),br,@{$results{$_}}[1..6]));
		}

# More to do: display 'out of' how many, and 'more' button

		print end_ol,p($startpos+20,'/',$tot_results,"matches"),"\n";

		if ($tot_results > $startpos + 20) {
			my $nq = CGI->new('');
			print start_form,
				$nq->hidden( -name=>'search',
					-value=>$srh),
				$nq->hidden( -name=>'next',
					-value=>($startpos + 20)),
				submit( 'More'),
				end_form;
		}
	} else {
		print $outstr;
	}
}

print end_div, end_html,"\n";

######### End of main program.

# Utility routines to actually do the search

sub do_search {
	my $wmatch = shift;

# Build regexp from parameter. Gobble upto 60 characters of context either side.

	my $wexp = qr/\b.{0,60}\b$wmatch\b.{0,60}\b/is;
	my %res;

# Search every wiki page for matches
	
	while (my ($k,$v) = each %wikitext) {
		my @out;
		for ($v =~ /$wexp/g) {
			my $match .= "...$_...";
			$match =~ s/<[^>]+>//gs;
			$match =~ s!\b($wmatch)\b!<b>$&</b>!i;
			push @out,$match;
		}
		my $temp = $k;
		$temp =~ s/_/ /g;

# Compute score and prepend to array of matches

		my $score = @out;
		$score +=10 if $temp =~ /$wexp/;
		$res{$k} = unshift(@out,$score) && \@out if @out;
	}
	
	%res;
}

sub intersperse {
	my $pagnam = shift;
	
	my @mixed;   
	my $score = 0;
	
	for my $j (@_) {
		if (exists $j->{$pagnam}) {
			$score += $j->{$pagnam}[0];
			push @mixed,[$_,$j->{$pagnam}[$_]] for 1..$#{$j->{$pagnam}};
		}
	}
	
	my @interspersed = map $_->[1], sort {$a->[0] <=> $b->[0]} @mixed;
	
	unshift @interspersed,$score;
	
	\@interspersed;
}

# matched_word - we have a list of adjacent words. Words are allowed to contain
# wildcards * and %

sub matched_word {

	my $wmatch = join '\W+',@_;
	$wmatch =~ s/%/\\w/g;
	$wmatch =~ s/\*/\\w*/g;

# Read in pages from the database that are candidates for the search.
	prime_wikitext(join ' ',@_);

	do_search($wmatch);
}

# matched_literal - we have a literal.

sub matched_literal {
	my $lit = shift;
	
	do_search(quotemeta $lit);
}

# matched_title - title only search, we have a list of words

sub matched_title {
	my $wmatch = join '\W+',@_;
	$wmatch =~ s/%/\\w/g;
	$wmatch =~ s/\*/\\w*/g;

	my $wexp = qr/\b$wmatch\b/is;
	my %res;
	
	for (keys %wikitext) {
		$res{$_} = [10] if /$wexp/g;
	}
	
	%res;
}


# matched_AND - we have a combination of subsearches.

sub matched_AND {

# Do all the searches

	my @comby_res = map {my %match_hash = matched_items(@$_);\%match_hash} @_;

# Use the first one's results as a basis for the output hash
	
	my @out= keys %{$comby_res[0]};
	my %out;

# Zap out any entries which do not appear in one of the other searches.
	
	PAGE:
	for my $page (@out) {
		for (@comby_res[1..$#comby_res]) {
			(delete $out{$page}),next PAGE if !exists $_->{$page};
		}
		
		$out{$page} = intersperse($page,@comby_res);
	}
	
	%out;
}

# matched_OR - we have a list of subsearches

sub matched_OR {

# Do all the searches

	my @list_res = map {my %match_hash = matched_items(@$_);\%match_hash} @_;
	
	my %union;

# Apply union of hashes, merging any duplicates.
	
	for (@list_res) {
		while (my ($k,$v) = each %$_) {
			$union{$k}++;
		}
	}
	
	my %out;
	
	$out{$_} = intersperse($_,@list_res) for keys %union;
	
	%out;
}

# matched_NOT - Form complement of hash against %wikitext

sub matched_NOT {

	my %excludes = matched_items(@_);
	my %out = map {$_=>[0]} keys %wikitext;

	delete $out{$_} for keys %excludes;
	%out;
}

=head1 NAME

supersearch.cgi - Search script for OpenGuides.

=head1 SYNOPSIS

Invoked as a CGI script.

Examples of search strings:

king's head
king's head&fullers
coach and horses|crown and anchor
(vegetarian|vegan)&takeaway
category restaurants&!expensive

=head1 DESCRIPTION

This script presents a single search form when called. The search
string is parsed with a full RecDescent grammar, and the wiki pages
are searched for matches.

Borrowing from Perl (or C) & represents AND, | represents OR, and !
represents NOT.

=head1 AUTHOR

The OpenGuides Project (grubstreet@hummous.earth.li)

=head1 COPYRIGHT

     Copyright (C) 2003 The OpenGuides Project.  All Rights Reserved.

The OpenGuides distribution is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 CREDITS

Most of the work in this script done by
I. Williams, E<lt>ivor.williams@tiscali.co.ukE<gt>

=head1 SEE ALSO

L<OpenGuides>
