package OpenGuides::SuperSearch;
use strict;
our $VERSION = '0.04';

use CGI qw( :standard );
use File::Spec::Functions qw(:ALL);
use OpenGuides::Template;
use OpenGuides::Utils;
use Parse::RecDescent;

=head1 NAME

OpenGuides::SuperSearch - Search form generation and processing for OpenGuides.

=head1 DESCRIPTION

Does search stuff for OpenGuides.  Distributed and installed as part of
the OpenGuides project, not intended for independent installation.
This documentation is probably only useful to OpenGuides developers.

=head1 SYNOPSIS

  use CGI;
  use Config::Tiny;
  use OpenGuides::SuperSearch;

  my $config = Config::Tiny->read( "wiki.conf" );
  my $search = OpenGuides::SuperSearch->new( config => $config );
  my %vars = CGI::Vars();
  $search->run( vars => \%vars );

=head1 METHODS

=over 4

=item B<new>

  my $config = Config::Tiny->read( "wiki.conf" );
  my $search = OpenGuides::SuperSearch->new( config => $config );

=cut

sub new {
    my ($class, %args) = @_;
    my $config = $args{config};
    my $self = { config => $config };
    bless $self, $class;
    my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );
    $self->{wiki} = $wiki;
    $self->{wikimain} = $config->{_}{script_url} . $config->{_}{script_name};
    $self->{css} = $config->{_}{stylesheet_url};
    $self->{head} = $config->{_}{site_name} . " Search";
    return $self;
}

=item B<run>

  my %vars = CGI::Vars();
  $search->run(
                vars           => \%vars,
                return_output  => 1,   # defaults to 0
                return_tt_vars => 1,  # defaults to 0
              );

The C<return_output> parameter is optional.  If supplied and true, the
stuff that would normally be printed to STDOUT will be returned as a
string instead.

The C<return_tt_vars> parameter is also optional.  If supplied and
true, the template is not processed and the variables that would have
been passed to it are returned as a hash.  This parameter takes
precedence over C<return_output>.

These two parameters exist to make testing easier; you probably don't
want to use them in production.

=back

=cut

sub run {
    my ($self, %args) = @_;
    $self->{return_output}  = $args{return_output}  || 0;
    $self->{return_tt_vars} = $args{return_tt_vars} || 0;
    my %vars = %{ $args{vars} || {} };
    my %tt_vars;

    $tt_vars{ss_version}  = $VERSION;
    $tt_vars{ss_info_url} = 'http://openguides.org/london?Search_Script';

    # Do we have an existing search? if so, do it.
    if ( $vars{search} ) {
        $tt_vars{search_terms} = $vars{search};
        $self->_perform_search( vars => \%vars );
    }

    if ( $self->{error} ) {
        $tt_vars{error_message} = $self->{error};
    } elsif ( $vars{search} ) {
        my %results = %{ $self->{results} || {} };
        my $numres = scalar keys %results;

        # For 0 or many we display results, for 1 we redirect to that page.
        if ( $numres == 1 && !$self->{return_tt_vars}) {
            my ($node) = each %results;
            my $output = CGI::redirect( $self->{wikimain} . "?"
                                        . CGI::escape($node) );
            return $output if $self->{return_output};
            print $output;
            exit;
        } else {
            # We browse through the results a page at a time.

            # Figure out which results we're going to be showing on this
            # page, and what the first one for the next page will be.
            my $startpos = $vars{next} || 0;
            $tt_vars{first_num} = $numres ? $startpos + 1 : 0;
            $tt_vars{last_num}  = $numres > $startpos + 20
                                    ? $startpos + 20
                                    : $numres;
            $tt_vars{total_num} = $numres;
            if ( $numres > $startpos + 20 ) {
                $tt_vars{next_page_startpos} = $startpos + 20;
            }

            # Sort the results - first index of array in HoA is the score.
            my @res_selected = sort
                               { $results{$b}[0] <=> $results{$a}[0] }
                               keys %results;

            # Now snip out just the ones for this page.  The -1 is
            # because arrays index from 0 and people from 1.
            my $from = $tt_vars{first_num} ? $tt_vars{first_num} - 1 : 0;
            my $to   = $tt_vars{last_num} - 1; # kludge to empty arr for no res
            @res_selected = @res_selected[ $from .. $to ];

            my @result_urls;
            foreach ( @res_selected ) {
                my @summary = grep { defined $_ } @{$results{$_}}[1 .. 6];
                push @result_urls,
		  {
                    name    => $_,
                    url     => $self->{wikimain} . "?" . CGI::escape($_),
                    summary => join "\n", @summary,
                  };
            }
            $tt_vars{results} = \@result_urls;
        }
    }

    $self->process_template( tt_vars => \%tt_vars );
}

