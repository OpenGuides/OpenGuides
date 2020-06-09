use Plack::App::CGIBin;
use Plack::Builder;
 
my $app = Plack::App::CGIBin->new(root => ".",exec_cb => sub { 1 },)->to_app;
builder {
  #    mount "/" => $app;
enable "Plack::Middleware::Static",
        path => qr{^/static/}, root => '.';
        $app;
};
