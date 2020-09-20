use Documentable;
use Documentable::Config;
use Documentable::Registry;

class Docky::Host {
    has Documentable::Registry $.registry;
    has Documentable::Config $.config;
    has %.page-sets;
    has %.index-pages;

    method new(Str $config-file = 'config.json') {
        my $registry = Documentable::Registry.new(
                topdir => 'doc/doc',
                :dirs( "Language", "Type", "Programs", "Native" ),
                :verbose);
        $registry.compose;
        my $config = Documentable::Config.new(filename => $config-file);
        my %page-set = self!generate-page-sets($registry);
        my %index-pages = self!generate-index-pages($registry, $config, %page-set);
        self.bless: :$registry, :$config, :%page-set, :%index-pages;
    }
    method !generate-index-pages(Documentable::Registry $registry, Documentable::Config $config, %all-pages) {
        my %pages;
        for Kind.enums.keys -> $kind {
            my $key = ::Kind::($kind);
            note $config.get-categories($key);
            %pages{$key.Str} = $config.get-categories($key).map(-> $category {
                %( title => $category<display-text>,
                   pages => %all-pages{$key}.grep({
                       try .pod.config<category> eq $category<name>
                   }).grep(so *).cache
                )
            });
        }
        note %pages{Kind::Programs};
        %pages;
    }

    method !generate-page-sets(Documentable::Registry $registry) {
        my %pages = Kind::Language.Str => $registry.lookup(Kind::Language.Str, :by<kind>),
                    Kind::Type.Str     => $registry.lookup(Kind::Type.Str, :by<kind>),
                    Kind::Routine.Str  => $registry.lookup(Kind::Routine.Str, :by<kind>),
                    Kind::Programs.Str => $registry.lookup(Kind::Programs.Str, :by<kind>);
    }

    method get-index-page-data(Kind $index-kind) {
        %!index-pages{$index-kind};
    }

    method get-pages($index) {
        # TODO
    }
}
