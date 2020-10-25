use Cro::WebApp::Template;
use Cro::HTTP::Client;
use Cro::HTTP::Router;
use Docky::Constants;
use Docky::Host;
use Docky::Renderer::TOC;
use Docky::Renderer::Node;
use Documentable;
use Documentable::Registry;
use Documentable::DocPage::Factory;
use Documentable::To::HTML::Wrapper;
use Pod::Utilities::Build;

constant GLOT_KEY = %*ENV<DOCKY_GLOT_IO_KEY>;

sub routes(Docky::Host $host) is export {
    my $UI-PREFIX = "ui-samples/dist";
    template-location 'templates';

    sub calculate-categories(Str $kind) {
        # FIXME this is very temporary, as index page design is not established yet
        given $kind {
            when Kind::Language.Str {
                my @categories-a = $host.get-index-page-data(Kind::Language)[0, 1, 2, 4].cache;
                my @categories-b = $host.get-index-page-data(Kind::Language)[3, 5].cache;
                return { :@categories-a, :@categories-b }
            }
            when Kind::Programs.Str {
                my @categories-a = $host.get-index-page-data(Kind::Programs).cache;
                my @categories-b = $host.get-index-page-data(Kind::Programs).cache;
                return { :@categories-a, :@categories-b }
            }
            when Kind::Type.Str {
                my @docs = $host.registry.lookup(Kind::Type.Str, :by<kind>)
                        .categorize(*.name).sort(*.key).map(*.value)
                        .map({%(
                    name     => .[0].name,
                    url      => .[0].url,
                    subkinds => .map({.subkinds // Nil}).flat.unique.List,
                    summary  => .[0].summary,
                    subkind  => .[0].subkinds[0]
                )}).cache;

                my @columns = <name Type Description>;
                my @rows = @docs.map({
                    ["<a href=\"$_.<url>\">$_.<name>\</a>", .<subkinds>, .<summary>]
                }).cache;
                my @tabs;
                @tabs.push: %( :is-active, :display-text<All>, :name<all>, :@columns, :@rows );
                @tabs.append: $host.config.get-categories(Kind::Type).map({ %( name => .<name>, display-text => .<display-text>, :!is-active, :@columns, :@rows ) });
                return @( :@tabs, :section-title('Raku Types'), :section-description('This is a list of all built-in Types that are documented here as part of the Raku language.') );
            }
            when Kind::Routine.Str {
                my @tabs;
                @tabs.push: %( :is-active, :display-text<All>, :title('This is a list of all built-in Types that are documented here as part of the Raku language. Use the above menu to narrow it down topically.') );
                @tabs.append: $host.config.get-categories(Kind::Routine).map({ %( display-text => .<display-text>, :!is-active ) });
                return :@tabs;
            }
            default {
                die "'$kind'";
            }
        }
    }

    route {
        # Index
        get -> :$color-scheme is cookie {
            template 'index.crotmp', %(
                |$host.config.config,
                :@backup-cards, :@community-links, :@resource-links, :@explore-links,
                color-scheme => $color-scheme // 'light'
            )
        }

        # Category indexes
        get -> $category-id where 'language' | 'type' | 'routine' | 'programs', :$color-scheme is cookie {
            with $host.config.kinds.first(*<kind> eq $category-id) -> $category {
                my $template = $category-id eq 'language' | 'programs' ?? 'category' !! 'tabbed';
                template "$template.crotmp", %(
                    |$host.config.config, color-scheme => $color-scheme // 'light',
                    title => "$category<display-text> - Raku Documentation",
                    category-title => $category<display-text>,
                    category-description => $category<description>,
                    |calculate-categories($category-id)
                )
            } else {
                not-found;
            }
        }

        sub render-pod($category-id, $name, $pod) {
            my $renderer = Pod::To::HTML.new(template => $*CWD, node-renderer => Docky::Renderer::Node,
                    prettyPodPath => "$category-id.tc()/$name.subst('::', '/', :g).pod6",
                    podPath => "{ $host.config.pod-root-path }/$category-id.tc()/$name.subst('::', '/', :g).pod6",
                    # FIXME this is a hack because Documentable::Config is not flexible enough...
                    editURL => "{ $host.config.pod-root-path.subst('blob', 'edit') }/$category-id.tc()/$name.subst('::', '/', :g).pod6");
            my $html = $renderer.render($pod, toc => Docky::Renderer::TOC);
            "$renderer.metadata()<title> - Raku Documentation" => $html;
        }

        # /type/Int
        get -> $category-id where 'type'|'language'|'programs', $name, :$color-scheme is cookie {
            with $host.render-cache{$category-id}{$name} -> $page {
                template 'entry.crotmp', { title => $page.key, |$host.config.config, html => $page.value,
                                           color-scheme => $color-scheme // 'light' }
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
                    my $page = $host.render-cache{$category-id}{$name} = render-pod($category-id, $name, $pod);
                    template 'entry.crotmp', { title => $page.key, |$host.config.config, html => $page.value,
                                               color-scheme => $color-scheme // 'light' }
                } else {
                    not-found;
                }
            }
        }

        # /syntax/token...
        get -> $category-id where 'routine' | 'reference' | 'syntax', $name, :$color-scheme is cookie {
            with $host.render-cache{$category-id}{$name} -> $page {
                template 'entry.crotmp', { title => $page.key, |$host.config.config, html => $page.value,
                                           color-scheme => $color-scheme // 'light' }
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
                    my $page = $host.render-cache{$category-id}{$name} = render-pod($category-id, $name, $pod);
                    template 'entry.crotmp', { title => $page.key, |$host.config.config, html => $page.value,
                                               color-scheme => $color-scheme // 'light' }
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
        get -> 'about', :$color-scheme is cookie {
            template 'about.crotmp', { title => 'About - Raku Documentation', |$host.config.config,
                                       color-scheme => $color-scheme // 'light' }
        }
        get -> 'css', *@path { static "static/css/", @path }
        get -> 'js',  *@path { static "static/js/", @path }
        get -> 'img', *@path { static "$UI-PREFIX/img/", @path }
        get -> 'images', $svg-path { static "doc/html/images/$svg-path" }
        get -> 'favicon.ico' { static "$UI-PREFIX/img/favicon.ico" }

        # Saint redirects for everyone, to cover as many links as possible...
        # First, just redirect folks with `.html` to extension-less pages
        get -> $page where $page.ends-with('.html') {
            redirect $page.subst('.html'), :permanent;
        }
    }
}
