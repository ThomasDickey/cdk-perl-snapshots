use ExtUtils::MakeMaker;

#
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
#

#
# Variables you may need to set:
#
#	-DHAVE_COLOR		Set this if your curses has colour.
#	-DHAVE_NCURSES		Set this if you have ncurses installed.
#	-DHAVE_USLEEP		Set this if you have usleep.
#	-DCDK_PERL_EXT		Set this always. :)
#
WriteMakefile(
    'NAME'	=> 'Cdk',
    'VERSION'	=> '4.9.6',
    'LIBS'	=> ['-L/home/glover/local/lib -lcdk -lncurses'],
    'DEFINE'	=> '-DHAVE_USLEEP -DHAVE_NCURSES -DHAVE_COLOR -DCDK_PERL_EXT',
    'INC'	=> '-I/usr/include/ncurses -I/home/glover/local/include/cdk',
    'clean'	=> {FILES => 'Makefile.old'},
);

#
#If you want to get a hold of me mail me at one of the following:
#        glover@credit.erin.utoronto.ca
#        vexus@home.com
#
#The CDK Web page has several homes. They are:
#        http://members.home.net/vexus/CDK.html (official)
#        http://www.datasoft.on.ca/~cdk (Sponsered by the nice folks at Datasoft)
#
# ttfn,
#	Mike
#
