package OpenGuides;
use strict;

use vars qw( $VERSION );

$VERSION = '0.08';

=head1 NAME

OpenGuides - A complete web application for managing a collaboratively-written guide to a city or town.

=head1 DESCRIPTION

The OpenGuides software provides the framework for a collaboratively-written
city guide.  It is similar to a wiki but provides somewhat more structured
data storage allowing you to annotate wiki pages with information such as
category, location, and much more.  It provides searching facilities
including "find me everything within a certain distance of this place".
Every page includes a link to a machine-readable (RDF) version of the page.

=head1 BUGS AND CAVEATS

At the moment, the location data uses a United-Kingdom-specific module,
so the location features might not work so well outside the UK.

=head1 SEE ALSO

=over 4

=item * The OpenGuides development site, temporarily at L<http://un.earth.li/~kake/cgi-bin/wiki.cgi>

=item * L<http://the.earth.li/~kake/cgi-bin/openguides/vegan-oxford.cgi>, an experimental OpenGuides install mirroring the Vegan Guide to Oxford at L<http://www.earth.li/~kake/vegan-oxford/>

=item * grubstreet, the motivation behind OpenGuides; at L<http://grault.net/grubstreet/>

=back

=head1 FEEDBACK

If you have a question, a bug report, or a patch, or you're interested
in joining the development team, please contact grubstreet@hummous.earth.li
(moderated mailing list, will reach all current developers but you'll have
to wait for your post to be approved) or kake@earth.li (a real person who
may take a little while to reply to your mail if she's busy).

=head1 AUTHOR

The OpenGuides Project (grubstreet@hummous.earth.li)

=head1 COPYRIGHT

     Copyright (C) 2003 The OpenGuides Project.  All Rights Reserved.

The OpenGuides distribution is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 CREDITS

Programming by Earle Martin, Kake Pugh, Ivor Williams.  Testing and
bug reporting by Cal Henderson and Bob Walker.  Much of the
Module::Build stuff copied from the Siesta project
L<http://siesta.unixbeard.net/>

=cut

1;
