#!/usr/bin/perl -w

use strict;
use warnings;

use lib qw( /home/kake/local/share/perl/5.6.1/
	    /home/kake/local/lib/perl/5.6.1/
          );

use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Cookie;
use CGI::Wiki;
use CGI::Wiki::Store::Pg;
use CGI::Wiki::Search::SII;
use CGI::Wiki::Formatter::UseMod;
use CGI::Wiki::Plugin::Locator::UK;
use CGI::Wiki::Plugin::RSS::ChefMoz;
use CGI::Wiki::Plugin::RSS::ModWiki;
use Config::Tiny;
use Geography::NationalGrid;
use Geography::NationalGrid::GB;
use Template;
use Time::Piece;
use URI::Escape;

# config vars
my $FULL_CGI_URL = "http://the.earth.li/~kake/cgi-bin/cgi-wiki/wiki.cgi?";

# Make store.
my $store   = CGI::Wiki::Store::SQLite->new(
    dbname     => "/home/kake/public_html/cgi-out/cgi-wiki.db"
);

# Make search.
my $indexdb = Search::InvertedIndex::DB::DB_File_SplitHash->new(
    -map_name  => "/home/kake/public_html/cgi-out/cgi-wiki-index.db",
    -lock_mode => "EX"
);

my $search  = CGI::Wiki::Search::SII->new( indexdb => $indexdb );

# Make formatter.
my %macros = (
    '@SEARCHBOX' =>
        qq(<form action="wiki.cgi" method="get">
	   <input type="hidden" name="action" value="search">
	   <input type="text" size="20" name="terms">
	   <input type="submit" name="Search" value="Search"></form>),
    qr/\@INDEX_LINK\s+\[\[Category\s+([^\]]+)\]\]/ =>
        sub { return qq(<a href="wiki.cgi?action=catindex&category=) . uri_escape($_[0]) . qq(">View all pages in Category $_[0]</a>)
            }
);

my $formatter = CGI::Wiki::Formatter::UseMod->new(
    extended_links      => 1,
    implicit_links      => 0,
    allowed_tags        => [qw(a p b strong i em pre small img table td tr th
			       br hr ul li center blockquote kbd div code
			       strike)],
    macros              => \%macros,
    node_prefix         => 'wiki.cgi?',
    edit_prefix         => 'wiki.cgi?action=edit&id='
);

my %conf = ( store     => $store,
             search    => $search,
             formatter => $formatter );

my ($wiki, $locator, $q);
eval {
    $wiki = CGI::Wiki->new(%conf);
    $locator = CGI::Wiki::Plugin::Locator::UK->new( wiki => $wiki );

    # Get CGI object, find out what to do.
    $q = CGI->new;

    # Note $q->param('keywords') gives you the entire param string.
    # We need this because usemod has URLs like foo.com/wiki.pl?This_Page
    my $node = $q->param('id') || $q->param('title') || $q->param('keywords') || "";
    $node = $formatter->node_param_to_node_name( $node );

    my $action = $q->param('action') || 'display';
    my $commit = $q->param('Save') || 0;
    my $preview = $q->param('preview') || 0;
    my $search_terms = $q->param('terms') || $q->param('search') || '';
    my $username = $q->param('username') || '';
    my $format = $q->param('format') || '';

    # Alternative method of calling search, supported by usemod.
    $action = 'search' if $q->param("search");

    if ($commit) {
        commit_node($node);
    } elsif ($preview) {
        preview_node($node);
    } elsif ($action eq 'edit') {
        edit_node($node);
    } elsif ($action eq 'search') {
        do_search($search_terms);
    } elsif ($action eq 'show_backlinks') {
        show_backlinks($node);
    } elsif ($action eq 'index') {
        my @all_nodes = $wiki->list_all_nodes();
	my @nodes = map { { name  => $_,
			    param => $formatter->node_name_to_node_param($_) }
			} sort @all_nodes;
        process_template("site_index.tt", "index", { nodes => \@nodes });
    } elsif ($action eq 'random') {
        my @nodes = $wiki->list_all_nodes();
        $node = $nodes[int(rand(scalar(@nodes) + 1)) + 1];
        redirect_to_node($node);
        exit 0;
    } elsif ($action eq 'catindex') {
        my $cat = $q->param('category');
        my @cats = $wiki->list_nodes_by_metadata( metadata_type => "category",
						  metadata_value => $cat );
	my @nodes = map { { name  => $_,
			    param => $formatter->node_name_to_node_param($_) }
			} sort @cats;
        my ($template, $omit_header);
        if ( $format eq "rdf" ) {
            $template = "rdf_index.tt";
            $omit_header = 1;
#            print "Content-type: application/xml\n\n";
            print "Content-type: text/plain\n\n";
	} else {
	    $template = "site_index.tt";
        }
        process_template($template, "Category Index",
                         { nodes    => \@nodes,
			   category => { name => $q->escapeHTML($cat),
					 url  => "wiki.cgi?Category_"
                        . uri_escape($formatter->node_name_to_node_param($cat))
			                }
			  },
			  {},
			  $omit_header);
    } elsif ($action eq 'find_within_distance') {
        my $metres = $q->param("distance_in_metres");
        my @finds = $locator->find_within_distance( node => $node,
			 		            metres => $metres );
        my @nodes;
        foreach my $find ( @finds ) {
            my $distance = $locator->distance( from_node => $node,
					       to_node   => $find,
                                               unit      => "metres" );
            push @nodes, { name => $find,
			   param => $formatter->node_name_to_node_param($find),
                           distance => $distance };
	}
        @nodes = sort { $a->{distance} <=> $b->{distance} } @nodes;
        process_template("site_index.tt", "index",
                         { nodes  => \@nodes,
			   origin => $node,
			   origin_param => $formatter->node_name_to_node_param($node),
			   limit  => "$metres metres" } );
    } elsif ($action eq 'userstats') {
        show_userstats( $username );
    } elsif ($action eq 'list_all_versions') {
        list_all_versions($node);
    } elsif ($action eq 'rss') {
        my $feed = $q->param("feed");
        if ( !defined $feed or $feed eq "recent_changes" ) {
            emit_recent_changes_rss();
        } elsif ( $feed eq "chef_moz" ) {
            emit_chef_moz_rss( node => $node );
        } elsif ( $feed eq "chef_dan" ) {
            emit_chef_dan_rss( node => $node );
        } else {
            croak "Unknown RSS feed type '$feed'";
        }
    } else {
        my $version = $q->param("version");
        display_node($node, $version);
    }
};

