use Cro::WebApp::Template;
use Cro::HTTP::Client;
use Cro::HTTP::Router;
use Docky::Constants;
use Docky::Host;
use Docky::Renderer::TOC;
use Docky::Renderer::Node;
use Docky::Routes::BackwardCompat;
use Docky::Routes::Index;
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
            $html .= subst('SIDEBAR_STYLE', ($sidebar // 'true') eq 'true' ?? '' !! 'style="width:0px; display:none;"');
            $html .= subst('SIDEBAR_TOGGLE_STYLE', ($sidebar // 'true') eq 'true' ?? '' !! 'style="left:0px;"');
            $html .= subst('SIDEBAR_SHEVRON', ($sidebar // 'true') eq 'true' ?? 'left' !! 'right');
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
                            ?? Documentable::DocPage::Primary::Type.compose-type($host.registry, $_).pod
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
                    my $pod = pod-with-title("$subkind $name",
                            pod-block("Documentation for $subkind ", pod-code($name),
                                    " assembled from the following pages:"),
                            @docs.map({
                                pod-heading("{ .origin.human-kind } { .origin.name }"),
                                pod-block("From ", pod-link(.origin.name, .url-in-origin),), .pod.list,
                            }));
                    cache-and-serve-pod($category-id, $name, $pod, :$sidebar, :$color-scheme);
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
