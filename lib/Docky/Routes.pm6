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
        get -> {
            template 'index.crotmp', %(
                |$host.config.config,
                :@backup-cards, :@community-links, :@resource-links, :@explore-links
            )
        }

        # Category indexes
        get -> $category-id where 'language'|'type'|'routine'|'programs' {
            with $host.config.kinds.first(*<kind> eq $category-id) -> $category {
                my $template = $category-id eq 'language'|'programs' ?? 'category' !! 'tabbed';
                template "$template.crotmp", %(
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
            my $pod;
            # The simple way is where we have a single document to render
            # If it is not so, we need to gather each relevant piece and assemble a document
            if $category-id eq 'language'|'type'|'programs' {
                # Technically, this can be merged with `else` branch to just grep and then take first, but with .first we don't need
                # to traverse whole structure if we found the doc, while in else branch we _have to_ exhaust it to
                # make sure we don't miss some definition of some method on a page we did not traverse
                $pod = $host.registry.lookup($category-id, :by<kind>).first(*.url eq "/$category-id/$name");
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
                my $renderer = Pod::To::HTML.new(template => $*CWD, node-renderer => Docky::Renderer::Node,
                        prettyPodPath => "$category-id.tc()/$name.subst('::', '/', :g).pod6",
                        podPath => "{ $host.config.pod-root-path }/$category-id.tc()/$name.subst('::', '/', :g).pod6",
                        # FIXME this is a hack because Documentable::Config is not flexible enough...
                        editURL => "{ $host.config.pod-root-path.subst('blob', 'edit') }/$category-id.tc()/$name.subst('::', '/', :g).pod6",
                        );
                my $html = $renderer.render($_.pod, toc => Docky::Renderer::TOC);
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
        get -> 'about' {
            template 'about.crotmp', { title => 'About - Raku Documentation', |$host.config.config }
        }
        get -> 'css', *@path { static "static/css/", @path }
        get -> 'js',  *@path { static "static/js/",  @path }
        get -> 'img', *@path { static "$UI-PREFIX/img/", @path }
        get -> 'favicon.ico' { static "$UI-PREFIX/img/favicon.ico" }

        # Saint redirects for everyone, to cover as many links as possible...
        get -> $page where $page.ends-with('.html') {
            redirect $page.subst('.html'), :permanent;
        }

        #get -> 'type-basic'
    }
}
