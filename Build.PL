use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'SAFT::Simple',
    license             => 'perl',
    dist_author         => 'Martin Hoppenheit <martin.hoppenheit@brhf.de>',
    dist_version_from   => 'lib/SAFT/Simple.pm',
    requires => {
        'Test::More'    => 0,
        'version'       => 0,
        'warnings'      => 0,
        'strict'        => 0,
        'Carp'          => 0,
        'utf8'          => 0,
        'XML::LibXML'   => 0,
    },
    add_to_cleanup      => [ 'SAFT-Simple-*' ],
);

$builder->create_build_script();