if ($@) {
    my $error = $@;
    warn $error;
    print $q->header;
    print qq(<html><head><title>ERROR</title></head><body>
             <p>Sorry!  Something went wrong.  Please contact the
             Wiki administrator at
             <a href="mailto:kake\@earth.li">kake\@earth.li</a> and quote
             the following error message:</p><blockquote>)
      . $q->escapeHTML($error)
      . qq(</blockquote><p><a href="wiki.cgi">Return to the Wiki home page</a>
           </body></html>);
}
exit 0;

############################ subroutines ###################################

sub redirect_to_node {
    my $node = shift;
    print $q->redirect($FULL_CGI_URL . $q->escape($formatter->node_name_to_node_param($node)));
    exit 0;
}

sub display_node {
    my ($node, $version) = @_;
    $node ||= "Home";

    my %tt_vars;

    # If this is a Category node, check whether it exists and write it
    # a stub node if it doesn't.
    if ( $node =~ /^Category (.*)$/ ) {
        $tt_vars{is_category_node} = 1;
        $tt_vars{category_name}    = $1;

        unless ( $wiki->node_exists($node) ) {
            warn "Creating default node $node";
            $wiki->write_node( $node,
                               "\@INDEX_LINK [[$node]]",
                               undef,
			       { username => "Auto Create",
				 comment  => "Auto created category stub page"
			       }
	    );
	}
    }

    my %current_data = $wiki->retrieve_node( $node );
    my $current_version = $current_data{version};
    undef $version if ($version && $version == $current_version);
    my %criteria = ( name => $node );
    $criteria{version} = $version if $version;#retrieve_node default is current

    my %node_data = $wiki->retrieve_node( %criteria );
    my $raw = $node_data{content};
    if ( $raw =~ /^#REDIRECT\s+(.+?)\s+$/ ) {
        my $redirect = $1;
        # Strip off enclosing [[ ]] in case this is an extended link.
        $redirect =~ s/^\[\[//;
        $redirect =~ s/\]\]$//;
        # See if this is a valid node, if not then just show the page as-is.
	if ( $wiki->node_exists($redirect) ) {
            redirect_to_node($redirect);
	}
    }
    my $content    = $wiki->format($raw);
    my $modified   = $node_data{last_modified};
    my %metadata   = %{$node_data{metadata}};
    my $catref     = $metadata{category};
    my $locref     = $metadata{locale};
    my $os_x       = $metadata{os_x}[0];
    my $os_y       = $metadata{os_y}[0];
    my $phone      = $metadata{phone}[0];
    my $website    = $metadata{website}[0];
    my $hours_text = $metadata{opening_hours_text}[0];
    my $postcode   = $metadata{postcode}[0];

    my ($lat, $long);
    if ( $os_x && $os_y ) {
        my $point = Geography::NationalGrid::GB->new( Easting  => $os_x,
						      Northing => $os_y );
        $lat  = $point->latitude;
	$long = $point->longitude;
    }

    my @categories = map { { name => $_,
                             url  => "wiki.cgi?Category_"
            . uri_escape($formatter->node_name_to_node_param($_)) } } @$catref;

    my @locales    = map { { name => $_,
                             url  => "wiki.cgi?Category_"
            . uri_escape($formatter->node_name_to_node_param($_)) } } @$locref;

    %tt_vars = (    %tt_vars,
		    content       => $content,
                    categories    => \@categories,
		    locales       => \@locales,
		    os_x          => $os_x,
		    os_y          => $os_y,
		    phone         => $phone,
		    website       => $website,
		    hours_text    => $hours_text,
		    postcode      => $postcode,
		    latitude      => $lat,
		    longitude     => $long,
		    last_modified => $modified,
		    version       => $node_data{version},
		    node_name     => $q->escapeHTML($node),
		    node_param    => $q->escape($node) );

    # We've undef'ed $version above if this is the current version.
    $tt_vars{current} = 1 unless $version;

    if ($node eq "RecentChanges") {
        my @recent = $wiki->list_recent_changes( days => 7 );
        @recent = map { {name          => $q->escapeHTML($_->{name}),
                         last_modified => $q->escapeHTML($_->{last_modified}),
                         comment       => $q->escapeHTML($_->{metadata}{comment}[0]),
                         username      => $q->escapeHTML($_->{metadata}{username}[0]),
                         url           => "wiki.cgi?"
          . $q->escape($formatter->node_name_to_node_param($_->{name})) }
                       } @recent;
        $tt_vars{recent_changes} = \@recent;
        $tt_vars{days} = 7;
        process_template("recent_changes.tt", $node, \%tt_vars);
    } elsif ($node eq "Home") {
        my @recent = $wiki->list_recent_changes( last_n_changes => 10);
        @recent = map { {name          => $q->escapeHTML($_->{name}),
                         last_modified => $q->escapeHTML($_->{last_modified}),
                         comment       => $q->escapeHTML($_->{metadata}{comment}[0]),
                         username      => $q->escapeHTML($_->{metadata}{username}[0]),
                         url           => "wiki.cgi?"
          . $q->escape($formatter->node_name_to_node_param($_->{name})) }
                       } @recent;
        $tt_vars{recent_changes} = \@recent;
        process_template("home_node.tt", $node, \%tt_vars);
    } else {
        process_template("node.tt", $node, \%tt_vars);
    }
}