# thin wrapper around OpenGuides::Template
sub process_template {
    my ($self, %args) = @_;
    my $tt_vars = $args{tt_vars} || {};
    $tt_vars->{not_editable} = 1;

    return %$tt_vars if $self->{return_tt_vars};

    my $output =  OpenGuides::Template->output(
                                                wiki     => $self->{wiki},
                                                config   => $self->{config},
                                                template => "supersearch.tt",
                                                vars     => $tt_vars,
                                              );
    return $output if $self->{return_output};

    print $output;
    return 1;
}

# method to populate $self with text of nodes potentially matching a query
# This could contain many more nodes than actually match the query
sub _prime_wikitext {
    my ($self, $op, @leaves) = @_;
    my $wiki = $self->{wiki};

    if ($op =~ /AND|OR/) {
	# Recurse into parse tree for boolean op nodes
	$self->_prime_wikitext(@$_) for @leaves;
    } elsif ($op eq 'NOT') {
	$self->_prime_wikitext(@leaves);
    } elsif ($op eq 'word') {
	foreach (@leaves) {
	    # Search title and body.
	    my %results = $wiki->search_nodes( $_ );
	    foreach my $node ( keys %results ) {
		next unless $node; # Search::InvertedIndex goes screwy sometimes
		my $key = $wiki->formatter->node_name_to_node_param( $node );
		my $text = $node . " " . $wiki->retrieve_node( $node );
		$self->{wikitext}{$key} ||= $self->_mungepage( $text );
	    }
	}

	my $meta_title = join '_',@leaves;
	my $matchstr = join ' ',@leaves;

	# Search categories.
	my @catmatches = $wiki->list_nodes_by_metadata(
				 metadata_type  => "category",
				 metadata_value => $meta_title,
				 ignore_case    => 1,
	);

	foreach my $node ( @catmatches ) {
		my $key = $wiki->formatter->node_name_to_node_param( $node );
		my $text = $node. " " . $wiki->retrieve_node( $node );
		$self->{wikitext}{$key} ||= $self->_mungepage( $text );
		# Append this category so the regex finds it later.
		$self->{wikitext}{$key} .= " [$matchstr]";
	}

	# Search locales.
	my @locmatches = $wiki->list_nodes_by_metadata(
				 metadata_type  => "locale",
				 metadata_value => $meta_title,
				 ignore_case    => 1,
	);
	foreach my $node ( @locmatches ) {
		my $key = $wiki->formatter->node_name_to_node_param( $node );
		my $text = $node. " " . $wiki->retrieve_node( $node );
		$self->{wikitext}{$key} ||= $self->_mungepage( $text );
		# Append this locale so the regex finds it later.
		$self->{wikitext}{$key} .= " [$matchstr]";
	}
    } # $op eq 'word'
} # sub _prime_wikitext
    
