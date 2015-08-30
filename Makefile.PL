use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'DBIx::FlexibleBinding',
    AUTHOR             => 'Iain Campbell <cpanic@cpan.org>',
    VERSION_FROM       => 'lib/DBIx/FlexibleBinding.pm',
    ABSTRACT_FROM      => 'lib/DBIx/FlexibleBinding.pm',
    LICENSE            => 'gpl_2',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006,
    CONFIGURE_REQUIRES => {
                            'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
                        'Test::More'  => 0,
                        'DBI'         => 0,
                        'DBD::SQLite' => 0,
                        'JSON::Syck'  => 0,
    },
    PREREQ_PM => {
                   'DBI'              => 0,
                   'List::MoreUtils'  => 0,
                   'MRO::Compat'      => 0,
                   'Scalar::Util'     => 0,
                   'namespace::clean' => 0,
    },
    META_MERGE => {
                    'meta-spec' => { version => 2 },
                    resources   => {
                                   repository => {
                                                   type => 'git',
                                                   url  => 'https://github.com/cpanic/Params-Callbacks.git',
                                                   web  => 'https://github.com/cpanic/Params-Callbacks',
                                   },
                    },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'DBIx-FlexibleBinding-*' },
);