sub list_all_versions {
    my $node = shift;
    my %curr_data = $wiki->retrieve_node($node);
    my $curr_version = $curr_data{version};
    croak "This is the first version" unless $curr_version > 1;
    my @history;
    for my $version ( 1 .. $curr_version ) {
        my %node_data = $wiki->retrieve_node( name    => $node,
					      version => $version );
	push @history, { version  => $version,
			 modified => $node_data{last_modified},
		         username => $node_data{metadata}{username}[0],
		         comment  => $node_data{metadata}{comment}[0]   };
    }
    @history = reverse @history;
    my %tt_vars = ( node    => $node,
		    version => $curr_version,
		    history => \@history );
    process_template("node_history.tt", $node, \%tt_vars );
}

sub show_userstats {
    my $username = shift;
    croak "No username supplied to show_userstats" unless $username;
    my @nodes = $wiki->list_recent_changes(
        last_n_changes => 5,
	metadata_is    => { username => $username }
    );
    @nodes = map { {name          => $q->escapeHTML($_->{name}),
		    last_modified => $q->escapeHTML($_->{last_modified}),
		    comment       => $q->escapeHTML($_->{metadata}{comment}[0]),
		    url           => "wiki.cgi?"
          . $q->escape($formatter->node_name_to_node_param($_->{name})) }
                       } @nodes;
    my %tt_vars = ( last_five_nodes => \@nodes,
		    username        => $username );
    process_template("userstats.tt", "", \%tt_vars);
}

