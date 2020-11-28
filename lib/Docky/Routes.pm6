use Cro::WebApp::Template;
use Cro::HTTP::Client;
use Cro::HTTP::Router;
use Docky::Constants;
use Docky::Host;
use Docky::Renderer::TOC;
use Docky::Renderer::Node;
use Docky::Routes::BackwardCompat;
use Docky::Routes::Index;
use Docky::Search;
use Documentable;
use Documentable::Registry;
use Documentable::DocPage::Factory;
use Documentable::To::HTML::Wrapper;
use Pod::Utilities::Build;

constant GLOT_KEY = %*ENV<DOCKY_GLOT_IO_KEY>;

sub routes(Docky::Host $host) is export {
    my $UI-PREFIX = "ui-samples/dist";
    template-location 'templates';

    route {
        after {
            template '404.crotmp', hash if .status == 404;
            template '500.crotmp', hash if .status == 500;
        }

        # Index
        get -> Str :$color-scheme is cookie {
            template 'index.crotmp', %(
                |$host.config.config,
                :@backup-cards, :@community-links, :@resource-links, :@explore-links,
                color-scheme => $color-scheme // 'light'
            )
        }

        include index-routes($host);

        my sub render-pod($category-id, $name, $pod) {
            my $renderer = Pod::To::HTML.new(template => $*CWD, node-renderer => Docky::Renderer::Node,
                    prettyPodPath => "$category-id.tc()/$name.subst('::', '/', :g).pod6",
                    podPath => "{ $host.config.pod-root-path }/$category-id.tc()/$name.subst('::', '/', :g).pod6",
                    # FIXME this is a hack because Documentable::Config is not flexible enough...
                    editURL => "{ $host.config.pod-root-path.subst('blob', 'edit') }/$category-id.tc()/$name.subst('::', '/', :g).pod6");
            my $html = $renderer.render($pod, toc => Docky::Renderer::TOC);
            "$renderer.metadata()<title> - Raku Documentation" => $html;
        }

        my sub serve-cached-page($page, Str :$sidebar, Str :$color-scheme) {
            my $html = $page.value.clone;
            # Update cached sidebar
            $html .= subst('SIDEBAR_STYLE', ($sidebar // 'true') eq 'true' ?? '' !! 'style="width:0px; display:none;"');
            $html .= subst('SIDEBAR_TOGGLE_STYLE', ($sidebar // 'true') eq 'true' ?? '' !! 'style="left:0px;"');
            $html .= subst('SIDEBAR_SHEVRON', ($sidebar // 'true') eq 'true' ?? 'left' !! 'right');
            # Update cached SVG if any
            $html .= subst('<strong>SVG_PLACEHOLDER</strong>', compose-type-graph($page));
            template 'entry.crotmp', { title => $page.key, |$host.config.config, :$html,
                                       :color-scheme($color-scheme // 'light') }
        }

        my sub cache-and-serve-pod(Str $category-id, Str $name, $pod, Str :$sidebar, Str :$color-scheme) {
            $host.render-cache{$category-id}{$name} = render-pod($category-id, $name, $pod);
            my $page = $host.render-cache{$category-id}{$name}.clone;
            $page.value .= subst('SIDEBAR_STYLE',
            ($sidebar // 'true') eq 'true' ?? '' !! 'style="width:0px; display:none;"');
            $page.value .= subst('SIDEBAR_TOGGLE_STYLE', ($sidebar // 'true') eq 'true' ?? '' !! 'style="left:0px;"');
            $page.value .= subst('SIDEBAR_SHEVRON', ($sidebar // 'true') eq 'true' ?? 'left' !! 'right');
            template 'entry.crotmp', { title => $page.key, |$host.config.config, html => $page.value,
                                       :color-scheme($color-scheme // 'light') }
        }

        my sub compose-type-graph($doc, :$color-scheme = 'light') {
            my $template = q:to/END/;
<figure>
  <figcaption>Type relations for <code>PATH</code></figcaption>
  SVG
  <p class="fallback">
    <a
      rel="alternate"
      href="/images/type-graph-ESC_PATH.svg"
      type="image/svg+xml"
      >Expand above chart</a
    >
  </p>
</figure>
END
            my $svg;
            my $podname = $doc.key.words[1];
            my $valid-path = $podname.subst(:g, /\:\:/, "");
            if "static/images/$color-scheme/type-graph-{ $valid-path }.svg".IO.e {
                $svg = $_.substr($_.index('<svg')) given ("static/images/$color-scheme/type-graph-{ $valid-path }.svg").IO.slurp;
            } else {
                $svg = "<svg></svg>";
                $podname = "404";
            }
            my $figure = $template.subst("PATH", $podname)
                    .subst("ESC_PATH", $podname)
                    .subst("SVG", $svg);

            return [
                pod-heading("Type Graph"),
                Pod::Raw.new: :target<html>,
                        contents => [$figure]
            ]
        }

        my sub compose-type-page($doc) {
            $doc.pod.contents.append: pod-bold('SVG_PLACEHOLDER');
            # supply all routines
            Documentable::DocPage::Primary::Type.roles-done-by-type($host.registry, $doc);
            Documentable::DocPage::Primary::Type.parent-class($host.registry, $doc);
            Documentable::DocPage::Primary::Type.roles-done-by-parent-class($host.registry, $doc);
            $doc;
        }

        # /type/Int
        get -> $category-id where 'type'|'language'|'programs', $name, Str :$color-scheme is cookie, Str :$sidebar is cookie {
            with $host.render-cache{$category-id}{$name} -> $page {
                serve-cached-page($page, :$sidebar, :$color-scheme);
            } else {
                my $kind = do given $category-id {
                    when 'type'     { Kind::Type     }
                    when 'language' { Kind::Language }
                    when 'programs' { Kind::Programs }
                }
                my $doc = $host.registry.documentables.first({ .kind eq $kind && .url eq "/$category-id/$name" });
                with $doc {
                    my $pod = $kind eq Kind::Type
                            ?? compose-type-page($_).pod
                            !! $_.pod;
                    cache-and-serve-pod($category-id, $name, $pod, :$sidebar, :$color-scheme);
                } else {
                    not-found;
                }
            }
        }

        # /syntax/token...
        get -> $category-id where 'routine' | 'reference' | 'syntax', $name, Str :$color-scheme is cookie, Str :$sidebar is cookie {
            with $host.render-cache{$category-id}{$name} -> $page {
                serve-cached-page($page, :$sidebar, :$color-scheme);
            } else {
                my @docs = $host.registry.lookup($category-id, :by<kind>).grep(*.url eq "/$category-id/$name");
                if @docs.elems {
                    my @subkinds = @docs.map({ slip .subkinds }).unique;
                    my $subkind = @subkinds == 1 ?? @subkinds[0] !! $category-id;
                    my $doc-name = @docs[0].name;
                    my $pod = pod-with-title("$subkind $doc-name",
                            pod-block("Documentation for $subkind ", pod-code($doc-name),
                                    " assembled from the following pages:"),
                            @docs.map({
                                pod-heading("{ .origin.human-kind } { .origin.name }"),
                                pod-block("From ", pod-link(.origin.name, .url-in-origin),), .pod.list,
                            }));
                    cache-and-serve-pod($category-id, $doc-name, $pod, :$sidebar, :$color-scheme);
                }
                else {
                    not-found;
                }
            }
        }

        post -> 'run' {
            request-body -> %json {
                # Remove zero-width space from editing...
                my $code = %json<code>.subst("\x200B", '', :g);

                my $resp = await Cro::HTTP::Client.post('https://run.glot.io/languages/perl6/latest',
                        content-type => 'application/json',
                        headers => ['Authorization' => 'Token ' ~ GLOT_KEY],
                        body => { files => [{ :name<main.p6>, :content($code) },] });
                if $resp.status eq 200 {
                    my $json = await $resp.body;
                    content 'text/plain',
                            ($json<stdout>.subst("\n", '<br>', :g),
                             ($json<stderr> ?? "STDERR:<br>$json<stderr>".subst("\n", '<br>', :g) !! '')).join;
                } else {
                    bad-request;
                }
            }
        }

        # Search...
        get -> 'search', Str :$q is query, Str :$color-scheme is cookie {
            my @cats = generate-categories($host);
            template 'search.crotmp', {
                title => 'Search - Raku Documentation',
                :@cats,
                |$host.config.config, color-scheme => $color-scheme // 'light' };
        }

        # Statics
        get -> 'about', Str :$color-scheme is cookie {
            template 'about.crotmp', { title => 'About - Raku Documentation', |$host.config.config,
                                       color-scheme => $color-scheme // 'light' }
        }
        get -> 'css', *@path { static "static/css/", @path }
        get -> 'js',  *@path { static "static/js/", @path }
        get -> 'img', *@path { static "$UI-PREFIX/img/", @path }
        get -> 'images', $svg-path, Str :$color-scheme is cookie { static "static/images/{ $color-scheme // 'light' }/$svg-path" }
        get -> 'favicon.ico' { static "$UI-PREFIX/img/favicon.ico" }

        include backward-compatibility-redirects($host);
    }
}
