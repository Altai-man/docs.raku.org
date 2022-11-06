use Documentable;
use Documentable::Config;
use Documentable::Registry;

class Docky::Host {
    has Documentable::Registry $.registry is rw;
    has Documentable::Config $.config;
    has %.info;
    has %.page-sets;
    has %.index-pages;
    has %.render-cache;

    my class Heading::Actions {
        has Str  $.dname     = '';
        has      $.dkind     ;
        has Str  $.dsubkind  = '';
        has Str  $.dcategory = '';

        method name($/) {
            $!dname = $/.Str;
        }

        method single-name($/) {
            $!dname = $/.Str;
        }

        method subkind($/) {
            $!dsubkind = $/.Str.trim;
        }

        method operator($/) {
            $!dkind     = Kind::Routine;
            $!dcategory = "$/.Str().tc() operators";
        }

        method routine($/) {
            $!dkind     = Kind::Routine;
            $!dcategory = do given $/.Str {
                when 'sub'|'routine' { 'Subroutines' }
                when 'method'|'submethod' { 'Methods' }
                when 'term' { 'Terms' }
                when 'trait' { 'Traits' }
            }
        }

        method syntax($/) {
            $!dkind     = Kind::Syntax;
            $!dcategory = do given $/.Str {
                when 'twigil'|'quote'|'declarator' { 'Syntax' }
                when 'constant' { 'Reference' }
                when 'variable' { 'Variables' }
            }
        }
    }

    method new(Str $config-file = 'config.json') {
        my $*HEADING-TO-ANCHOR-TRANSFORMER-ACTIONS = Heading::Actions.new;

        my $registry = Documentable::Registry.new(
                topdir => 'doc/doc',
                :dirs("Language", "Type", "Programs", "Native"),
                :verbose, :typegraph-file('doc/type-graph.txt'));
        $registry.compose;
        my $config = Documentable::Config.new(filename => $config-file);
        my %info = content-version =>
            run(<git describe>, :cwd($*CWD.child('doc')), :out).out.slurp(:close).trim;
        my %index-pages := self!generate-index-pages($registry, $config);
        self.bless: :$registry, :$config, :%index-pages, :%info;
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
                }).grep(so *).sort(*.name).cache;
                %( title => $category<display-text>, :$pages )
            }).cache;
        }
        %index-pages;
    }

    method get-index-page-data(Kind $index-kind) {
        %!index-pages{$index-kind};
    }
}
