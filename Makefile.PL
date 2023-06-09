use 5.008000;
use ExtUtils::MakeMaker;
use ExtUtils::PkgConfig;

unless( -f 'Changes' ) {
	system('/usr/bin/bzr log --long > Changes');
}

sub MY::postamble {
	"check : test\n\n";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Geo::BUFR::EC',
    VERSION_FROM      => 'lib/Geo/BUFR/EC.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Geo/BUFR/EC.pm', # retrieve abstract from module
       AUTHOR         => 'Christophe Beauregard <cpb@cpan.org>') : ()),
	 LIBS              => [ ExtUtils::PkgConfig->libs('libecbufr') ],
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => ExtUtils::PkgConfig->cflags('libecbufr'),
	 MAN3PODS          => {
	 		'EC.xs' => 'blib/man3/Geo::BUFR::EC.3',
	 },
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
