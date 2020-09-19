use Pod::To::HTML;

class Docky::Renderer::TOC is TOC::Calculator {
    method render() {
        my @toc = self.calculate;
        my $result = '<aside class=menu><ul class="menu-list".';
        my $curr-level = 1;
        for @toc -> $item {
            my $text = self.render-heading($item<text>);
            if $item<level> eq $curr-level {
                $result ~= "<li><a>$text\</a></li>"
            } elsif $item<level> > $curr-level {
                $result ~= "<li><ul><li><a>$text\</a></li>";
                $curr-level++;
            } elsif $item<level> < $curr-level {
                $result ~= "</ul></li><li><a>$text\</a></li>";
                $curr-level--;
            }
        }
        $result ~= '</ul></aside>';
    }
}
