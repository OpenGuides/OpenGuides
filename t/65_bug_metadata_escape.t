use CGI::Wiki::Setup::SQLite;
use Config::Tiny;
use Cwd;
use OpenGuides;
use Test::More;

eval { require DBD::SQLite; };
if ( $@ ) {
    plan skip_all => "DBD:SQLite not installed";
} else {
    plan tests => 1;

    CGI::Wiki::Setup::SQLite::cleardb( { dbname => "t/node.db" } );
    CGI::Wiki::Setup::SQLite::setup( { dbname => "t/node.db" } );
    my $config = Config::Tiny->new;
    $config->{_} = {
                     dbtype             => "sqlite",
                     dbname             => "t/node.db",
                     indexing_directory => "t/indexes",
                     script_url         => "http://wiki.example.com/",
                     script_name        => "mywiki.cgi",
                     site_name          => "CGI::Wiki Test Site",
                     template_path      => cwd . "/templates",
                   };

    my $guide = OpenGuides->new( config => $config );

    $guide->wiki->write_node( "South Croydon Station", "A sleepy main-line station in what is arguably the nicest part of Croydon.", undef, { phone => "<hr><h1>hello mum</h1><hr>" } ) or die "Can't write node";

    my $output = $guide->display_node(
                                       id => "South Croydon Station",
                                       return_output => 1,
                                     );
    unlike( $output, qr'<hr><h1>hello mum</h1><hr>',
            "HTML escaped in metadata on node display" );
}

