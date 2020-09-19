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

        "<h$level class=\"raku-h$level\" id={ "\"%escaped<id>\"" }>$content\</h$level>\n";
    }

    multi method node2html(Pod::Block::Code $node) {
        # TODO header
        # TODO results
        # TODO get back %*POD2HTML-CALLBACKS from Documentable (?)
        my $header = False ?? q:to/END/
          <div class="code-header">
            <p class="code-name">example-name.pm6</p>
            <button class="b}utton code-button" aria-label="run">Run</button>
          </div>
        END
        !! '';

        qq:to/END/;
        <div class="raku-code">
          $header
          <pre><code>{ self.node2inline($node.contents) }</code></pre>
        </div>
        END
    }
}
