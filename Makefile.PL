#use 5.008002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Config::Magic',
    VERSION_FROM      => 'lib/Config/Magic.pm', # finds $VERSION
    PREREQ_PM         => {'Parse::RecDescent'=>'0','Tie::Hash::Indexed'=>'0'}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Config/Magic.pm', # retrieve abstract from module
       AUTHOR         => 'Rusty Phillips <rustyp@freeshell.org>') : ()),
);
