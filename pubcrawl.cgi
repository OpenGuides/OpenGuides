#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Cookie;
use CGI::Wiki;
use CGI::Wiki::Formatter::UseMod;
use CGI::Wiki::Plugin::Locator::UK;
use Config::Tiny;
use OpenGuides::UK::PubCrawl;
use Template;
use URI::Escape;

my $cgi = CGI->new();
my $action = $cgi->param('action') || '';

if ( $action eq "generate" ) {
    generate_crawl();
} else {
    show_form();
}

exit 0;

sub generate_crawl {
    # Setup
    my $config = Config::Tiny->read('wiki.conf');

    # Require in the right database module.
    my $dbtype = $config->{_}->{dbtype};

    my %cgi_wiki_exts = ( postgres => "Pg",
	  	          mysql    => "MySQL" );

    my $cgi_wiki_module = "CGI::Wiki::Store::" . $cgi_wiki_exts{$dbtype};
    eval "require $cgi_wiki_module";
    die "Can't 'require' $cgi_wiki_module.\n" if $@;

    # Make store.
    my $store = $cgi_wiki_module->new(
        dbname => $config->{_}{dbname},
        dbuser => $config->{_}{dbuser},
        dbpass => $config->{_}{dbpass},
    );

    # Make formatter
    my $formatter = CGI::Wiki::Formatter::UseMod->new(
        node_prefix         => $config->{_}->{script_name} . "?",
    );

    my $wiki = CGI::Wiki->new( store => $store, formatter => $formatter );
    my $locator = CGI::Wiki::Plugin::Locator::UK->new;
    $wiki->register_plugin( plugin => $locator );
    my $crawler = OpenGuides::UK::PubCrawl->new( locator => $locator );
    $wiki->register_plugin( plugin => $crawler );

    # Now do the stuff.
    my $sx = $cgi->param('sx');
    my $sy = $cgi->param('sy');
    my $max_km = $cgi->param('max_km');
    my $num_pubs = $cgi->param('n');
    my @crawl = $crawler->generate_crawl( start_location =>
					   { os_x => $sx,
					     os_y => $sy  },
                                          max_km_between => $max_km,
                                          num_pubs => $num_pubs,
		       		         );
    my @pubs = map { { name => $_,
                       url  => uri_escape( $config->{_}->{script_name} ) . "?" . uri_escape( $formatter->node_name_to_node_param( $_ ) )
                     }
                   } @crawl;
    print $cgi->header;
    process_crawl_template( crawl     => \@pubs,
                            sx        => $sx,
                            sy        => $sy,
                            max_km    => $max_km,
                            n         => $num_pubs,
                            show_form => 1 );
}


sub show_form {
    print $cgi->header;
    process_crawl_template( show_form => 1 );
}


sub process_crawl_template {
    # Some TT params are passed in to the sub.
    my %tt_vars = @_;

    # Others are global and we get them from the config file.
    my $config = Config::Tiny->read("wiki.conf");
    foreach my $param ( qw( site_name stylesheet_url script_name home_name
			    ) ) {
        $tt_vars{$param} = $config->{_}->{$param};
    }

    # This isn't a page you can edit.
    $tt_vars{not_editable} = 1;

    my %tt_conf = ( INCLUDE_PATH => $config->{_}->{template_path},
    );

    my $tt = Template->new( \%tt_conf );
    $tt->process( "pubcrawl.tt", \%tt_vars ) or warn $tt->error;
}
 
