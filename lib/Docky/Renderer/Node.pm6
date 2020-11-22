use File::Temp;
use JSON::Fast;
use Pod::To::HTML;
use URI::Escape;

class Docky::Renderer::Node is Node::To::HTML {
    has $.hl-proc = Proc::Async.new('coffee', 'doc/highlights/highlight-filename-from-stdin.coffee', :r, :w);
    has %!code-cache;

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
                !!'<a class="u" href="#___top" title="go to top of document">' ~ %escaped<html> ~ '</a>';
        $content ~= qq:to/END/;

                <a class="raku-anchor" href="#%escaped<id>">§</a>
        END
        "<h$level class=\"raku-h$level\" id={ "\"%escaped<id>\"" }>$content\</h$level>\n";
    }

    sub detect-declaration(Str $code) {
        # A very hole-y number of heuristics to check if it is a signature
        # and we don't want to have 'Run' button there...
        # If there is only a single line and it starts with `class`
        $code.indices("\n").elems == 0 && $code.starts-with('class'|'role') ||
                # There are multiple lines and all start from either multi, sub
                so $code.lines.map(*.starts-with('multi'|'sub'|'method'|'proto')).all;
        # Extend rules here if necessary...
    }

    method highlight-code($node) {
        my $code = $node.contents.join;
        return $_ with %!code-cache{$code};

        unless $!hl-proc.started {
            $!hl-proc.stdout.lines.tap(-> $json {
                my $parsed-json = from-json($json);
                %!code-cache{$parsed-json<file>}.keep($parsed-json<html>);
            });
            $!hl-proc.start; # FIXME this wants a proper failure mode to avoid hang when coffee is not present
        }

        my ($tmp_fname, $tmp_io) = tempfile;
        $tmp_io.spurt: $code, :close;

        my $p = %!code-cache{$tmp_fname} = Promise.new;
        $!hl-proc.say($tmp_fname);
        my $res = $p.result;
        %!code-cache{$tmp_fname}:delete;
        unlink $tmp_fname;
        %!code-cache{$code} = $res;
        $res;
    }

    multi method node2html(Pod::Block::Code $node) {
        my $lang = $node.config<lang> ?? '' !! ' raku-lang';
        $lang = '' with $node.config<skip-test>;
        my $content = self.highlight-code($node).subst('<pre class="editor editor-colors">', '<pre class="editor editor-colors cm-s-ayaya"><code>')
                .subst('</pre>', '</code></pre>').subst("\n", '<br>');
        my $code-runner = $lang && !detect-declaration($node.contents.join) ??
        q:to/END/
          <div class="code-output">
            <button class="button code-button" aria-label="run">Run</button>
            <div></div>
          </div>
        END
        !! '';
        qq:to/END/;
        <div class="raku-code$lang">
          $content
          $code-runner
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
                    {self.node2inline($node.contents)}
                </div>
            </article>
            END
        } else {
            self.node2inline($node.contents)
        }
    }
}
