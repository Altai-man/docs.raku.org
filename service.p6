use Perl6::TypeGraph;
use Perl6::TypeGraph::Viz;
use Documentable;
use Documentable::Registry;
use Cro::HTTP::Log::File;
use Cro::HTTP::Server;
use Docky::Host;
use Docky::Routes;
use Docky::Search;

my $host = Docky::Host.new;

init-search($host);

unless 'static/images'.IO.e {
    mkdir 'static/images/light';
    mkdir 'static/images/dark';
    my $tg = Perl6::TypeGraph.new-from-file;
    # Write light colors
    my $viz = Perl6::TypeGraph::Viz.new(class-color => '#030303', role-color => '#5503B3', enum-color => '#A30031',
            bg-color => '#fafafa', node-style => 'filled margin=0.2 fillcolor="#f2f2f2" shape=rectangle fontsize=16');
    $viz.write-type-graph-images(path => "static/images/light", :force, type-graph => $tg);
    # Write dark colors
    $viz = Perl6::TypeGraph::Viz.new(class-color => '#f7f7f7', role-color => '#8DB2EB', enum-color => '#EED891',
            bg-color => '#1B1D1E', node-style => 'filled margin=0.2 fillcolor="#212426" shape=rectangle fontsize=16');
    $viz.write-type-graph-images(path => "static/images/dark", :force, type-graph => $tg);
}

my Cro::Service $http = Cro::HTTP::Server.new(
    http => <1.1>,
    host => %*ENV<DOCKY_HOST> ||
        die("Missing DOCKY_HOST in environment"),
    port => %*ENV<DOCKY_PORT> ||
        die("Missing DOCKY_PORT in environment"),
    application => routes($host),
    after => [
        Cro::HTTP::Log::File.new(logs => $*OUT, errors => $*ERR)
    ]
);
$http.start;
say "Listening at http://%*ENV<DOCKY_HOST>:%*ENV<DOCKY_PORT>";
react {
    whenever signal(SIGINT) {
        say "Shutting down...";
        $http.stop;
        done;
    }
}
