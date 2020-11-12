use Documentable;
use Cro::HTTP::Router;
use Cro::WebApp::Template;
use Docky::Routes::Index;

# Saint redirects for everyone, to cover _as many links as possible_...
sub backward-compatibility-redirects($host) is export {
    my $index-cat-urls =
            'type' | 'type-basic' | 'type-composite' | 'type-domain-specific' | 'type-exception' | 'type-metamodel' | 'type-module' |
            'routine' | 'routine-sub' | 'routine-method' | 'routine-term' | 'routine-operator' | 'routine-trait' | 'routine-submethod'
            ;

    route {
        # First, just redirect folks with `.html` to extension-less pages
        get -> $page where $page.ends-with('.html') {
            redirect $page.subst('.html'), :permanent;
        }

        # Index pages by categories...
        get -> Str $index-by-category where * ~~ $index-cat-urls, :$color-scheme is cookie {
            my @category-kind = $index-by-category.split('-');
            my $category = $host.config.kinds.first(*<kind> eq @category-kind[0]);
            template "index/large.crotmp", %(
                |$host.config.config, color-scheme => $color-scheme // 'light',
                title => "$category<display-text> - Raku Documentation",
                category-title => $category<display-text>,
                category-description => $category<description>,
                |calculate-categories(
                        $host, TemplateKind::large, Kind::{@category-kind[0].tc},
                        category-kind => @category-kind[1..*].join('-'))
            );
        }
    }
}