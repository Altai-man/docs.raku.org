use v6.d;

use Cro::HTTP::Router;
use Documentable::Utils::IO;
use Documentable::Registry;

sub updater($host) { # more configuration if needed?
    # update the repo
    my $proc = run <git pull origin master>, :cwd($*CWD.child('doc'));

    return unless $proc.exitcode == 0;

    # update the registry
    say $host.render-cache;
    my $doc-path = 'doc/doc'.IO.absolute;
    my $cache = init-cache($doc-path);
    my @changed-files = $cache.list-files;

    say @changed-files;

    # Nothing to update
    return unless @changed-files;

    # Update registry
    $host.registry = Documentable::Registry.new(
        topdir => 'doc/doc',
        :dirs("Language", "Type", "Programs", "Native"),
        :verbose, :typegraph-file('doc/type-graph.txt')
    );
    $host.registry.compose;

    # Remove old page(s) form the cache
    for @changed-files -> $file {
        my $rel-path = $file.IO.relative($doc-path);
        my ($category-id, @name) = $rel-path.split($rel-path.IO.SPEC.dir-sep);
        # Turn 'X/AdHoc.pod6' into 'X::AdHoc'
        my $name = @name.join('::').subst('.pod6', '');
        $host.render-cache{$category-id.lc}{$name}:delete;
    }

    # update revision to show
    $host.info<content_version> = run(<git describe>, :cwd($*CWD.child('doc')), :out).out.slurp(:close).trim;
}

# Routes accepting outer commands such as update, info
sub command-routes($host) is export {
    my $update-p = Promise.kept;
    my $command-lock = Lock.new;

    route {
        get -> 'info' {
            content 'application/json', {
                content-version => $host.info<content-revision>
            };
        }

        get -> 'update', :$token is query {
            my $old = $host.info<content-version>;

            if $token eq %*ENV<DOCKY_COMMAND_TOKEN> {
                # Ensure we are not causing a conflict
                $command-lock.protect({
                    # finished the previous update
                    if $update-p.status == Kept || $update-p.status == Broken {
                        # report previous error
                        if $update-p.status == Broken {
                            try {
                                $update-p.result;
                                CATCH {
                                    default {
                                        .note;
                                    }
                                }
                            }
                        }
                        $update-p = start updater($host);
                        content 'application/json', { status => 'updating', :$old };
                    }
                    # if update is still working
                    if $update-p.status == Planned {
                        content 'application/json', { status => 'updating', :$old };
                    }
                });
            }
            else {
                forbidden;
            }
        }
    }
}
