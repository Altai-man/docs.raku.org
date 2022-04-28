# A small version of the examples execution server, representing just a single
# endpoint accepting JSON, executing some code in a container nd returning it back

use Cro::HTTP::Router;
use Cro::HTTP::Server;
use JSON::Fast;

constant DOCKER_COMMAND = <docker run --rm -i --read-only --tmpfs /tmp:rw,noexec,nosuid,size=65536k --tmpfs /home/glot:rw,exec,nosuid,uid=1000,gid=1000,size=131072k -u glot -w /home/glot glot/raku:latest>;
constant SECRET_TOKEN = %*ENV<DOCKY_EXAMPLES_EXECUTOR_KEY> // die "The DOCKY_EXAMPLES_EXECUTOR_KEY env variable must be declared";

my $application = route {
    post -> 'run', :$X-Access-Token is header {

        if $X-Access-Token eq SECRET_TOKEN {
            request-body -> %payload {
                my $proc = Proc::Async.new(:w, |DOCKER_COMMAND);

                my ($output, $success) = "", False;

                react {
                    whenever $proc.stdout.lines {
                        $output ~= $_;
                    }
                    whenever $proc.stderr {
                        # No wait if there is an error
                        done;
                    }
                    whenever $proc.start {
                        $success = $_.exitcode == 0;
                        done;
                    }
                    whenever $proc.print: to-json(%payload<payload>) {
                        $proc.close-stdin;
                    }
                    whenever Promise.in(10) {
                        $proc.kill;
                        whenever Promise.in(2) {
                            say ‘Timeout. Forcing the process to stop’;
                            $proc.kill: SIGKILL
                        }
                    }
                }
                if $success {
                    content 'application/json',$output;
                } else {
                    bad-request;
                }
            }
        } else {
            forbidden;
        }
    }
}

my Cro::Service $runner = Cro::HTTP::Server.new:
    :host<localhost>, :port<8088>, :$application;

$runner.start;
say "Serving execution of examples...";

react whenever signal(SIGINT) {
    $runner.stop;
    exit;
}
