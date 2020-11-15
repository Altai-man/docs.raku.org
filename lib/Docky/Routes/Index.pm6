use Docky::Host;
use Documentable;
use Cro::WebApp::Template;
use Cro::HTTP::Router;
use Pod::Utilities::Build;

enum TemplateKind <small medium large>;

# FIXME caching of all this...
sub calculate-categories(Docky::Host $host, TemplateKind $tmpl-kind,
                         Kind $doc-kind, :$category-kind = 'all') is export {
    my %render-data;
    my $OPERATOR-NAMES = 'prefix' | 'listop' | 'infix' | 'postcircumfix' | 'postfix' | 'postcircumfix' | 'circumfix';

    if $tmpl-kind == TemplateKind::small {
        %render-data<items> = $host.get-index-page-data(Kind::Programs)[0]<pages>;
    } elsif $tmpl-kind == TemplateKind::medium {
        # Magic numbers here represent what categories will go into left and right column respectively
        # to be visually more or less even
        %render-data<categories-a> = $host.get-index-page-data(Kind::Language)[0, 1, 2, 4].cache;
        %render-data<categories-b> = $host.get-index-page-data(Kind::Language)[3, 5].cache;
    } elsif $tmpl-kind == TemplateKind::large {
        # Now this is the most interesting piece of indexing,
        # serving both routines and types

        # Get some basic data
        my @columns = <Name Type Description>;
        my @docs = $host.registry.lookup($doc-kind.Str, :by<kind>);
        my @kinds = $host.config.kinds.first(*.<kind> eq $doc-kind.Str)<categories>.flat;

        # Create content of "All" category
        # Get all doc pages, for each page create a row in the table
        my $all = @docs.map( -> $doc-item {
            $doc-item.categorize(*.name).map({
                # Here we have `name -> array of pod pages` to be $_,
                # for types the array always consists of a single element, so gather summary etc
                if $doc-kind ~~ Kind::Type {
                    ["<a href=\"$_.value()[0].url()\">$_.key()\</a>", .value[0].subkinds.Str, .value[0].summary,
                     .value[0].pod.config<category>];
                }
                else {
                    # Routines are a bit more delicate, we can get a bunch of pages, so process them accordingly
                    ["<a href=\"$_.value()[0].url()\">$_.key()\</a>", .value.map(*.subkinds).flat.unique.join(', '),
                     "From ({ .value.map({ "<a href=\"$_.url-in-origin()\">$_.origin.name()\</a>" }).join(', ') })"];
                }
            }).Slip
        }).sort(*[0]).cache;

        my @tabs;
        # Now it is time to split complete "All" tab into separate branches...
        # This is not a terribly efficient way to do this as we have to grep the list O(@kinds) number of times,
        # and something smarter probably can be made with .categorize,
        # but since we most likely want to cache result of this anyway, the clarity wins
        my $active-category;
        for @kinds -> $kind {
            my @rows;
            # This is a workaround because we do not have a separate "infix" etc categories on page, just "operators"...
            if $kind<name> eq 'operator' {
                @rows = $all.grep(so *[1].contains($OPERATOR-NAMES)).map(*[^3]);
            } else {
                @rows = $all.grep($doc-kind ~~ Kind::Type ?? *[3] eq $kind<name> !! *[1].contains($kind<name>)).map(*[^3]);
            }
            my $is-active = $category-kind eq $kind<name>;
            $active-category = $category-kind if $is-active;
            @tabs.push: %( name => $kind<name>, :$is-active, :@rows, :@columns, display-text => $kind<display-text>,
                           title => "Raku $kind<name> {$doc-kind.Str}s",
                           description => "This is a list of built-in { $kind<name> } {$doc-kind.Str.tc}s that are documented here as part of the Raku language."
            );
        };
        # Add first 'All' tab
        @tabs.unshift: %( name => 'all', :is-active($category-kind eq 'all'), :@columns, rows => $all.map(*[^3]), display-text => 'All',
                          title => "Raku {$doc-kind.Str}s",
                          description => "This is a list of built-in {$doc-kind.Str.tc}s that are documented here as part of the Raku language."
        );

        # Now let's pack this table with additional data into our render data
        %render-data<tabs> = @tabs;
        %render-data<section-title> = "Raku $active-category {$doc-kind.Str}s";
        %render-data<section-description> = "This is a list of built-in { $active-category } {$doc-kind.Str.tc}s that are documented here as part of the Raku language.";
    }
    %render-data;
}

# Category indexes
sub index-routes($host) is export {
    route {
        get -> $category-id where 'language' | 'type' | 'routine' | 'programs', :$color-scheme is cookie {
            my $category = $host.config.kinds.first(*<kind> eq $category-id);
            # We have three views to demonstrate data depending on number of items:
            # * Small: programs
            # * Medium: language
            # * Large: type, routine
            my TemplateKind $template = do given $category-id {
                when 'programs' { TemplateKind::small }
                when 'language' { TemplateKind::medium }
                when 'type' | 'routine' { TemplateKind::large }
            }
            template "index/$template.crotmp", %(
                |$host.config.config, color-scheme => $color-scheme // 'light',
                title => "$category<display-text> - Raku Documentation",
                category-title => $category<display-text>,
                category-description => $category<description>,
                |calculate-categories($host, $template, (Kind::{$category-id.tc}))
            );
        }
    }
}
