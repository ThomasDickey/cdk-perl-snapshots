#
# $Author: tom $
# $Date: 2002/07/28 19:09:50 $
# $Revision: 1.6 $
#
use ExtUtils::MakeMaker;

#
# See README and Perl's MakeMaker.pm for guidance in modifying the
# LIBS and INC strings.
#

WriteMakefile(
    'NAME'	=> 'Cdk',
    'VERSION'	=> '4.09010',
    'LIBS'	=> ['-L/usr/local/lib -lcdk -lcurses'],
    'INC'	=> '-I/usr/include/ncurses -I/usr/local/include/cdk',
    'clean'	=> {FILES => 'Makefile.old'},
);
