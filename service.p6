use Perl6::TypeGraph;
use Perl6::TypeGraph::Viz;
use Documentable;
use Documentable::Registry;
use Cro::HTTP::Log::File;
use Cro::HTTP::Server;
use Docky::Host;
use Docky::Routes;

my $host = Docky::Host.new;

unless 'html/images'.IO.e {
    mkdir 'html/images';
    my $viz = Perl6::TypeGraph::Viz.new;
    my $tg = Perl6::TypeGraph.new-from-file;
    $viz.write-type-graph-images(path => "html/images", :force, type-graph => $tg);
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