sub preview_node {
    my $node = shift;
    my $content         = $q->param('content');
    $content =~ s/\r\n/\n/gs;
    my $checksum        = $q->param('checksum');
    my $categories_text = $q->param('categories');
    my $os_x            = $q->param('os_x');
    my $os_y            = $q->param('os_y');
    my $phone           = $q->param('phone');
    my $website         = $q->param('website');
    my $hours_text      = $q->param('hours_text');
    my $postcode        = $q->param('postcode');
    my $username        = $q->param('username');
    my $comment         = $q->param('comment');

    my @categories = sort split("\r\n", $categories_text);

    if ($wiki->verify_checksum($node, $checksum)) {
        my %tt_vars = ( content      => $q->escapeHTML($content),
			categories   => \@categories,
			os_x         => $os_x,
			os_y         => $os_y,
  		        phone         => $phone,
		        website       => $website,
		        hours_text    => $hours_text,
                        postcode     => $postcode,
			username     => $username,
			comment      => $comment,
                        preview_html => $wiki->format($content),
                        checksum     => $q->escapeHTML($checksum) );

        process_template("edit_form.tt", $node, \%tt_vars);
    } else {
    croak "edit_conflict needs to be brought up to date to cope with metadata";
        my %node_data = $wiki->retrieve_node($node);
        my ($stored, $checksum) = @node_data{ qw( content checksum ) };
        my %tt_vars = ( checksum    => $q->escapeHTML($checksum),
                        new_content => $q->escapeHTML($content),
                        stored      => $q->escapeHTML($stored) );
        process_template("edit_conflict.tt", $node, \%tt_vars);
    }
}

sub edit_node {
    my $node = shift;
    my %node_data = $wiki->retrieve_node($node);
    my ($content, $checksum) = @node_data{ qw( content checksum ) };
    my %metadata   = %{$node_data{metadata}};
    my $catref     = $metadata{category};
    my $locref     = $metadata{locale};
    my $os_x       = $metadata{os_x}[0];
    my $os_y       = $metadata{os_y}[0];
    my $phone      = $metadata{phone}[0];
    my $website    = $metadata{website}[0];
    my $hours_text = $metadata{opening_hours_text}[0];
    my $postcode   = $metadata{postcode}[0];
    my %tt_vars = ( content    => $q->escapeHTML($content),
                    checksum   => $q->escapeHTML($checksum),
                    categories => $catref,
		    locales    => $locref,
		    os_x       => $os_x,
		    os_y       => $os_y,
		    phone      => $phone,
		    website    => $website,
		    hours_text => $hours_text,
                    postcode   => $postcode
    );

    process_template("edit_form.tt", $node, \%tt_vars);
}


sub emit_recent_changes_rss {
    my $rss = CGI::Wiki::Plugin::RSS::ModWiki->new(
        wiki      => $wiki,
        site_name => "CGI::Wiki Test Site",
        site_description => "A clone of the Open Community Guide To London",
        make_node_url => sub {
            my ( $node_name, $version ) = @_;
            return "http://the.earth.li/~kake/cgi-bin/cgi-wiki/wiki.cgi?id="
                 . uri_escape(
                        $wiki->formatter->node_name_to_node_param( $node_name )
			     )
                 . ";version=" . uri_escape($version);
	  },
        recent_changes_link =>
            "http://the.earth.li/~kake/cgi-bin/cgi-wiki/wiki.cgi?RecentChanges"
     );

    print "Content-type: text/plain\n\n";
    print $rss->recent_changes;
    exit 0;
}

sub emit_chef_moz_rss {
    my %args = @_;
    my $node = $args{node};
    my $rss = CGI::Wiki::Plugin::RSS::ChefMoz->new(
        wiki      => $wiki,
        site_name => "CGI::Wiki Test Site",
        site_description => "A clone of the Open Community Guide To London",
        make_node_url => sub {
            my ( $node_name, $version ) = @_;
            return "http://the.earth.li/~kake/cgi-bin/cgi-wiki/wiki.cgi?id="
                 . uri_escape(
                        $wiki->formatter->node_name_to_node_param( $node_name )
			     )
                 . ";version=" . uri_escape($version);
        },
        full_node_prefix =>
            "http://the.earth.li/~kake/cgi-bin/cgi-wiki/wiki.cgi?",
	default_city => "London",
        default_country => "United Kingdom"
     );

    print "Content-type: text/plain\n\n";
    print $rss->chef_moz( node => $node );
    exit 0;
}

