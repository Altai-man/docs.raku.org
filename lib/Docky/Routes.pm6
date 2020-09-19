use Cro::WebApp::Template;
use Cro::HTTP::Client;
use Cro::HTTP::Router;
use Docky::Constants;
use Docky::Renderer::TOC;
use Docky::Renderer::Node;
use Documentable;
use Documentable::Registry;
use Documentable::DocPage::Factory;
use Documentable::To::HTML::Wrapper;

constant GLOT_KEY = %*ENV<DOCKY_GLOT_IO_KEY>;

# TODO properly initialize everything somewhere else
my $registry = Documentable::Registry.new(
        topdir => 'doc/doc',
        :dirs( "Language", "Type", "Programs", "Native" ),
        :verbose);
$registry.compose;

my @language-pages = $registry.lookup(Kind::Language.Str, :by<kind>).map({
    %(
        title    => .name,
        url     => .url,
        description => .summary,
        category => .pod.config<category>
    )}).cache;

my $config = Documentable::Config.new(filename => 'config.json');

my @type-pages = $registry.lookup(Kind::Type.Str, :by<kind>).map({
    die $_ if .subkinds.elems > 1;
    %(
    title => .filename,
    url => .url,
    description => .summary,
    category => .subkinds[0]
)}).cache;

my @language-categories = $config.get-categories(Kind::Language).map(-> $category {
    { title => $category<display-text>, pages => @language-pages.grep({ $_<category> eq $category<name> }).cache }
});

my @type-categories = <class role>.map(-> $category {
    { title => $category.tc, pages => @type-pages.grep({ $_<category> eq $category }).cache }
});

my @kinds = $config.kinds.cache;

sub routes() is export {
    my $UI-PREFIX = "ui-samples/dist";
    template-location 'templates';

    sub calculate-categories(Str $kind) {
        given $kind {
            when Kind::Language.Str {
                my @categories-a = @language-categories[0, 1, 2, 4].cache;
                my @categories-b = @language-categories[3, 5].cache;
                return { :@categories-a, :@categories-b }
            }
            when Kind::Type.Str {
                my @categories-a = @type-categories[0];
                my @categories-b = @type-categories[1];
                return { :@categories-a, :@categories-b }
            }
            when Kind::Routine.Str {
                return { }
            }
            when Kind::Programs.Str {
                return { }
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
                :@backup-cards, |$config.config,
                :@community-links, :@resource-links, :@explore-links
            )
        }

        get -> $page where $page.ends-with('.html') {
            redirect $page.subst('.html'), :permanent;
        }

        # Page categories
        get -> $category-id where 'language'|'type' {
            with @kinds.first(*<kind> eq $category-id) -> $category {
                template 'category.crotmp', %(
                    |$config.config,
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
            state @docs = $registry.documentables.grep({ .kind eq Kind::Language });
            my $doc = @docs.first(*.url eq ('/' ~ @path.join('/')));
            my $renderer = Pod::To::HTML.new(template => $*CWD, node-renderer => Docky::Renderer::Node);
            my $html = $renderer.render($doc.pod, toc => Docky::Renderer::TOC);
            # static "$UI-PREFIX/templates/elems.html";
            template 'entry.crotmp', { title => $renderer.metadata<title> ~ ' - Raku Documentation', |$config.config, :$html };
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
    }
}
