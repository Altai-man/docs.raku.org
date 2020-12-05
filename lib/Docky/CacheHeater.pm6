use URI::Escape;
use Docky::Host;

class Docky::CacheHeater {
    method heat-cache(Docky::Host $host) {
        my @urls;

        for $host.index-pages.map(*.value) -> $category {
            for $category.map(*<pages>) -> $pages {
                @urls.append: $pages.map(*.url);
            }
        }
        for <routine reference syntax> -> $category {
            for @($host.registry.lookup($category, :by<kind>)) -> $page {
                @urls.append: "/$category/" ~ uri-escape($page.url.substr($category.chars + 2))
            }
        }
        my $count = 0;

        say "Started heating at {DateTime.now}";
        @urls.race.map({
            say "Heated $count pages out of @urls.elems()" if ++$count %% 20;
            run 'curl', "http://{ %*ENV<DOCKY_HOST> }:{ %*ENV<DOCKY_PORT> }$_", :!out, :!err;
        });
        say "Done heating at {DateTime.now}";
    }
}
