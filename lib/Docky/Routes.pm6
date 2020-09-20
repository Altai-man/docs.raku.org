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

        # Redirect from `.html` FIXME more redirects, much more
        get -> $page where $page.ends-with('.html') {
            redirect $page.subst('.html'), :permanent;
        }

        # Category indexes
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

        # /type/Int or /syntax/token...
        get -> $category-id where 'language'|'type'|'programs'|'routine'|'reference'|'syntax', $name {
            my $renderer = Pod::To::HTML.new(template => $*CWD, node-renderer => Docky::Renderer::Node);
            my $pod;
            # The simple way is where we have a single document to render
            # If it is not so, we need to gather each relevant piece and assemble a document
            if $category-id eq 'language'|'type'|'programs' {
                # Technically, this can be merged with `else` branch to just grep and then take first, but with .first we don't need
                # to traverse whole structure if we found the doc, while in else branch we _have to_ exhaust it to
                # make sure we don't miss some definition of some method on a page we did not traverse
                $pod = $_.pod with $host.registry.lookup($category-id, :by<kind>).first(*.url eq "/$category-id/$name");
            }
            else {
                my @docs = $host.registry.lookup($category-id, :by<kind>).grep(*.url eq "/$category-id/$name");
                $pod = pod-with-title("SUBKIND TODO $name",
                        pod-block("Documentation for SUBKIND TODO ", pod-code($name), " assembled from the following types:"),
                        @docs.map({
                            pod-heading("{.origin.human-kind} {.origin.name}"),
                            pod-block("From ", pod-link(.origin.name, .url-in-origin),), .pod.list,
                        })) if @docs.elems != 0;;
            }
            with $pod {
                my $html = $renderer.render($_, toc => Docky::Renderer::TOC);
                template 'entry.crotmp', { title => $renderer.metadata<title> ~ ' - Raku Documentation',
                                           |$host.config.config, :$html }
            }
            else {
                not-found;
            }
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
