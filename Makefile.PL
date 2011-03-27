use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SAFT::Simple',
    AUTHOR              => 'Martin Hoppenheit <martin.hoppenheit@brhf.de>',
    VERSION_FROM        => 'lib/SAFT/Simple.pm',
    ABSTRACT_FROM       => 'lib/SAFT/Simple.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'    => 0,
        'version'       => 0,
        'warnings'      => 0,
        'strict'        => 0,
        'Carp'          => 0,
        'utf8'          => 0,
        'XML::LibXML'   => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SAFT-Simple-*' },
);
