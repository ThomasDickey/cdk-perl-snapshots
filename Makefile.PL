#
# $Author: tom $
# $Date: 2001/01/08 00:03:21 $
# $Revision: 1.4 $
#
use ExtUtils::MakeMaker;

#
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
#

WriteMakefile(
    'NAME'	=> 'Cdk',
    'VERSION'	=> '4.9.10',
    'LIBS'	=> ['-L/usr/local/lib -lcdk -lncurses'],
    'DEFINE'	=> '-DCDK_PERL_EXT',
    'INC'	=> '-I/usr/include/ncurses -I/usr/local/include/cdk',
    'clean'	=> {FILES => 'Makefile.old'},
);

#
# If you want to talk to me mail me at one of the following:
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