# method to filter out undesirable markup from the raw wiki text
sub _mungepage {
    my ($self, $text) = @_;

    # Remove HTML tags (sort of)
    $text =~ s/<.*?>//g;

    # Change WikiLinks into plain text
    $text =~ s/\[\[(.*?)\|(.*?)\]\]/$2/g;  # titled WikiLink
    $text =~ s/\[\[(.*?)\]\]/$1/g;         # normal WikiLink
    $text =~ s/\[(.*?) (.*?)\]/$2/g;       # titled web link
    
    # Remove WikiFormatting
    $text =~ s/=//g;      # heading
    $text =~ s/'''//g;    # bold
    $text =~ s/''//g;     # italic
    $text =~ s/\*//g;     # bullet point
    $text =~ s/----//g;   # horizontal rule

    # Change "#REDIRECT" to something prettier
    $text =~ s/\#REDIRECT/\(redirect\)/g;

    return $text;
}

# Populates either $self->{error} or $self->{results}
sub _perform_search {
    my ($self, %args) = @_;
    my %vars = %{ $args{vars} || {} };
    my $srh = $vars{search};

    # Check for only valid characters in tainted search param
    # (quoted literals are OK, as they are escaped)
    if ( $srh !~ /^("[^"]*"|[\w \-',()!*%\[\]])+$/i) { #"
        $self->{error} = "Search expression contains invalid character(s)";
        return;
    }

    $self->_build_parser && exists($self->{error}) && return;
    $self->_apply_parser($srh);
}

sub _build_parser {
    my $self = shift;

    # Build RecDescent grammar for search syntax.

    my $parse = Parse::RecDescent->new(q{

        search: list eostring {$return = $item[1]}

	list: comby(s)
            {$return = (@{$item[1]}>1) ? ['AND', @{$item[1]}] : $item[1][0]}

        comby: <leftop: term ',' term> 
            {$return = (@{$item[1]}>1) ? ['OR', @{$item[1]}] : $item[1][0]}

        term: '(' list ')' {$return = $item[2]}
            |        '-' term {$return = ['NOT', @{$item[2]}]}
#           |        word ':' term {$return = ['meta', $item[1], $item[3]];}
            |        '"' word(s) '"' {$return = ['word', @{$item[2]}]}
            |        word {$return = ['word', $item[1]]}
            |        '[' word(s) ']' {$return = ['title', @{$item[2]}]}
#	    |        m([/|\\]) m([^$item[1]]+) $item[1]
#	    		{ $return = ['regexp', qr($item[2])] }

        word: /[\w'*%]+/ {$return = $item[1]}
            
        eostring: /^\Z/
	
    });

    unless ( $parse ) {
        warn $@;
        $self->{error} = "can't create parse object";
        return;
    }
    
    $self->{parser} = $parse;
    return $self;
}

sub _apply_parser {
    my ($self,$search) = @_;
	
    # Turn search string into parse tree
    my $tree = $self->{parser}->search($search);
    unless ( $tree ) {
        $self->{error} = "Search syntax error";
        return;
    }

    #Prime the search
    $self->_prime_wikitext(@$tree);

    # Apply search and return results
    my %results = $self->_matched_items( tree => $tree );
    $self->{results} = \%results;
    return $self;
}

# called with parse tree
sub _matched_items {
    my ($self, %args) = @_;
    my $tree = $args{tree};
    my @tree_arr = @$tree;
    my $op = shift @tree_arr;
    my $meth = 'matched_'.$op;

    return $self->can($meth) ? $self->$meth(@tree_arr) : undef;
}



=head1 INPUT

=over

=item B<word>

a single word will be matched as-is. For example, a search on

  escalator

will return all pages containing the word "escalator".

=cut

sub matched_word {
    my $self = shift;
    my $wmatch = join '\W+',@_;
    $wmatch =~ s/%/\\w/g;
    $wmatch =~ s/\*/\\w*/g;

    return $self->_do_search($wmatch);
}

=item B<AND searches>

A list of words with no punctuation will be ANDed, for example:

  restaurant vegetarian

will return all pages containing both the word "restaurant" and the word
"vegetarian".

=cut

sub matched_AND {
    my $self = shift;

    # Do all the searches
    my @comby_res = map {
                          my %match_hash = $self->_matched_items(tree => $_);
                          \%match_hash
                        } @_;

    # Use the first one's results as a basis for the output hash
    my @out = keys %{$comby_res[0]};
    my %out;

    # Zap out any entries which do not appear in one of the other searches.
    PAGE:
    for my $page (@out) {
        for (@comby_res[1..$#comby_res]) {
            (delete $out{$page}),next PAGE if !exists $_->{$page};
        }
        
        $out{$page} = $self->intersperse($page, @comby_res);
    }
    
    return %out;
}

=item B<OR searches>

A list of words separated by commas (and optional spaces) will be ORed, 
for example:

  restaurant, cafe

will return all pages containing either the word "restaurant" or the
word "cafe".

=cut

sub matched_OR {
    my $self = shift;

    # Do all the searches
    my @list_res = map {
                         my %match_hash = $self->_matched_items(tree => $_);
                         \%match_hash
                       } @_;

    # Apply union of hashes, merging any duplicates.
    my %union;
    for (@list_res) {
        while (my ($k,$v) = each %$_) {
            $union{$k}++;
        }
    }
    
    my %out;
    
    $out{$_} = $self->intersperse($_, @list_res) for keys %union;
    
    return %out;
}


=item B<NOT searches>

Words and phrases preceded by a minus sign are excluded, for example:

  restaurant -expensive

will return all pages that contain the word "restaurant" and do not 
contain "expensive".

Note that a NOT search is used to qualify an existing search, so you
cannot use -foo standalone to give you all pages without foo.

=cut

# matched_NOT - Form complement of hash against %wikitext
sub matched_NOT {
    my $self = shift;
    my %excludes = $self->_matched_items(tree => \@_);
    my %out = map {$_=>[0]} keys %{ $self->{wikitext} };

    delete $out{$_} for keys %excludes;
    return %out;
}

=item B<phrase searches>

Enclose phrases in double quotes, for example:

  "meat pie"

will return all pages that contain the exact phrase "meat pie" - not pages
that only contain, for example, "apple pie and meat sausage".

=cut

# matched_literal - we have a literal.
sub matched_literal {
    my $self = shift;
    my $lit = shift;
    $self->_do_search(quotemeta $lit);
}

sub intersperse {
    my $self = shift;
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
    
    return \@interspersed;
}

sub _do_search {
    my ($self, $wmatch) = @_;

    # Build regexp from parameter. Gobble upto 60 characters of
    # context either side.
    my $wexp = qr/\b.{0,60}\b$wmatch\b.{0,60}\b/is;
    my %res;

    # Search every wiki page for matches
    my %wikitext = %{ $self->{wikitext} || {} };
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
    
    return %res;
}

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

     Copyright (C) 2003 The OpenGuides Project.  All Rights Reserved.

The OpenGuides distribution is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<OpenGuides>

=cut

1;

__END__

# Not sure what this sub is meant to do.  It doesn't seem to match on [foo]
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
