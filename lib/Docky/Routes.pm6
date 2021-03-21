use OO::Monitors;
use Cro::WebApp::Template;
use Cro::HTTP::Client;
use Cro::HTTP::Router;
use Docky::Constants;
use Docky::Host;
use Docky::Renderer::TOC;
use Docky::Renderer::Node;
use Docky::Renderer::Page;
use Docky::Routes::BackwardCompat;
use Docky::Routes::Index;
use Docky::Search;
use Documentable;
use Documentable::Registry;
use Documentable::DocPage::Factory;
use Documentable::To::HTML::Wrapper;
use Pod::Utilities::Build;

constant DOCKY_EXAMPLES_EXECUTOR_HOST = %*ENV<DOCKY_EXAMPLES_EXECUTOR_HOST>;
constant DOCKY_EXAMPLES_EXECUTOR_KEY = %*ENV<DOCKY_EXAMPLES_EXECUTOR_KEY>;

sub routes(Docky::Host $host) is export {
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

        include backward-compatibility-redirects($host);

        include index-routes($host);

        my sub render-pod($category-id, $name, $pod) {
            my $renderer = Pod::To::HTML.new(template => $*CWD, node-renderer => Docky::Renderer::Node,
                    page-renderer => Docky::Renderer::Page,
                    prettyPodPath => "$category-id.tc()/$name.subst('::', '/', :g).pod6",
                    podPath => "{ $host.config.pod-root-path }/$category-id.tc()/$name.subst('::', '/', :g).pod6",
                    # FIXME this is a hack because Documentable::Config is not flexible enough...
                    editURL => "{ $host.config.pod-root-path.subst('blob', 'edit') }/$category-id.tc()/$name.subst('::', '/', :g).pod6");
            my $html = $renderer.render($pod, toc => Docky::Renderer::TOC);
            "$renderer.metadata()<title> - Raku Documentation" => $html;
        }

        sub refresh-page($page is rw, $sidebar, $color-scheme) {
            $page .= subst('SIDEBAR_STYLE', ($sidebar // 'true') eq 'true' ?? '' !! 'style="width:0px; display:none;"');
            $page .= subst('SIDEBAR_TOGGLE_STYLE', ($sidebar // 'true') eq 'true' ?? '' !! 'style="left:0px;"');
            $page .= subst('SIDEBAR_SHEVRON', ($sidebar // 'true') eq 'true' ?? 'left' !! 'right');
            $page .= subst('COLOR_SCHEME', $color-scheme // 'light', :g);
            $page ~~ s/'<strong>SVG_PLACEHOLDER_' (.+?) '</strong>'/ { compose-type-graph($0, $color-scheme // 'light') } /;
        }

        my sub cache-and-serve-pod(Str $category-id, Str $name, $pod, Str :$sidebar, Str :$color-scheme) {
            my $entry-html = render-pod($category-id, $name, $pod);
            $host.render-cache{$category-id}{$name} = render-template 'entry.crotmp',
                    { title => $entry-html.key, |$host.config.config,
                      html => $entry-html.value, :color-scheme<COLOR_SCHEME> }
            my $html = $host.render-cache{$category-id}{$name}.clone;
            # Seems like due to concurrency access to our cache sometimes $html
            # becomes Any, as if it was not filled just a moment ago...
            # So just try render it again and good luck next time.
            without $html {
                return cache-and-serve-pod($category-id, $name, $pod, :$sidebar, :$color-scheme);
            }
            refresh-page($html, $sidebar, $color-scheme);
            content 'text/html', $html;
        }

        my sub serve-cached-page($page is copy, Str :$sidebar, Str :$color-scheme) {
            # Update cached sidebar
            refresh-page($page, $sidebar, $color-scheme);
            # Serve the resulting HTML
            content 'text/html', $page;
        }

        my sub compose-type-graph($typename, $color-scheme) {
            my $template = q:to/END/;
<figure>
  <figcaption>Type relations for <code>PATH</code></figcaption>
  SVG
  <p class="fallback">
    <a rel="alternate" href="/images/type-graph-ESC_PATH.svg" type="image/svg+xml">Expand above chart</a>
  </p>
</figure>
END
            my $svg;
            my $podname = $typename;
            my $valid-path = $podname.subst(:g, /\:\:/, "");
            if "static/images/$color-scheme/type-graph-{ $valid-path }.svg".IO.e {
                $svg = $_.substr($_.index('<svg')) given ("static/images/$color-scheme/type-graph-{ $valid-path }.svg").IO.slurp;
            } else {
                $svg = "<svg></svg>";
                $podname = "404";
            }
            $template.subst("PATH", $podname).subst("ESC_PATH", $podname).subst("SVG", $svg);
        }

        my sub compose-type-page($doc) {
            # type graph
            $doc.pod.contents.append(pod-heading("Type Graph"));
            $doc.pod.contents.append(pod-bold("SVG_PLACEHOLDER_$doc.filename()"));
            # supply routines from parents and roles
            Documentable::DocPage::Primary::Type.roles-done-by-type($host.registry, $doc);
            Documentable::DocPage::Primary::Type.parent-class($host.registry, $doc);
            Documentable::DocPage::Primary::Type.roles-done-by-parent-class($host.registry, $doc);
            $doc;
        }

        # /type/Int
        get -> $category-id where 'type'|'language'|'programs', $name where not *.contains('.html'), Str :$color-scheme is cookie, Str :$sidebar is cookie {
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
                    my $pod = pod-with-title(Pod::Raw.new(target => 'html', contents => "$subkind $doc-name"),
                            pod-block("Documentation for $subkind ", pod-code($doc-name),
                                    " assembled from the following pages:"),
                            @docs.map({
                                pod-heading("{ .origin.human-kind.tc() }: { .origin.name }"),
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
                my $code = %json<code>.subst("\x200B", '', :g)
                        .subst("\x00A0", ' ', :g);

                my $resp = await Cro::HTTP::Client.post(DOCKY_EXAMPLES_EXECUTOR_HOST,
                        content-type => 'application/json',
                        headers => ['X-Access-Token' => DOCKY_EXAMPLES_EXECUTOR_KEY],
                        body => {
                            :image('glot/raku:latest'),
                            payload => { :language<raku>, files => [{ :name<main.raku>, :content($code) },] } });
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
        get -> 'css', *@path {
            cache-control(:public, :max-age(86400));
            static "static/css/", @path;
        }
        get -> 'js',  *@path {
            cache-control(:public, :max-age(86400));
            static "static/js/", @path;
        }
        get -> 'img', *@path {
            cache-control(:public, :max-age(86400));
            static "static/img/", @path;
        }
        get -> 'images', $svg-path, Str :$color-scheme is cookie {
            cache-control(:public, :max-age(86400));
            static "static/images/{ $color-scheme // 'light' }/$svg-path"
        }
        get -> 'favicon.ico' {
            cache-control(:public, :max-age(31536000));
            static "static/img/favicon.ico"
        }
    }
}
