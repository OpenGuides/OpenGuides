package OpenGuides::Diff;

use strict;
use warnings;

use Algorithm::Diff;
use VCS::Lite;
our $VERSION = '0.02';

=head1 NAME

OpenGuides::Diff - An OpenGuides helper to extract differences between two versions of a node.

=head1 DESCRIPTION

Makes a nice extract of differences between two versions of an
OpenGuides node.  Distributed and installed as part of the OpenGuides
project, not intended for independent installation.  This
documentation is probably only useful to OpenGuides developers.

=head1 SYNOPSIS

  use Config::Tiny;
  use OpenGuides::Diff;
  use OpenGuides::Template;
  use OpenGuides::Utils;

  my $config = Config::Tiny->read( "wiki.conf" );
  my $wiki = OpenGuides::Utils->make_wiki_object( config => $config );

  # Show the differences between versions 3 and 5 of the home node.
  my %diff_vars = OpenGuides::Diff->formatted_diff_vars(
      wiki => $wiki,
      node => "Home Page",
      versions => [5, 3]
  );
  print OpenGuides::Template->output( wiki     => $wiki,
                                      config   => $config,
                                      node     => "Home Page",
                                      template => "differences.tt",
                                      vars     => \%diff_vars );
  
=cut

=head1 METHODS

=over 4

=item B<formatted_diff_vars>

  my %diff_vars = OpenGuides::Diff->formatted_diff_vars(
      wiki     => $wiki,
      node     => "Home Page",
      versions => [5, 3]
  );

Returns a hash with the key-value pairs:

=over 4

=item *

B<ver1> - The node version whose content we're considering canonical.

B<ver2> - The node version that we're showing the differences from.

B<content> - The (formatted) contents of version C<ver1> of the node.

B<diff> - An array of hashrefs of C<hunks> of differences between the
versions - access from your template as C<diff.hunk.left> and
C<diff.hunk.right>.

=back

That explanation sucks.  Better wording solicited.

=cut

sub formatted_diff_vars {
    my ($class, %args) = @_;
    my ($wiki, $node)  = @args{ qw( wiki node ) };
    my ($v1, $v2)      = @{ $args{versions} };

    my %ver1 = $wiki->retrieve_node( name => $node, version => $v1);
    my %ver2 = $wiki->retrieve_node( name => $node, version => $v2);

    my $verstring1 = "Version ".$ver1{version};
    my $verstring2 = "Version ".$ver2{version};
    
    my $el1 = VCS::Lite->new($verstring1,undef,
    	content_escape($ver1{content}).
	serialise_metadata($ver1{metadata}));
    my $el2 = VCS::Lite->new($verstring2,undef,
    	content_escape($ver2{content}).
	serialise_metadata($ver2{metadata}));
    my %pag = %ver1;
    $pag{ver1} = $verstring1;
    $pag{ver2} = $verstring2;
    $pag{content} = $wiki->format($ver1{content});
    my $dlt = $el1->delta($el2)
	or return %pag;
    my ($c1,$c2,@dlt) = @$dlt;	# Unpicking a VCS::Lite::Delta object
    				# but then I know what I am doing as I
				# wrote that module :) --IvorW

    my @out;
    
    for (@dlt) {
    	my ($lin1,$lin2,$out1,$out2);
	for (@$_) {
	    my ($ind,$line,$text) = @$_;
	    if ($ind ne '+') {
		$lin1 ||= $line;
		$out1 .= $text;
	    }
	    if ($ind ne '-') {
		$lin2 ||= $line;
		$out2 .= $text;
	    }
	}
    	push @out,{ left => $lin1 ? "== Line $lin1 ==\n" : "", 
		right => $lin2 ? "== Line $lin2 ==\n" : ""};
	my ($text1,$text2) = intradiff($out1,$out2);
	push @out,{left => $text1,
		right => $text2};
    }

    $pag{diff} = \@out;

    return %pag;
}

sub serialise_metadata {
    my $hr = shift;
    my %metadata = %$hr;

    delete $metadata{comment};
    delete $metadata{username};
    
    join "<br />\n", map {"$_='".join (',',@{$metadata{$_}})."'"} sort keys %metadata;
}

sub content_escape {
    my $str = shift;

    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s!\n!<br />\n!gs;

    $str;
}

sub intradiff {
    my ($str1,$str2) = @_;

    return (qq{<span class="diff1">$str1</span>},"") unless $str2;
    return ("",qq{<span class="diff2">$str2</span>}) unless $str1;
    my @diffs = Algorithm::Diff::sdiff([$str1 =~ m!&.+?;|<br />|.!sg]
    	,[$str2 =~ m!&.+?;|<br />|.!sg]);
    my $out1 = '';
    my $out2 = '';
    my ($mode1,$mode2);

    for (@diffs) {
    	my ($ind,$c1,$c2) = @$_;

	my $newmode1 = $ind =~ /[c\-]/;
	my $newmode2 = $ind =~ /[c+]/;
	$out1 .= '<span class="diff1">' if $newmode1 && !$mode1;
	$out2 .= '<span class="diff2">' if $newmode2 && !$mode2;
	$out1 .= '</span>' if !$newmode1 && $mode1;
	$out2 .= '</span>' if !$newmode2 && $mode2;
	($mode1,$mode2) = ($newmode1,$newmode2);
	$out1 .= $c1;
	$out2 .= $c2;
    }
    $out1 .= '</span>' if $mode1;
    $out2 .= '</span>' if $mode2;

    ($out1,$out2);
}

=head1 SEE ALSO

L<OpenGuides>

=head1 AUTHOR

The OpenGuides Project (grubstreet@hummous.earth.li)

=head1 COPYRIGHT

     Copyright (C) 2003 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CREDITS

Code in this module mostly written by Ivor Williams,
E<lt>ivor.williams@tiscali.co.ukE<gt>

=cut

1;
