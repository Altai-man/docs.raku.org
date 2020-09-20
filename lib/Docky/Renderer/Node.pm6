use URI::Escape;
use Pod::To::HTML;

class Docky::Renderer::Node is Node::To::HTML {
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

    multi method node2html(Pod::Block::Code $node) {
        my $lang = $node.config<lang> ?? '' !! ' raku-lang';
        my $header = $lang ??
        q:to/END/
        <div class="code-header">
          <p class="code-name">example-name.pm6</p>
          <button class="button code-button" aria-label="run">Run</button>
        </div>
        END
        !! '';
        # TODO get back %*POD2HTML-CALLBACKS from Documentable (?)
        qq:to/END/;
        <div class="raku-code$lang">
          $header
          <pre><code>{ self.node2inline($node.contents) }</code></pre>
          <div class="code-output">
            <p class="code-output-title">Output</p>
          </div>
        </div>
        END
    }

    multi method node2html(Pod::Block::Table $node) {
        $node.config<class> = 'table is-bordered centered';
        Node::To::HTML.node2html($node);
    }
}
