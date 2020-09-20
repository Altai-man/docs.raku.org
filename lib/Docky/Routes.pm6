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
            when Kind::Type.Str {
                my @categories-a = $host.get-index-page-data(Kind::Type).cache;
                my @categories-b = $host.get-index-page-data(Kind::Type).cache;
                return { :@categories-a, :@categories-b }
            }
            when Kind::Routine.Str {
                my @categories-a = $host.get-index-page-data(Kind::Routine).cache;
                my @categories-b = $host.get-index-page-data(Kind::Routine).cache;
                return { :@categories-a, :@categories-b }
            }
            when Kind::Programs.Str {
                my @categories-a = $host.get-index-page-data(Kind::Programs).cache;
                my @categories-b = $host.get-index-page-data(Kind::Programs).cache;
                return { :@categories-a, :@categories-b }
            }
            default {
                die "'$kind'";
            }
        }

    }

    route {
        # Index
        get -> {
            template 'index.crotmp', %(
                |$host.config.config,
                :@backup-cards, :@community-links, :@resource-links, :@explore-links
            )
        }

        get -> $page where $page.ends-with('.html') {
            redirect $page.subst('.html'), :permanent;
        }

        # Page categories
        get -> $category-id where 'language'|'type'|'routine'|'programs' {
            with $host.config.kinds.first(*<kind> eq $category-id) -> $category {
                template 'category.crotmp', %(
                    |$host.config.config,
                    title => "$category<display-text> - Raku Documentation",
                    category-title => $category<display-text>,
                    category-description => $category<description>,
                    |calculate-categories($category-id)
                )
            } else {
                not-found;
            }
        }

        # Individual item page
        get -> *@path {
            state @docs = $host.registry.documentables.grep({ .kind eq Kind::Language });
            my $doc = @docs.first(*.url eq ('/' ~ @path.join('/')));
            my $renderer = Pod::To::HTML.new(template => $*CWD, node-renderer => Docky::Renderer::Node);
            my $html = $renderer.render($doc.pod, toc => Docky::Renderer::TOC);
            # static "$UI-PREFIX/templates/elems.html";
            template 'entry.crotmp', {
                title => $renderer.metadata<title> ~ ' - Raku Documentation',
                |$host.config.config, :$html };
        }

        post -> 'run' {
            request-body -> %json {
                my $code = %json<code>.subst("\x200B", '', :g); # Remove zero-width space from editing...

                my $resp = await Cro::HTTP::Client.post('https://run.glot.io/languages/perl6/latest',
                        content-type => 'application/json',
                        headers => [ 'Authorization' => 'Token ' ~ GLOT_KEY ],
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
        get -> 'css', *@path { static "$UI-PREFIX/css/", @path }
        get -> 'js',  *@path { static "static/js/",  @path }
        get -> 'img', *@path { static "$UI-PREFIX/img/", @path }
        get -> 'favicon.ico' { static "$UI-PREFIX/img/favicon.ico" }
    }
}
