use File::Temp;
use JSON::Fast;
use Pod::To::HTML;
use URI::Escape;
use OO::Monitors;

monitor Docky::Renderer::Node is Node::To::HTML {
    my $hl-proc = Proc::Async.new('node', 'highlights/highlight-filename-from-stdin.js', :r, :w);
    my $lock = Lock.new;
    my %code-cache;

    multi method node2html(Pod::List $node) {
        "<div class=\"content\"><ul>" ~ self.node2html($node.contents) ~ "</ul></div>\n";
    }

    multi method node2html(Pod::Heading $node) {
        # HTML only has 6 levels of numbered headings
        my $level = min($node.level, 6);
        my %escaped = id => escape_id(node2rawtext($node.contents)),
                      html => self.node2inline($node.contents);
        %escaped<uri> = uri_escape(%escaped<id>);
        my $content = %escaped<html> ~~ m{href .+ \<\/a\>}
                ?? %escaped<html>
                !! '<a class="u" href="#___top" title="go to top of document">' ~ %escaped<html> ~ '</a>';
        $content ~= qq:to/END/;

                <a class="raku-anchor" href="#%escaped<id>">§</a>
        END
        "<h$level class=\"raku-h$level\" id={ "\"%escaped<id>\"" }>$content\</h$level>\n";
    }

    sub detect-declaration(Str $code) {
        # A very hole-y number of heuristics to check if it is a signature
        # and we don't want to have 'Run' button there...
        # If there is only a single line and it starts with `class`
        $code.indices("\n").elems == 0 && $code.starts-with('class' | 'role') ||
                # There are multiple lines and all start from either multi, sub
                so $code.lines.map(*.starts-with('multi' | 'sub' | 'method' | 'proto')).all;
        # Extend rules here if necessary...
    }

    sub strip-off-formatting($node) {
        given $node {
            when Pod::FormattingCode {
                $node.contents;
            }
            default {
                $node
            }
        }
    }

    method highlight-code($node) {
        my $code = $node.contents.map(&strip-off-formatting).join;
        # my $code = $node.contents.join;
        # if $code.contains('<strong>') {
        #     say $node.contents.raku;
        # }

        $lock.protect({
            unless $hl-proc.started {
                $hl-proc.stdout.lines.tap(-> $json {
                    my $parsed-json = from-json($json);
                    my $p = %code-cache{$parsed-json<file>};
                    with $p {
                        .keep($parsed-json<html>)
                    } else {
                        note "Something went wrong during highlighting...";
                    }
                });
                note "Starting HL thread!";
                $hl-proc.start;
            }
        });

        my ($tmp_fname, $tmp_io) = tempfile;
        $tmp_io.spurt: $code, :close;

        my $p;
        $lock.protect({
            $p = %code-cache{$tmp_fname} = Promise.new;
        });
        $hl-proc.say($tmp_fname);
        await Promise.anyof($p, Promise.in(3)); # A timeout of 3 seconds that should be enough for coffee to do the job
        unlink $tmp_fname;
        if $p.status !~~ Kept {
            warn "Code example was not highlighted! Check if you have coffeescript interpreter installed or try to debug what's wrong if you have.";
            return $code;
        } else {
            return $p.result;
        }
    }

    multi method node2html(Pod::Block::Code $node) {
        # Detect language
        my $lang = $node.config<lang> || $node.config<skip-test> ?? '' !! 'raku-lang';
        my $content;
        # If it's Raku, we allow an editor
        if $lang eq 'raku-lang' {
            $content = self.highlight-code($node).subst('<pre class="editor editor-colors">',
                    '<pre class="editor editor-colors cm-s-ayaya"><code>')
                    .subst('</pre>', '</code></pre>').subst("\n", '<br>');
        } else {
            $content = '<pre class="pod-block-code">' ~ self.node2inline($node.contents) ~ "</pre>\n";
        }
        # Should we have a run button?
        my $allow-running = $lang eq 'raku-lang' && !detect-declaration($node.contents.join);
        # Allow to explicitly override our guesses
        with $node.config<runnable> -> $is-runnable {
            $allow-running = $is-runnable;
        }
        constant $code-runner = q:to/END/;
          <div class="code-output">
            <button class="button code-button" aria-label="run">Run</button>
            <div></div>
          </div>
        END
        return qq:to/END/;
        <div class="raku-code $lang">
          $content
          { $allow-running ?? $code-runner !! '' }
        </div>
        END
    }

    multi method node2html(Pod::Block::Table $node) {
        $node.config<class> = 'table is-bordered centered';
        Node::To::HTML.node2html($node);
    }

    multi method node2html(Pod::Block::Para $node, *%config --> Str) {
        with %config<versioned> {
            qq:to/END/
            <article class="raku version-note">
                <div class="version-note-header">
                    <p>Version Note</p>
                    <div class="version-related-to">
                <span class="icon">
                  <i class="fas fa-chevron-$_ is-medium"></i>
                </span>
                    </div>
                </div>

                <div class="version-body">
                    { "<p>" ~ self.node2inline($node.contents) ~ "</p>" }
                </div>
            </article>
            END
        } else {
            "<p>" ~ self.node2inline($node.contents) ~ "</p>"
        }
    }
}
