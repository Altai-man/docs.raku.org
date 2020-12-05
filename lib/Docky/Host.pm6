use Documentable;
use Documentable::Config;
use Documentable::Registry;

class Docky::Host {
    has Documentable::Registry $.registry;
    has Documentable::Config $.config;
    has %.page-sets;
    has %.index-pages;
    has %.render-cache;

    method new(Str $config-file = 'config.json') {
        my $registry = Documentable::Registry.new(
                topdir => 'doc/doc',
                :dirs("Language", "Type", "Programs", "Native"),
                :verbose, :typegraph-file('doc/type-graph.txt'));
        $registry.compose;
        my $config = Documentable::Config.new(filename => $config-file);
        my %index-pages := self!generate-index-pages($registry, $config);
        self.bless: :$registry, :$config, :%index-pages;
    }

    method !generate-index-pages($registry, Documentable::Config $config) {
        my %all-pages = %( Kind::Language.Str => $registry.lookup(Kind::Language.Str, :by<kind>),
                           Kind::Type.Str => $registry.lookup(Kind::Type.Str, :by<kind>),
                           Kind::Routine.Str => $registry.lookup(Kind::Routine.Str, :by<kind>),
                           Kind::Programs.Str => $registry.lookup(Kind::Programs.Str, :by<kind>)
        );
        my %index-pages;
        for Kind.enums.keys -> $kind {
            my $key = Kind::{$kind};
            %index-pages{$key.Str} = $config.get-categories($key).map(-> $category {
                my $pages = %all-pages{$key}.grep({
                    try .pod.config<category> eq $category<name>
                }).grep(so *).cache;
                %( title => $category<display-text>, :$pages )
            }).cache;
        }
        %index-pages;
    }

    method get-index-page-data(Kind $index-kind) {
        %!index-pages{$index-kind};
    }
}
