package OpenGuides::Diff;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use OpenGuides::Diff ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	display_node_diff	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';


=head1 NAME

OpenGuides::Diff - OpenGuides module for displaying differences

=head1 SYNOPSIS

  use OpenGuides::Diff;
  
  
=head1 DESCRIPTION

This module provides display of differences for OpenGuides.

=head2 EXPORT

None by default.

=head1 SEE ALSO

L<OpenGuides>

=head1 AUTHOR

Ivor Williams, E<lt>ivorw@earth.liE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Ivor Williams

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
use VCS::Lite;

sub display_node_diff {
    my ($wiki, $node, $v1, $v2) = @_;

    my %ver1 = $wiki->retrieve_node( name => $node,
    				version => $v1);
    my %ver2 = $wiki->retrieve_node( name => $node,
    				version => $v2);

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
	or main::process_template("differences.tt", $node, \%pag );
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

    # line below hacked to use namespace from caller assumed to be wiki.cgi
    main::process_template("differences.tt", $node, \%pag );
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

1;
