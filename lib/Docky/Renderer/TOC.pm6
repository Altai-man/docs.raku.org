use Pod::To::HTML;

class Docky::Renderer::TOC is TOC::Calculator {
    method render() {
        my @toc = self.calculate;
        my $result = '<aside class="menu"><ul class="menu-list">';
        my $curr-level = 1;
        for @toc -> $item {
            my $text = self.render-heading($item<text>);
            my $common = "<li><a href=\"#$item<link>\">$text\</a>";
            if $item<level> eq $curr-level {
                $result ~= $common;
            } elsif $item<level> > $curr-level {
                $result ~= "<li><ul>$common\</li>";
                $curr-level++;
            } elsif $item<level> < $curr-level {
                $result ~= "</ul></li>$common\</li>";
                $curr-level--;
            }
        }
        $result ~= '</ul></aside>';
    }
}
