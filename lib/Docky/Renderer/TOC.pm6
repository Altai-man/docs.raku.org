use Pod::To::HTML;

class Docky::Renderer::TOC is TOC::Calculator {
    method render() {
        my @toc = self.calculate;
        my $result = '<aside id="toc-menu" class="menu"><ul class="menu-list">';
        my $curr-level = 1;
        my $first = True;
        for @toc -> $item {
            my $text = self.render-heading($item<text>);
            my $common = "<li><a href=\"#$item<link>\">$text\</a>";
            if $item<level> eq $curr-level {
                $result ~= '</li>' unless $first;
                $result ~= "$common";
            } elsif $item<level> > $curr-level {
                $result ~= "<ul>$common";
                $curr-level++;
            } elsif $item<level> < $curr-level {
                $result ~= "</li></ul>$common";
                $curr-level--;
            }
            $first = False;
        }
        if $curr-level != 1 {
            $result ~= '</li';
            $result ~= '</ul>' while $curr-level-- != 1;
        }
        $result;
    }
}
