use strict;
use Config::Tiny;
use OpenGuides::Utils;
use Test::MockObject;
use Test::More tests => 6;

use_ok( "OpenGuides::Diff" );

# Set up mock wiki object.

# NOTE: Don't use this config object for anything involving writing, or it
# might hose a live database.
my $tmpcf = Config::Tiny->read("wiki.conf");
my $justwanttheformatter = OpenGuides::Utils->make_wiki_object(config=>$tmpcf);
my $formatter = $justwanttheformatter->formatter;

my $wiki = Test::MockObject->new;
$wiki->mock( "retrieve_node",
    sub {
        my ($self, %args) = @_;
        my ($node, $version) = @args{ qw(name version) };
        my %content = (
            "Home Page" => {
                1 => { content => "Version 1 of Home Page",
                       version => 1,
                       metadata => { }
                     }
                           },
            "I Like Pie" => {
                1 => { content  => "Best pie is meat pie.",
                       version  => 1,
                       metadata => { }
                     },
                2 => { content  => "Best pie is apple pie.",
                       version  => 2,
                       metadata => { }
                     },
                3 => { content  => "Best pie is lentil pie.",
                       version  => 3,
                       metadata => { }
                     },
                           }
        );
        return wantarray ? %{ $content{$node}{$version} }
                         : $content{$node}{$version}{content};
    }
);
$wiki->mock( "format", sub { return $formatter->format($_[1]); } );

my %diff_vars = OpenGuides::Diff->formatted_diff_vars(
    wiki     => $wiki,
    node     => "I Like Pie",
    versions => [ 2, 1 ]
);

is( $diff_vars{ver1}, "Version 2", "ver1 set OK" );
is( $diff_vars{ver2}, "Version 1", "ver2 set OK" );
like( $diff_vars{content}, qr/^<p>Best pie is apple pie.<\/p>\s+$/,
      "formatted content as expected" );
isa_ok( $diff_vars{diff}, "ARRAY", "diff returned as arrayref -" );
my @diffs = @{$diff_vars{diff}};
# Why is the first entry blank?
like( $diffs[1]{right}, qr/<span class="diff2">meat<\/span>/,
      "diffs done by word not by letter" );