sub emit_chef_dan_rss {
    my %args = @_;
    my $node = $args{node};
    my $rss = CGI::Wiki::Plugin::RSS::ChefMoz->new(
        wiki      => $wiki,
        site_name => "CGI::Wiki Test Site",
        site_description => "A clone of the Open Community Guide To London",
        make_node_url => sub {
            my ( $node_name, $version ) = @_;
            if ( defined $version ) {
               return "http://the.earth.li/~kake/cgi-bin/cgi-wiki/wiki.cgi?id="
                 . uri_escape(
                        $wiki->formatter->node_name_to_node_param( $node_name )
			     )
                 . ";version=" . uri_escape($version);
	     } else {
                return "http://the.earth.li/~kake/cgi-bin/cgi-wiki/wiki.cgi?"
                 . uri_escape(
                        $wiki->formatter->node_name_to_node_param( $node_name )
			     );
             }
        },
	full_node_prefix => "REMOVE - not used",
	default_city => "London",
        default_country => "United Kingdom"
     );

    print "Content-type: text/plain\n\n";
    print $rss->chef_dan( node => $node );
    exit 0;
}


sub process_template {
    my ($template, $node, $vars, $conf, $omit_header) = @_;

    $vars ||= {};
    $conf ||= {};

    my %tt_vars = ( %$vars,
                    site_name     => "CGI::Wiki Test Site",
                    cgi_url       => "wiki.cgi",
                    full_cgi_url  => $FULL_CGI_URL,
                    contact_email => "kake\@earth.li",
                    description   => "",
                    keywords      => "",
                    stylesheet    => "http://grault.net/grubstreet/grubstreet.css",
                    home_link     => "wiki.cgi",
                    home_name     => "Home" );

    if ($node) {
        $tt_vars{node_name} = $q->escapeHTML($node);
        $tt_vars{node_param} = $q->escape($formatter->node_name_to_node_param($node));
    }

    my %tt_conf = ( %$conf,
                INCLUDE_PATH => "/home/kake/public_html/cgi-bin/cgi-wiki/templates" );

    # Create Template object, print CGI header, process template.
    my $tt = Template->new(\%tt_conf);
    print $q->header unless $omit_header;
    unless ($tt->process($template, \%tt_vars)) {
        print qq(<html><head><title>ERROR</title></head><body><p>
                 Failed to process template: )
          . $tt->error
          . qq(</p></body></html>);
    }
}


sub commit_node {
    my $node = shift;
    my $content  = $q->param('content');
    $content =~ s/\r\n/\n/gs;
    my $checksum = $q->param('checksum');
    my $categories_text = $q->param('categories');
    my $locales_text    = $q->param('locales');
    my $os_x            = $q->param('os_x');
    my $os_y            = $q->param('os_y');
    my $phone           = $q->param('phone');
    my $website         = $q->param('website');
    my $hours_text      = $q->param('hours_text');
    my $postcode        = $q->param('postcode');
    my $username        = $q->param('username');
    my $comment         = $q->param('comment');

    my @categories = sort split("\r\n", $categories_text);
    my @locales    = sort split("\r\n", $locales_text);

    my $written = $wiki->write_node($node, $content, $checksum,
                                    { category   => \@categories,
				      locale     => \@locales,
				      os_x       => $os_x,
				      os_y       => $os_y,
				      phone      => $phone,
				      website    => $website,
			      opening_hours_text => $hours_text,
				      postcode   => $postcode,
				      username   => $username,
				      comment    => $comment      } );
    if ($written) {
        redirect_to_node($node);
    } else {
    croak "edit_conflict needs to be brought up to date to cope with metadata";
        my %node_data = $wiki->retrieve_node($node);
	my ($stored, $checksum) = @node_data{ qw( content checksum ) };
        my %tt_vars = ( checksum    => $q->escapeHTML($checksum),
                        new_content => $q->escapeHTML($content),
                        stored      => $q->escapeHTML($stored) );
        process_template("edit_conflict.tt", $node, \%tt_vars);
    }
}


sub do_search {
    my $terms = shift;
    my %finds = $wiki->search_nodes($terms);
#    my @sorted = sort { $finds{$a} cmp $finds{$b} } keys %finds;
    my @sorted = sort keys %finds;
    my @results = map {
        { url   => $q->escape($formatter->node_name_to_node_param($_)),
	  title => $q->escapeHTML($_)
        }             } @sorted;
    my %tt_vars = ( results      => \@results,
                    num_results  => scalar @results,
                    not_editable => 1,
                    search_terms => $q->escapeHTML($terms) );
    process_template("search_results.tt", "", \%tt_vars);
}

sub show_backlinks {
    my $node = shift;
    my @backlinks = $wiki->list_backlinks( node => $node );
    my @results = map {
        { url   => $q->escape($formatter->node_name_to_node_param($_)),
	  title => $q->escapeHTML($_)
        }             } sort @backlinks;
    my %tt_vars = ( results      => \@results,
                    num_results  => scalar @results,
                    not_editable => 1 );
    process_template("backlink_results.tt", $node, \%tt_vars);
}

