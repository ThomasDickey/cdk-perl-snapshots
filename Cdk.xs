/*
 * $Author: Niko.Tyni $
 * $Date: 2013/08/16 21:57:50 $
 * $Revision: 1.32 $
 */

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#define CDK_PERL_EXT
#ifdef HAVE_CDK_CDK_H
#include <cdk/cdk.h>
#else
#include <cdk.h>
#endif

#undef dNOOP
#define dNOOP /*EMPTY*/

/* Prior to perl5.005, the PL_ prefix wasn't used for things such
   as PL_rs.  Define the PL_ macros that we use if necessary. */

#include <patchlevel.h>		/* This is perl's patchlevel.h */

#if PATCHLEVEL < 5
#define PL_na na
#define PL_sv_undef sv_undef
#endif

static char * checkChtypeKey(chtype key);
static chtype sv2chtype(SV *sv);
static int sv2dtype(SV * sv);
static int sv2int(SV *sv);

CDKSCREEN *	GCDKSCREEN	= (CDKSCREEN *)NULL;
WINDOW *	GCWINDOW	= (WINDOW *)NULL;

/* this would be a function, except the menu widget relies on a fixed array */
#define MAKE_MENU_MATRIX(START,INPUT,NEWARRAY,ARRAYSIZE,ARRAYLEN)	\
	do {								\
	   AV *array	= (AV *)SvRV((INPUT));				\
	   int x, y;							\
									\
	   (ARRAYLEN)	= av_len (array);				\
									\
	   for (x = 0; x <= (ARRAYLEN); x++)				\
	   {								\
	      SV *name			= *av_fetch(array,x,FALSE);	\
	      AV *subArray		= (AV *)SvRV(name);		\
	      int subLen		= av_len (subArray);		\
	      (ARRAYSIZE)[x+(START)]	= subLen + 1;			\
									\
	      for (y=0; y <= subLen; y++)				\
	      {								\
		 SV *sv = *av_fetch(subArray,y,FALSE);			\
		 (NEWARRAY)[x+(START)][y+(START)] = copyChar((char *)SvPV(sv,PL_na));	\
	      }								\
	   }								\
	   (ARRAYLEN)++;						\
	} while (0)

static void make_int_array(int start, SV* input, int **dest, int *destlen)
{
   AV *src	= (AV *)SvRV(input);
   int length	= av_len(src) + 1;
   int x;

   if ((*dest = (int *)calloc((size_t) length + 2, sizeof(int *))) == 0)
   {
      croak("make_int_array(%d)", length + 2);
   }
   for (x=0; x < length; x++)
   {
      SV *foo	         = *av_fetch(src, x, FALSE);
      (*dest)[x + start] = sv2int (foo);
   }
   *destlen = length;
}
#define MAKE_INT_ARRAY(START, INPUT, DEST, LEN) \
	make_int_array(START, INPUT, &DEST, &LEN)

static void make_dtype_array(int start, SV *input, int **dest, int *destlen)
{
   AV *src	= (AV *)SvRV(input);
   int length	= av_len(src) + 1;
   int x;

   if ((*dest = (int *)calloc((size_t) length + 2, sizeof(int *))) == 0)
   {
      croak("make_dtype_array(%d)", length + 2);
   }
   for (x=0; x < length; x++)
   {
      SV *foo		 = *av_fetch(src, x, FALSE);
      (*dest)[x + start] = sv2dtype (foo);
   }
   *destlen = length;
}
#define MAKE_DTYPE_ARRAY(START, INPUT, DEST, LEN) \
	make_dtype_array(START, INPUT, &DEST, &LEN)

static void make_chtype_array(int start, SV *input, chtype **dest, int *destlen)
{
   AV *src	= (AV *)SvRV(input);
   int length	= av_len(src) + 1;
   int x;

   if ((*dest = (chtype *)calloc((size_t) length + 2, sizeof(chtype *))) == 0)
   {
      croak("make_chtype_array(%d)", length + 2);
   }
   for (x=0; x < length; x++)
   {
      SV *foo		 = *av_fetch(src, x, FALSE);
      (*dest)[x + start] = sv2chtype (foo);
   }
   *destlen = length;
}
#define MAKE_CHTYPE_ARRAY(START, INPUT, DEST, LEN) \
	make_chtype_array(START, INPUT, &DEST, &LEN)

static void make_char_array(int start, SV *input, char ***dest, int *destlen)
{
   AV *src	= (AV *)SvRV(input);
   int length	= av_len(src) + 1;
   int x;

   if ((*dest = (char **)calloc((size_t) length + 2, sizeof(char *))) == 0)
   {
      croak("make_char_array(%d)", length + 2);
   }
   for (x=0; x < length; x++)
   {
      SV *foo		 = *av_fetch(src, x, FALSE);
      (*dest)[x + start] = copyChar((char *)SvPV(foo,PL_na));
   }
   *destlen = length;
}
#define MAKE_CHAR_ARRAY(START, INPUT, DEST, LEN) \
	make_char_array(START, INPUT, &DEST, &LEN)

static void make_title(SV * input, char **dest)
{
   char *data;

   if (SvROK(input) && SvTYPE(SvRV(input)) == SVt_PVAV)
   {
      AV *src	= (AV *)SvRV(input);
      int len = av_len(src) + 1;
      int x;
      int length = 2;

      for (x=0; x < len; x++)
      {
	 SV *foo = *av_fetch(src, x, FALSE);
	 data = (char *)SvPV(foo,PL_na);
	 length += (int)strlen(data) + 1;
      }
      *dest = malloc((size_t)length);
      if (*dest == 0)
	 croak("make_title");

      **dest = '\0';
      for (x=0; x < len; x++)
      {
	 SV *foo = *av_fetch(src, x, FALSE);
	 data = (char *)SvPV(foo,PL_na);
	 if (x != 0)
	    strcat(*dest, "\n");
	 strcat(*dest, data);
      }
   }
   else
   {
      data = (char *)SvPV(input,PL_na);
      *dest = malloc(strlen(data) + 1);
      if (*dest == 0)
	 croak("make_title");
      strcpy (*dest, data);
   }
}
#define MAKE_TITLE(INPUT, DEST) \
	make_title(INPUT, &DEST)

/*
 * The callback callback to run Perl callback routines. Are you confused???
 */
static int PerlBindCB (EObjectType cdktype, void *object, void *data, chtype input)
{
   dSP ;

   SV *foo = (SV*)data;
   int returnValueCount;
   char *chtypeKey, temp[10];

   ENTER;
   SAVETMPS;
   PUSHMARK (sp);

   (void) cdktype;
   (void) object;

   /* Check which key input is... */
   chtypeKey = checkChtypeKey (input);
   if (chtypeKey == (char *)NULL)
   {
      sprintf (temp, "%c", (char)input);
      XPUSHs (sv_2mortal(newSVpv(temp, 1)));
   }
   else
   {
      XPUSHs (sv_2mortal(newSVpv(chtypeKey, strlen(chtypeKey))));
   }
   PUTBACK ;

   /* Call the perl subroutine. */
   returnValueCount = perl_call_sv (foo, G_SCALAR);

   SPAGAIN;

   /* Check the number of values returned from this function. */
   if (returnValueCount == 0)
   {
      /* They didn't return anything, let them continue. */
      PUTBACK;
      FREETMPS;
      LEAVE;
      return 1;
   }

   /* They returned something, lets find out what it is. */
   (void) POPi;

   PUTBACK;
   FREETMPS;
   LEAVE;
   return 1;
}

/*
 * The callback callback to run Perl callback routines. Are you confused???
 */
static int PerlProcessCB (EObjectType cdktype, void *object, void *data, chtype input)
{
   dSP ;

   SV *foo = (SV*)data;
   int returnValueCount, returnValue;
   char *chtypeKey, temp[10];

   ENTER;
   SAVETMPS;
   PUSHMARK (sp);

   (void) cdktype;
   (void) object;

   /* Check which key input is... */
   chtypeKey = checkChtypeKey (input);
   if (chtypeKey == (char *)NULL)
   {
      sprintf (temp, "%c", (char)input);
      XPUSHs (sv_2mortal(newSVpv(temp, 1)));
   }
   else
   {
      XPUSHs (sv_2mortal(newSVpv(chtypeKey, strlen(chtypeKey))));
   }
   PUTBACK ;

   /* Call the perl subroutine. */
   returnValueCount = perl_call_sv (foo, G_SCALAR);

   SPAGAIN;

   /* Check the number of values returned from this function. */
   if (returnValueCount == 0)
   {
      /* They didn't return anything, let them continue. */
      PUTBACK;
      FREETMPS;
      LEAVE;
      return 1;
   }

   /* They returned something, lets find out what it is. */
   returnValue = POPi;

   PUTBACK;
   FREETMPS;
   LEAVE;
   return returnValue;
}

static void checkCdkInit(void)
{
   if (GCDKSCREEN == (CDKSCREEN *)NULL)
   {
      croak ("Cdk has not been initialized.\n");
   }
}

static char *
checkChtypeKey(chtype key)
{
   char *result = 0;

   if (key == KEY_UP)
      result = "KEY_UP";
   else if (key == KEY_DOWN)
      result = "KEY_DOWN";
   else if (key == KEY_LEFT)
      result = "KEY_LEFT";
   else if (key == KEY_RIGHT)
      result = "KEY_RIGHT";
   else if (key == KEY_NPAGE)
      result = "KEY_NPAGE";
   else if (key == KEY_PPAGE)
      result = "KEY_PPAGE";
   else if (key == KEY_END)
      result = "KEY_END";
   else if (key == KEY_HOME)
      result = "KEY_HOME";
   else if (key == KEY_BACKSPACE)
      result = "KEY_BACKSPACE";
   else if (key == DELETE)
      result = "KEY_DELETE";
   else if (key == KEY_ESC)
      result = "KEY_ESC";

   return result;
}

static int
sv2integer(SV *sv, int invalid)
{
   char *from = SvPV(sv,PL_na);
   char mark;
   int result;

   if (sscanf(from, "%d%c", &result, &mark) != 1)
   {
      result = invalid;
   }
   return result;
}

static chtype
sv2chtype(SV *sv)
{
   bool found = FALSE;
   chtype result = 0;

   if (SvPOK(sv))
   {
      char *name = SvPV(sv,PL_na);
      chtype *fillerChtype;
      int c1, c2;

      found = TRUE;
      if (strEQ(name, "ACS_BTEE"))
	  result = ACS_BTEE;
      else if (strEQ(name, "ACS_HLINE"))
	  result = ACS_HLINE;
      else if (strEQ(name, "ACS_LLCORNER"))
	  result = ACS_LLCORNER;
      else if (strEQ(name, "ACS_LRCORNER"))
	  result = ACS_LRCORNER;
      else if (strEQ(name, "ACS_LTEE"))
	  result = ACS_LTEE;
      else if (strEQ(name, "ACS_PLUS"))
	  result = ACS_PLUS;
      else if (strEQ(name, "ACS_RTEE"))
	  result = ACS_RTEE;
      else if (strEQ(name, "ACS_TTEE"))
	  result = ACS_TTEE;
      else if (strEQ(name, "ACS_ULCORNER"))
	  result = ACS_ULCORNER;
      else if (strEQ(name, "ACS_URCORNER"))
	  result = ACS_URCORNER;
      else if (strEQ(name, "ACS_VLINE"))
	  result = ACS_VLINE;
      else if (strEQ(name, "A_ALTCHARSET"))
	  result = A_ALTCHARSET;
      else if (strEQ(name, "A_ATTRIBUTES"))
	  result = A_ATTRIBUTES;
      else if (strEQ(name, "A_BLINK"))
	  result = A_BLINK;
      else if (strEQ(name, "A_BOLD"))
	  result = A_BOLD;
      else if (strEQ(name, "A_CHARTEXT"))
	  result = A_CHARTEXT;
      else if (strEQ(name, "A_COLOR"))
	  result = A_COLOR;
      else if (strEQ(name, "A_DIM"))
	  result = A_DIM;
      else if (strEQ(name, "A_INVIS"))
	  result = A_INVIS;
      else if (strEQ(name, "A_NORMAL"))
	  result = A_NORMAL;
      else if (strEQ(name, "A_PROTECT"))
	  result = A_PROTECT;
      else if (strEQ(name, "A_REVERSE"))
	  result = A_REVERSE;
      else if (strEQ(name, "A_STANDOUT"))
	  result = A_STANDOUT;
      else if (strEQ(name, "A_UNDERLINE"))
	  result = A_UNDERLINE;
      else if (strEQ(name, "CDK_COPY"))
	  result = CDK_COPY;
      else if (strEQ(name, "CDK_CUT"))
	  result = CDK_CUT;
      else if (strEQ(name, "CDK_ERASE"))
	  result = CDK_ERASE;
      else if (strEQ(name, "CDK_PASTE"))
	  result = CDK_PASTE;
      else if (strEQ(name, "CDK_REFRESH"))
	  result = CDK_REFRESH;
#ifdef COLOR
      else if (strEQ(name, "COLOR_BLACK"))
	 result = COLOR_BLACK;
      else if (strEQ(name, "COLOR_BLUE"))
	 result = COLOR_BLUE;
      else if (strEQ(name, "COLOR_CYAN"))
	 result = COLOR_CYAN;
      else if (strEQ(name, "COLOR_GREEN"))
	 result = COLOR_GREEN;
      else if (strEQ(name, "COLOR_MAGENTA"))
	 result = COLOR_MAGENTA;
      else if (strEQ(name, "COLOR_RED"))
	 result = COLOR_RED;
      else if (strEQ(name, "COLOR_WHITE"))
	 result = COLOR_WHITE;
      else if (strEQ(name, "COLOR_YELLOW"))
	 result = COLOR_YELLOW;
#endif
      else if (strEQ(name, "DELETE"))
	  result = DELETE;
      else if (strEQ(name, "KEY_A1"))
	  result = KEY_A1;
      else if (strEQ(name, "KEY_A3"))
	  result = KEY_A3;
      else if (strEQ(name, "KEY_B2"))
	  result = KEY_B2;
      else if (strEQ(name, "KEY_BACKSPACE"))
	  result = KEY_BACKSPACE;
      else if (strEQ(name, "KEY_BEG"))
	  result = KEY_BEG;
      else if (strEQ(name, "KEY_BREAK"))
	  result = KEY_BREAK;
      else if (strEQ(name, "KEY_BTAB"))
	  result = KEY_BTAB;
      else if (strEQ(name, "KEY_C1"))
	  result = KEY_C1;
      else if (strEQ(name, "KEY_C3"))
	  result = KEY_C3;
      else if (strEQ(name, "KEY_CANCEL"))
	  result = KEY_CANCEL;
      else if (strEQ(name, "KEY_CATAB"))
	  result = KEY_CATAB;
      else if (strEQ(name, "KEY_CLEAR"))
	  result = KEY_CLEAR;
      else if (strEQ(name, "KEY_CLOSE"))
	  result = KEY_CLOSE;
      else if (strEQ(name, "KEY_COMMAND"))
	  result = KEY_COMMAND;
      else if (strEQ(name, "KEY_COPY"))
	  result = KEY_COPY;
      else if (strEQ(name, "KEY_CREATE"))
	  result = KEY_CREATE;
      else if (strEQ(name, "KEY_CTAB"))
	  result = KEY_CTAB;
      else if (strEQ(name, "KEY_DC"))
	  result = KEY_DC;
      else if (strEQ(name, "KEY_DL"))
	  result = KEY_DL;
      else if (strEQ(name, "KEY_DOWN"))
	  result = KEY_DOWN;
      else if (strEQ(name, "KEY_EIC"))
	  result = KEY_EIC;
      else if (strEQ(name, "KEY_END"))
	  result = KEY_END;
      else if (strEQ(name, "KEY_ENTER"))
	  result = KEY_ENTER;
      else if (strEQ(name, "KEY_EOL"))
	  result = KEY_EOL;
      else if (strEQ(name, "KEY_EOS"))
	  result = KEY_EOS;
      else if (strEQ(name, "KEY_ESC"))
	  result = KEY_ESC;
      else if (strEQ(name, "KEY_EXIT"))
	  result = KEY_EXIT;
      else if (strEQ(name, "KEY_F0"))
	  result = KEY_F0;
      else if (strEQ(name, "KEY_F1"))
	  result = KEY_F1;
      else if (strEQ(name, "KEY_F10"))
	  result = KEY_F10;
      else if (strEQ(name, "KEY_F11"))
	  result = KEY_F11;
      else if (strEQ(name, "KEY_F12"))
	  result = KEY_F12;
      else if (strEQ(name, "KEY_F2"))
	  result = KEY_F2;
      else if (strEQ(name, "KEY_F3"))
	  result = KEY_F3;
      else if (strEQ(name, "KEY_F4"))
	  result = KEY_F4;
      else if (strEQ(name, "KEY_F5"))
	  result = KEY_F5;
      else if (strEQ(name, "KEY_F6"))
	  result = KEY_F6;
      else if (strEQ(name, "KEY_F7"))
	  result = KEY_F7;
      else if (strEQ(name, "KEY_FIND"))
	  result = KEY_FIND;
      else if (strEQ(name, "KEY_HELP"))
	  result = KEY_HELP;
      else if (strEQ(name, "KEY_HOME"))
	  result = KEY_HOME;
      else if (strEQ(name, "KEY_IC"))
	  result = KEY_IC;
      else if (strEQ(name, "KEY_IL"))
	  result = KEY_IL;
      else if (strEQ(name, "KEY_LEFT"))
	  result = KEY_LEFT;
      else if (strEQ(name, "KEY_LL"))
	  result = KEY_LL;
      else if (strEQ(name, "KEY_MARK"))
	  result = KEY_MARK;
      else if (strEQ(name, "KEY_MAX"))
	  result = KEY_MAX;
      else if (strEQ(name, "KEY_MESSAGE"))
	  result = KEY_MESSAGE;
      else if (strEQ(name, "KEY_MIN"))
	  result = KEY_MIN;
      else if (strEQ(name, "KEY_MOVE"))
	  result = KEY_MOVE;
      else if (strEQ(name, "KEY_NPAGE"))
	  result = KEY_NPAGE;
      else if (strEQ(name, "KEY_OPEN"))
	  result = KEY_OPEN;
      else if (strEQ(name, "KEY_OPTIONS"))
	  result = KEY_OPTIONS;
      else if (strEQ(name, "KEY_PPAGE"))
	  result = KEY_PPAGE;
      else if (strEQ(name, "KEY_PREVIOUS"))
	  result = KEY_PREVIOUS;
      else if (strEQ(name, "KEY_PRINT"))
	  result = KEY_PRINT;
      else if (strEQ(name, "KEY_REDO"))
	  result = KEY_REDO;
      else if (strEQ(name, "KEY_REFERENCE"))
	  result = KEY_REFERENCE;
      else if (strEQ(name, "KEY_REFRESH"))
	  result = KEY_REFRESH;
      else if (strEQ(name, "KEY_REPLACE"))
	  result = KEY_REPLACE;
      else if (strEQ(name, "KEY_RESET"))
	  result = KEY_RESET;
      else if (strEQ(name, "KEY_RESTART"))
	  result = KEY_RESTART;
      else if (strEQ(name, "KEY_RESUME"))
	  result = KEY_RESUME;
      else if (strEQ(name, "KEY_RETURN"))
	  result = KEY_RETURN;
      else if (strEQ(name, "KEY_RIGHT"))
	  result = KEY_RIGHT;
      else if (strEQ(name, "KEY_SAVE"))
	  result = KEY_SAVE;
      else if (strEQ(name, "KEY_SBEG"))
	  result = KEY_SBEG;
      else if (strEQ(name, "KEY_SCANCEL"))
	  result = KEY_SCANCEL;
      else if (strEQ(name, "KEY_SCOMMAND"))
	  result = KEY_SCOMMAND;
      else if (strEQ(name, "KEY_SCOPY"))
	  result = KEY_SCOPY;
      else if (strEQ(name, "KEY_SCREATE"))
	  result = KEY_SCREATE;
      else if (strEQ(name, "KEY_SDC"))
	  result = KEY_SDC;
      else if (strEQ(name, "KEY_SDL"))
	  result = KEY_SDL;
      else if (strEQ(name, "KEY_SELECT"))
	  result = KEY_SELECT;
      else if (strEQ(name, "KEY_SEND"))
	  result = KEY_SEND;
      else if (strEQ(name, "KEY_SEOL"))
	  result = KEY_SEOL;
      else if (strEQ(name, "KEY_SEXIT"))
	  result = KEY_SEXIT;
      else if (strEQ(name, "KEY_SF"))
	  result = KEY_SF;
      else if (strEQ(name, "KEY_SFIND"))
	  result = KEY_SFIND;
      else if (strEQ(name, "KEY_SHELP"))
	  result = KEY_SHELP;
      else if (strEQ(name, "KEY_SHOME"))
	  result = KEY_SHOME;
      else if (strEQ(name, "KEY_SIC"))
	  result = KEY_SIC;
      else if (strEQ(name, "KEY_SLEFT"))
	  result = KEY_SLEFT;
      else if (strEQ(name, "KEY_SMESSAGE"))
	  result = KEY_SMESSAGE;
      else if (strEQ(name, "KEY_SMOVE"))
	  result = KEY_SMOVE;
      else if (strEQ(name, "KEY_SNEXT"))
	  result = KEY_SNEXT;
      else if (strEQ(name, "KEY_SOPTIONS"))
	  result = KEY_SOPTIONS;
      else if (strEQ(name, "KEY_SPREVIOUS"))
	  result = KEY_SPREVIOUS;
      else if (strEQ(name, "KEY_SPRINT"))
	  result = KEY_SPRINT;
      else if (strEQ(name, "KEY_SR"))
	  result = KEY_SR;
      else if (strEQ(name, "KEY_SREDO"))
	  result = KEY_SREDO;
      else if (strEQ(name, "KEY_SREPLACE"))
	  result = KEY_SREPLACE;
      else if (strEQ(name, "KEY_SRESET"))
	  result = KEY_SRESET;
      else if (strEQ(name, "KEY_SRIGHT"))
	  result = KEY_SRIGHT;
      else if (strEQ(name, "KEY_SRSUME"))
	  result = KEY_SRSUME;
      else if (strEQ(name, "KEY_SSAVE"))
	  result = KEY_SSAVE;
      else if (strEQ(name, "KEY_SSUSPEND"))
	  result = KEY_SSUSPEND;
      else if (strEQ(name, "KEY_STAB"))
	  result = KEY_STAB;
      else if (strEQ(name, "KEY_SUNDO"))
	  result = KEY_SUNDO;
      else if (strEQ(name, "KEY_SUSPEND"))
	  result = KEY_SUSPEND;
      else if (strEQ(name, "KEY_TAB"))
	  result = KEY_TAB;
      else if (strEQ(name, "KEY_UNDO"))
	  result = KEY_UNDO;
      else if (strEQ(name, "KEY_UP"))
	  result = KEY_UP;
      else if (strEQ(name, "SPACE"))
	 result = SPACE;
      else if (strEQ(name, "TAB"))
	 result = TAB;
      /* Else they used a format of </X> to specify a chtype. */
      else if ((fillerChtype = char2Chtype (name, &c1, &c2)) != 0) {
	  result = fillerChtype[0];
	  freeChtype (fillerChtype);
      }
      else
	 found = FALSE;
   }
   if (!found)
   {
      result = (chtype)sv2integer(sv, 0);
   }
   return result;
}

static int
sv2dtype(SV * sv)
{
   bool found = FALSE;
   int result = vINVALID;

   if (SvPOK(sv))
   {
      char *name = SvPV(sv,PL_na);

      found = TRUE;
      if (strEQ (name, "CHAR"))
	 result = vCHAR;
      else if (strEQ (name, "HCHAR"))
	 result = vHCHAR;
      else if (strEQ (name, "INT"))
	 result = vINT;
      else if (strEQ (name, "HINT"))
	 result = vHINT;
      else if (strEQ (name, "MIXED"))
	 result = vMIXED;
      else if (strEQ (name, "HMIXED"))
	 result = vHMIXED;
      else if (strEQ (name, "UCHAR"))
	 result = vUCHAR;
      else if (strEQ (name, "LCHAR"))
	 result = vLCHAR;
      else if (strEQ (name, "UHCHAR"))
	 result = vUHCHAR;
      else if (strEQ (name, "LHCHAR"))
	 result = vLHCHAR;
      else if (strEQ (name, "UMIXED"))
	 result = vUMIXED;
      else if (strEQ (name, "LMIXED"))
	 result = vLMIXED;
      else if (strEQ (name, "UHMIXED"))
	 result = vUHMIXED;
      else if (strEQ (name, "LHMIXED"))
	 result = vLHMIXED;
      else if (strEQ (name, "VIEWONLY"))
	 result = vVIEWONLY;
      else if (strEQ (name, "NONE"))
	 result = vNONE;
      else if (strEQ (name, "PERCENT"))
	 result = vPERCENT;
      else if (strEQ (name, "REAL"))
	 result = vREAL;
      else if (strEQ (name, "PLOT"))
	 result = vPLOT;
      else if (strEQ (name, "LINE"))
	 result = vLINE;
      else
	 found = FALSE;
   }
   if (!found)
   {
      result = sv2integer(sv, vINVALID);
   }
   return result;
}

static int
sv2int(SV *sv)
{
   bool found = FALSE;
   int result = 0;

   if (SvPOK(sv))
   {
      char *name = SvPV(sv,PL_na);

      found = TRUE;
      if (strEQ(name, "BOTTOM"))
	 result = BOTTOM;
      else if (strEQ(name, "CENTER"))
	 result = CENTER;
      else if (strEQ(name, "COL"))
	 result = COL;
      else if (strEQ(name, "FALSE"))
	 result = FALSE;
      else if (strEQ(name, "FULL"))
	 result = FULL;
      else if (strEQ(name, "HORIZONTAL"))
	 result = HORIZONTAL;
      else if (strEQ(name, "LEFT"))
	 result = LEFT;
      else if (strEQ(name, "NONE"))
	 result = NONE;
      else if (strEQ(name, "NONUMBERS"))
	 result = NONUMBERS;
      else if (strEQ(name, "NUMBERS"))
	 result = NUMBERS;
      else if (strEQ(name, "RIGHT"))
	 result = RIGHT;
      else if (strEQ(name, "ROW"))
	 result = ROW;
      else if (strEQ(name, "TRUE"))
	 result = TRUE;
      else if (strEQ(name, "TOP"))
	 result = TOP;
      else if (strEQ(name, "VERTICAL"))
	 result = VERTICAL;
      else
	 found = FALSE;
   }
   if (!found)
   {
      result = sv2integer(sv, 0);
   }
   return result;
}

#if 0
static char *
sv2CharPtr(SV *inp)
{
   char *name = (char *)SvPV(inp,PL_na);
   return (name);
}

static int
not_here(char *s)
{
    croak("%s not implemented on this architecture", s);
    return -1;
}
#endif

static double
constant(char *name, int arg)
{
    (void)arg;
    errno = 0;
    switch (*name) {
    case 'A':
	break;
    case 'B':
	break;
    case 'C':
	break;
    case 'D':
	break;
    case 'E':
	break;
    case 'F':
	break;
    case 'G':
	break;
    case 'H':
	break;
    case 'I':
	break;
    case 'J':
	break;
    case 'K':
	break;
    case 'L':
	break;
    case 'M':
	break;
    case 'N':
	break;
    case 'O':
	break;
    case 'P':
	break;
    case 'Q':
	break;
    case 'R':
	break;
    case 'S':
	break;
    case 'T':
	break;
    case 'U':
	break;
    case 'V':
	break;
    case 'W':
	break;
    case 'X':
	break;
    case 'Y':
	break;
    case 'Z':
	break;
    }
    errno = EINVAL;
    return 0;
#if 0
not_there:
    errno = ENOENT;
    return 0;
#endif
}

MODULE	= Cdk	PACKAGE = Cdk

const char *
getVersion()
	CODE:
	{
	    RETVAL = CDKVersion();
	}
	OUTPUT:
	    RETVAL

double
constant(name,arg)
	char *		name
	int		arg

void
Beep()
	CODE:
	{
	   Beep();
	}

CDKSCREEN *
init()
	CODE:
	{
	   GCWINDOW	= initscr();
	   GCDKSCREEN	= initCDKScreen (GCWINDOW);

	   /* Start the colors. */
	   initCDKColor();

	   RETVAL = GCDKSCREEN;
	}
	OUTPUT:
	   RETVAL

long
getColor(pair)
	int	pair
	CODE:
	{
	   (void) targ;
	   RETVAL = COLOR_PAIR(pair);
	}
	OUTPUT:
	   RETVAL

void
end()
	CODE:
	{
	   /* Kill the main screen. */
	   destroyCDKScreen (GCDKSCREEN);

	   /* Remove the curses window. */
	   delwin (GCWINDOW);

	   /* Shut down curses. */
	   endCDK();
	   kill (0, 2);
	}

CDKSCREEN *
getCdkScreen()
	CODE:
	{
	   RETVAL = GCDKSCREEN;
	}
	OUTPUT:
	   RETVAL

void
getCdkScreenDim()
	PPCODE:
	{
	   XPUSHs (sv_2mortal(newSViv(GCDKSCREEN->window->_maxy)));
	   XPUSHs (sv_2mortal(newSViv(GCDKSCREEN->window->_maxx)));
	}

WINDOW *
getCdkWindow()
	CODE:
	{
	   RETVAL = GCDKSCREEN->window;
	}
	OUTPUT:
	   RETVAL


void
refreshCdkScreen()
	CODE:
	{
	   refreshCDKScreen (GCDKSCREEN);
	}

void
eraseCdkScreen()
	CODE:
	{
	   eraseCDKScreen (GCDKSCREEN);
	}

void
destroyCdkScreen()
	CODE:
	{
	   destroyCDKScreen(GCDKSCREEN);
	}

void
DrawMesg(window,mesg,attrib=A_NORMAL,xpos=CENTER,ypos=CENTER,align=HORIZONTAL)
	WINDOW *	window
	char *		mesg
	chtype		attrib = sv2chtype ($arg);
	int		xpos = sv2int ($arg);
	int		ypos = sv2int ($arg);
	int		align = sv2int ($arg);
	CODE:
	{
	   int mesgLen = (int) strlen (mesg);

	   writeCharAttrib (window, xpos, ypos, mesg, attrib, align, 0, mesgLen);
	}

chtype
getch()

void
raw()

void
noraw()

PROTOTYPES: DISABLE

MODULE	= Cdk	PACKAGE = Cdk::Label

CDKLABEL *
New(mesg,xPos=CENTER,yPos=CENTER,Box=TRUE,shadow=FALSE)
	SV *	mesg
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKLABEL *	widget = (CDKLABEL *)NULL;
	   char **	message;
	   int		messageLines;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_CHAR_ARRAY (0, mesg, message, messageLines);

	   widget = newCDKLabel (GCDKSCREEN, xPos, yPos,
					message, messageLines,
					Box, shadow);
	   free (message);

	   /* Check the return value. */
	   if (widget == (CDKLABEL *)NULL)
	   {
	      croak ("Cdk::Label Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = widget;
	   }
	}
	OUTPUT:
	   RETVAL

void
SetMessage(object,mesg)
	CDKLABEL *	object
	SV *		mesg
	CODE:
	{
	   char **	message;
	   int		messageLines;

	   MAKE_CHAR_ARRAY (0, mesg, message, messageLines);
	   setCDKLabelMessage (object, message, messageLines);
	   free (message);
	}

void
SetBox(object,Box=TRUE)
	CDKLABEL *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKLabelBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKLABEL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKLabelULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKLABEL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKLabelURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKLABEL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKLabelLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKLABEL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKLabelLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKLABEL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKLabelVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKLABEL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKLabelHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKLABEL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKLabelBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKLABEL *	object
	char *		color
	CODE:
	{
	   setCDKLabelBackgroundColor (object,color);
	}

void
Draw(object,Box=TRUE)
	CDKLABEL *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKLabel (object, Box);
	}

void
Erase(object)
	CDKLABEL *	object
	CODE:
	{
	   eraseCDKLabel(object);
	}

char
Wait(object, key=0)
	CDKLABEL *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   RETVAL = waitCDKLabel (object, (char) key);
	}
	OUTPUT:
	   RETVAL

void
Register(object)
	CDKLABEL *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vLABEL, object);
	}

void
Unregister(object)
	CDKLABEL *	object
	CODE:
	{
	   unregisterCDKObject (vLABEL, object);
	}

void
Raise(object)
	CDKLABEL *	object
	CODE:
	{
	   raiseCDKObject (vLABEL, object);
	}

void
Lower(object)
	CDKLABEL *	object
	CODE:
	{
	   lowerCDKObject (vLABEL, object);
	}

WINDOW *
GetWindow(object)
	CDKLABEL *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Dialog

CDKDIALOG *
New(message,buttons,xPos=CENTER,yPos=CENTER,highlight=A_REVERSE,seperator=TRUE,Box=TRUE,shadow=FALSE)
	SV *	message
	SV *	buttons
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	chtype	highlight = sv2chtype ($arg);
	int	seperator = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKDIALOG *	dialogWidget = (CDKDIALOG *)NULL;
	   char **	Message;
	   char **	Buttons;
	   int		buttonCount;
	   int		rowCount;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_CHAR_ARRAY (0, message, Message, rowCount);
	   MAKE_CHAR_ARRAY (0, buttons, Buttons, buttonCount);

	   dialogWidget = newCDKDialog (GCDKSCREEN,xPos,yPos,
					Message,rowCount,
					Buttons,buttonCount,
					highlight,seperator,
					Box,shadow);
	   free (Message);
	   free (Buttons);

	   /* Check the return type. */
	   if (dialogWidget == (CDKDIALOG *)NULL)
	   {
	      croak ("Cdk::Dialog Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = dialogWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object,...)
	CDKDIALOG *	object
	CODE:
	{
	   chtype *	Keys;
	   int		arrayLen;
	   int		value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKDialog (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKDialog (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

int
Inject(object,key)
	CDKDIALOG *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKDialog (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKDIALOG *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vDIALOG, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKDIALOG *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKDialogPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKDIALOG *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKDialogPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKDIALOG *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKDialog (object,Box);
	}

void
Erase(object)
	CDKDIALOG *	object
	CODE:
	{
	   eraseCDKDialog (object);
	}

void
SetHighlight(object,highlight=A_REVERSE)
	CDKDIALOG *	object
	chtype		highlight = sv2chtype ($arg);
	CODE:
	{
	   setCDKDialogHighlight (object,highlight);
	}

void
SetSeparator(object,separator=TRUE)
	CDKDIALOG *	object
	int		separator
	CODE:
	{
	   setCDKDialogSeparator (object,separator);
	}

void
SetBox(object,Box=TRUE)
	CDKDIALOG *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKDialogBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKDIALOG *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKDialogULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKDIALOG *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKDialogURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKDIALOG *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKDialogLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKDIALOG *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKDialogLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKDIALOG *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKDialogVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKDIALOG *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKDialogHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKDIALOG *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKDialogBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKDIALOG *	object
	char *		color
	CODE:
	{
	   setCDKDialogBackgroundColor (object,color);
	}

void
Register(object)
	CDKDIALOG *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vDIALOG, object);
	}

void
Unregister(object)
	CDKDIALOG *	object
	CODE:
	{
	   unregisterCDKObject (vDIALOG, object);
	}

void
Raise(object)
	CDKDIALOG *	object
	CODE:
	{
	   raiseCDKObject (vDIALOG, object);
	}

void
Lower(object)
	CDKDIALOG *	object
	CODE:
	{
	   lowerCDKObject (vDIALOG, object);
	}

WINDOW *
GetWindow(object)
	CDKDIALOG *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Scroll

CDKSCROLL *
New (title,mesg,height,width,xPos=CENTER,yPos=CENTER,sPos=RIGHT,numbers=TRUE,highlight=A_REVERSE,Box=TRUE,shadow=FALSE)
	SV *	title
	SV *	mesg
	int	height
	int	width
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	sPos = sv2int ($arg);
	int	numbers	 = sv2int ($arg);
	chtype	highlight = sv2chtype ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKSCROLL *	scrollWidget = 0;
	   char **	Message;
	   char *	Title;
	   int		mesglen;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_CHAR_ARRAY(0, mesg, Message, mesglen);
	   MAKE_TITLE (title,Title);

	   scrollWidget = newCDKScroll (GCDKSCREEN, xPos, yPos, sPos,
					height, width,
					Title, Message, mesglen,
					numbers, highlight,
					Box, shadow);
	   free (Message);
	   free (Title);

	   /* Check the return type. */
	   if (scrollWidget == (CDKSCROLL *)NULL)
	   {
	      croak ("Cdk::Scroll Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = scrollWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object,...)
	CDKSCROLL *	object
	CODE:
	{
	   chtype *	Keys;
	   int		arrayLen;
	   int		value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKScroll (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKScroll (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

int
Inject(object,key)
	CDKSCROLL *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKScroll (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Add(object,line)
	CDKSCROLL *	object
	char *		line
	CODE:
	{
	   addCDKScrollItem (object,line);
	}

void
Delete(object,position)
	CDKSCROLL *	object
	int		position = sv2int ($arg);
	CODE:
	{
	   deleteCDKScrollItem (object,position);
	}

void
Bind(object,key,functionRef)
	CDKSCROLL *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vSCROLL, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKSCROLL *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKScrollPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKSCROLL *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKScrollPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKSCROLL *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKScroll (object,Box);
	}

void
Erase(object)
	CDKSCROLL *	object
	CODE:
	{
	   eraseCDKScroll(object);
	}

void
Info(object)
	CDKSCROLL *	object
	PPCODE:
	{
	   int currentItem = object->currentItem;
	   int size = object->listSize;

	   XPUSHs (sv_2mortal (newSViv(size)));
	   XPUSHs (sv_2mortal (newSViv(currentItem)));
	}

void
SetItems(object,cItems,numbers=FALSE)
	CDKSCROLL *	object
	SV *		cItems
	int		numbers = sv2int ($arg);
	CODE:
	{
	   char **	Items;
	   int		itemLength;

	   MAKE_CHAR_ARRAY(0, cItems, Items, itemLength);
	   setCDKScrollItems (object, Items, itemLength, numbers);
	   free (Items);
	}

void
SetHighlight(object,highlight)
	CDKSCROLL *	object
	chtype		highlight = sv2chtype ($arg);
	CODE:
	{
	   setCDKScrollHighlight (object,highlight);
	}

void
SetBox(object,Box=TRUE)
	CDKSCROLL *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKScrollBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKSCROLL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScrollULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKSCROLL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScrollURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKSCROLL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScrollLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKSCROLL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScrollLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKSCROLL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScrollVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKSCROLL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScrollHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKSCROLL *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScrollBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKSCROLL *	object
	char *		color
	CODE:
	{
	   setCDKScrollBackgroundColor (object,color);
	}

void
Register(object)
	CDKSCROLL *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vSCROLL, object);
	}

void
Unregister(object)
	CDKSCROLL *	object
	CODE:
	{
	   unregisterCDKObject (vSCROLL, object);
	}

void
Raise(object)
	CDKSCROLL *	object
	CODE:
	{
	   raiseCDKObject (vSCROLL, object);
	}

void
Lower(object)
	CDKSCROLL *	object
	CODE:
	{
	   lowerCDKObject (vSCROLL, object);
	}

WINDOW *
GetWindow(object)
	CDKSCROLL *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Scale

CDKSCALE *
New(title,label,start,low,high,inc,fastinc,fieldwidth,xPos=CENTER,yPos=CENTER,fieldattr=A_NORMAL,Box=TRUE,shadow=FALSE)
	SV *	title
	char *	label
	int	start
	int	low
	int	high
	int	inc
	int	fastinc
	int	fieldwidth
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	chtype	fieldattr = sv2chtype ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKSCALE *	scaleWidget = (CDKSCALE *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   scaleWidget = newCDKScale (GCDKSCREEN,xPos,yPos,
					Title,label,
					fieldattr,fieldwidth,
					start,low,high,inc,fastinc,
					Box,shadow);
	   free (Title);

	   /* Check the return type. */
	   if (scaleWidget == (CDKSCALE *)NULL)
	   {
	      croak ("Cdk::Scale Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = scaleWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object,...)
	CDKSCALE *	object
	CODE:
	{
	   chtype *	Keys;
	   int		arrayLen;
	   int		value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKScale (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKScale (object, NULL);
	   }

	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

int
Inject(object,key)
	CDKSCALE *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int value = injectCDKScale (object,key);
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKSCALE *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vSCALE, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKSCALE *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKScalePreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKSCALE *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKScalePostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKSCALE *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKScale (object,Box);
	}

void
Erase(object)
	CDKSCALE *	object
	CODE:
	{
	   eraseCDKScale(object);
	}

void
SetValue(object,value)
	CDKSCALE *	object
	int		value
	CODE:
	{
	   setCDKScaleValue (object,value);
	}

void
SetLowHigh(object,low,high)
	CDKSCALE *	object
	int		low
	int		high
	CODE:
	{
	   setCDKScaleLowHigh (object,low,high);
	}

void
SetBox(object,Box=TRUE)
	CDKSCALE *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKScaleBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKSCALE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScaleULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKSCALE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScaleURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKSCALE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScaleLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKSCALE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScaleLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKSCALE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScaleVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKSCALE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScaleHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKSCALE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKScaleBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKSCALE *	object
	char *		color
	CODE:
	{
	   setCDKScaleBackgroundColor (object,color);
	}

void
Register(object)
	CDKSCALE *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vSCALE, object);
	}

void
Unregister(object)
	CDKSCALE *	object
	CODE:
	{
	   unregisterCDKObject (vSCALE, object);
	}

void
Raise(object)
	CDKSCALE *	object
	CODE:
	{
	   raiseCDKObject (vSCALE, object);
	}

void
Lower(object)
	CDKSCALE *	object
	CODE:
	{
	   lowerCDKObject (vSCALE, object);
	}

WINDOW *
GetWindow(object)
	CDKSCALE *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Histogram

CDKHISTOGRAM *
New(title,height,width,orient=HORIZONTAL,xPos=CENTER,yPos=CENTER,Box=TRUE,shadow=FALSE)
	SV *	title
	int	height
	int	width
	int	orient = sv2int ($arg);
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKHISTOGRAM * histWidget = (CDKHISTOGRAM *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   histWidget = newCDKHistogram (GCDKSCREEN,xPos,yPos,height,width,orient,Title,Box,shadow);

	   free (Title);

	   /* Check the return type. */
	   if (histWidget == (CDKHISTOGRAM *)NULL)
	   {
	      croak ("Cdk::Histogram Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = histWidget;
	   }
	}
	OUTPUT:
	   RETVAL

void
SetDisplayType(object,value="vPERCENT")
	CDKHISTOGRAM *		object
	char *			value
	CODE:
	{
	   EHistogramDisplayType displayType = vPERCENT;

	   /* Set the stats type.		*/
	   if (strEQ (value, "PERCENT"))
	      displayType = vPERCENT;
	   if (strEQ (value, "FRACTION"))
	      displayType = vFRACTION;
	   if (strEQ (value, "REAL"))
	      displayType = vREAL;
	   if (strEQ (value, "NONE"))
	      displayType = vNONE;

	   setCDKHistogramDisplayType (object,displayType);
	}

void
SetValue(object,value,low,high)
	CDKHISTOGRAM *	object
	int		value
	int		low
	int		high
	CODE:
	{
	   setCDKHistogramValue (object,value,low,high);
	}

void
SetFillerChar(object,value)
	CDKHISTOGRAM *	object
	chtype		value = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramFillerChar (object,value);
	}

void
SetStatsPos(object,value)
	CDKHISTOGRAM *	object
	int		value = sv2int ($arg);
	CODE:
	{
	   setCDKHistogramStatsPos (object,value);
	}

void
SetStatsAttr(object,value)
	CDKHISTOGRAM *	object
	chtype		value = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramStatsAttr (object,value);
	}

void
SetBox(object,Box=TRUE)
	CDKHISTOGRAM *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKHistogramBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKHISTOGRAM *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKHISTOGRAM *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKHISTOGRAM *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKHISTOGRAM *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKHISTOGRAM *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKHISTOGRAM *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKHISTOGRAM *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKHistogramBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKHISTOGRAM *	object
	char *		color
	CODE:
	{
	   setCDKHistogramBackgroundColor (object,color);
	}

void
Draw(object,Box=TRUE)
	CDKHISTOGRAM *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKHistogram (object,Box);
	}

void
Erase(object)
	CDKHISTOGRAM *	object
	CODE:
	{
	   eraseCDKHistogram (object);
	}

void
Register(object)
	CDKHISTOGRAM *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vHISTOGRAM, object);
	}

void
Unregister(object)
	CDKHISTOGRAM *	object
	CODE:
	{
	   unregisterCDKObject (vHISTOGRAM, object);
	}

void
Raise(object)
	CDKHISTOGRAM *	object
	CODE:
	{
	   raiseCDKObject (vHISTOGRAM, object);
	}

void
Lower(object)
	CDKHISTOGRAM *	object
	CODE:
	{
	   lowerCDKObject (vHISTOGRAM, object);
	}

WINDOW *
GetWindow(object)
	CDKHISTOGRAM *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Menu

CDKMENU *
New(menulist, menuloc, titleattr=A_REVERSE, subtitleattr=A_REVERSE, menuPos=TOP)
	SV *	menulist
	SV *	menuloc
	chtype	titleattr = sv2chtype ($arg);
	chtype	subtitleattr = sv2chtype ($arg);
	int	menuPos = sv2int ($arg);
	CODE:
	{
	   const char *	menuList[MAX_MENU_ITEMS][MAX_SUB_ITEMS];
	   int		subSize[MAX_SUB_ITEMS];
	   int *	menuLoc;
	   int		menulen;
	   int		loclen;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_MENU_MATRIX(0, menulist, menuList, subSize, menulen);

	   MAKE_INT_ARRAY (0, menuloc, menuLoc, loclen);
	   if (menulen != loclen)
	   {
	      croak ("Cdk::Menu The menu list and menu location arrays are not the same size.");
	   }
	   RETVAL = newCDKMenu (GCDKSCREEN,
				menuList,
				menulen,
				subSize,
				menuLoc,
				menuPos,
				titleattr,
				subtitleattr);

	   free (menuLoc);
	}
	OUTPUT:
	   RETVAL

int
Activate(object,...)
	CDKMENU *	object
	CODE:
	{
	   chtype *	Keys;
	   int		arrayLen;
	   int		value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKMenu (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKMenu (object, (void *)0);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

int
Inject(object,key)
	CDKMENU *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKMenu (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKMENU *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vMENU, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKMENU *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKMenuPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKMENU *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKMenuPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object, Box)
	CDKMENU *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKMenu (object, Box);
	}

void
Erase(object)
	CDKMENU *	object
	CODE:
	{
	   eraseCDKMenu (object);
	}

void
SetCurrentItem(object,menuitem,submenuitem)
	CDKMENU *	object
	int		menuitem
	int		submenuitem
	CODE:
	{
	   setCDKMenuCurrentItem(object,menuitem,submenuitem);
	}

void
SetTitleHighlight(object,value)
	CDKMENU *	object
	chtype		value
	CODE:
	{
	   setCDKMenuTitleHighlight (object,value);
	}

void
SetSubTitleHighlight(object,value)
	CDKMENU *	object
	chtype		value
	CODE:
	{
	   setCDKMenuSubTitleHighlight (object,value);
	}

void
SetBackgroundColor(object,value)
	CDKMENU *	object
	char *		value
	CODE:
	{
	   setCDKMenuBackgroundColor (object,value);
	}

void
Register(object)
	CDKMENU *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vMENU, object);
	}

void
Unregister(object)
	CDKMENU *	object
	CODE:
	{
	   unregisterCDKObject (vMENU, object);
	}

void
Raise(object)
	CDKMENU *	object
	CODE:
	{
	   raiseCDKObject (vMENU, object);
	}

void
Lower(object)
	CDKMENU *	object
	CODE:
	{
	   lowerCDKObject (vMENU, object);
	}

MODULE	= Cdk	PACKAGE = Cdk::Entry

CDKENTRY *
New(title,label,min,max,fieldWidth,filler=".",disptype=vMIXED,xPos=CENTER,yPos=CENTER,fieldattr=A_NORMAL,Box=TRUE,shadow=FALSE)
	SV *		title
	char *		label
	int		min
	int		max
	int		fieldWidth
	chtype		filler = sv2chtype ($arg);
	int		disptype = sv2dtype ($arg);
	int		xPos = sv2int ($arg);
	int		yPos = sv2int ($arg);
	chtype		fieldattr = sv2chtype ($arg);
	int		Box = sv2int ($arg);
	int		shadow = sv2int ($arg);
	CODE:
	{
	   CDKENTRY *	entryWidget = (CDKENTRY *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   entryWidget = newCDKEntry (GCDKSCREEN,xPos,yPos,
					Title,label,
					fieldattr,filler,(EDisplayType) disptype,
					fieldWidth,min,max,
					Box,shadow);
	   free (Title);

	   /* Check the return type. */
	   if (entryWidget == (CDKENTRY *)NULL)
	   {
	      croak ("Cdk::Entry Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = entryWidget;
	   }
	}
	OUTPUT:
	   RETVAL

char *
Activate(object,...)
	CDKENTRY *	object
	CODE:
	{
	   chtype *	Keys;
	   int		arrayLen;
	   char *	value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKEntry (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKEntry (object, NULL);
	   }

	   if (object->exitType != vNORMAL)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

char *
Inject(object,key)
	CDKENTRY *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   char *value = injectCDKEntry (object,key);
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKENTRY *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv(functionRef);
	   bindCDKObject (vENTRY, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKENTRY *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKEntryPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKENTRY *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKEntryPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKENTRY *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKEntry (object, Box);
	}

void
Erase(object)
	CDKENTRY *	object
	CODE:
	{
	   eraseCDKEntry (object);
	}

void
SetValue(object,value)
	CDKENTRY *	object
	char *		value
	CODE:
	{
	   setCDKEntryValue (object, value);
	}

void
SetMin(object,value)
	CDKENTRY *	object
	int		value
	CODE:
	{
	   setCDKEntryMin (object, value);
	}

void
SetMax(object,value)
	CDKENTRY *	object
	int		value
	CODE:
	{
	   setCDKEntryMax (object, value);
	}

void
SetFillerChar(object,value)
	CDKENTRY *	object
	chtype		value = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryFillerChar (object, value);
	}

void
SetHiddenChar(object,value)
	CDKENTRY *	object
	chtype		value = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryHiddenChar (object, value);
	}

void
SetBox(object,Box=TRUE)
	CDKENTRY *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKEntryBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKEntryBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKENTRY *	object
	char *		color
	CODE:
	{
	   setCDKEntryBackgroundColor (object,color);
	}

char *
Get(object)
	CDKENTRY *	object
	CODE:
	{
	   RETVAL = getCDKEntryValue (object);
	}
	OUTPUT:
	   RETVAL

void
Clean(object)
	CDKENTRY *	object
	CODE:
	{
	   cleanCDKEntry (object);
	}

void
Register(object)
	CDKENTRY *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vENTRY, object);
	}

void
Unregister(object)
	CDKENTRY *	object
	CODE:
	{
	   unregisterCDKObject (vENTRY, object);
	}

void
Raise(object)
	CDKENTRY *	object
	CODE:
	{
	   raiseCDKObject (vENTRY, object);
	}

void
Lower(object)
	CDKENTRY *	object
	CODE:
	{
	   lowerCDKObject (vENTRY, object);
	}

WINDOW *
GetWindow(object)
	CDKENTRY *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Mentry

CDKMENTRY *
New(title,label,min,physical,logical,fieldWidth,disptype=vMIXED,filler=".",xPos=CENTER,yPos=CENTER,fieldattr=A_NORMAL,Box=TRUE,shadow=FALSE)
	SV *		title
	char *		label
	int		min
	int		physical
	int		logical
	int		fieldWidth
	int		disptype = sv2dtype ($arg);
	chtype		filler = sv2chtype ($arg);
	int		xPos = sv2int ($arg);
	int		yPos = sv2int ($arg);
	chtype		fieldattr = sv2chtype ($arg);
	int		Box = sv2int ($arg);
	int		shadow = sv2int ($arg);
	CODE:
	{
	   CDKMENTRY *	mentryWidget = (CDKMENTRY *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   mentryWidget = newCDKMentry (GCDKSCREEN,xPos,yPos,
					Title,label,
					fieldattr,filler,
					(EDisplayType) disptype,fieldWidth,
					physical,logical,min,
					Box,shadow);
	   free (Title);

	   /* Check the return type. */
	   if (mentryWidget == (CDKMENTRY *)NULL)
	   {
	      croak ("Cdk::Mentry Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = mentryWidget;
	   }
	}
	OUTPUT:
	   RETVAL

char *
Activate(object,...)
	CDKMENTRY *	object
	CODE:
	{
	   chtype *	Keys;
	   int		arrayLen;
	   char *	value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKMentry (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKMentry (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

char *
Inject(object,key)
	CDKMENTRY *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   char *value = injectCDKMentry (object,key);
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKMENTRY *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vMENTRY, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKMENTRY *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKMentryPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKMENTRY *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKMentryPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKMENTRY *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKMentry (object,Box);
	}

void
Erase(object)
	CDKMENTRY *	object
	CODE:
	{
	   eraseCDKMentry (object);
	}

void
SetValue(object,value)
	CDKMENTRY *	object
	char *		value
	CODE:
	{
	   setCDKMentryValue (object,value);
	}

void
SetMin(object,value)
	CDKMENTRY *	object
	int		value
	CODE:
	{
	   int min = value;

	   if (value < 0)
	   {
	      min = object->min;
	   }

	   setCDKMentryMin (object,min);
	}

void
SetFillerChar(object,value)
	CDKMENTRY *	object
	chtype		value = sv2chtype ($arg);
	CODE:
	{
	   setCDKMentryFillerChar (object,value);
	}

void
SetBox(object,Box=TRUE)
	CDKMENTRY *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKMentryBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKMENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMentryULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKMENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMentryURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKMENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMentryLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKMENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMentryLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKMENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMentryVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKMENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMentryHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKMENTRY *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMentryBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKMENTRY *	object
	char *		color
	CODE:
	{
	   setCDKMentryBackgroundColor (object,color);
	}

char *
Get(object)
	CDKMENTRY *	object
	CODE:
	{
	   RETVAL = object->info;
	}
	OUTPUT:
	   RETVAL

void
Clean(object)
	CDKMENTRY *	object
	CODE:
	{
	   cleanCDKMentry (object);
	}

void
Register(object)
	CDKMENTRY *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vMENTRY, object);
	}

void
Unregister(object)
	CDKMENTRY *	object
	CODE:
	{
	   unregisterCDKObject (vMENTRY, object);
	}

void
Raise(object)
	CDKMENTRY *	object
	CODE:
	{
	   raiseCDKObject (vMENTRY, object);
	}

void
Lower(object)
	CDKMENTRY *	object
	CODE:
	{
	   lowerCDKObject (vMENTRY, object);
	}

WINDOW *
GetWindow(object)
	CDKMENTRY *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Matrix

CDKMATRIX *
New(title,rowtitles,coltitles,colwidths,coltypes,vrows,vcols,xPos=CENTER,yPos=CENTER,rowspace=1,colspace=1,filler=".",dominant=NONE,boxMatrix=FALSE,boxCell=TRUE,shadow=FALSE)
	SV *	title
	SV *	rowtitles
	SV *	coltitles
	SV *	colwidths
	SV *	coltypes
	int	vrows
	int	vcols
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	rowspace
	int	colspace
	chtype	filler = sv2chtype ($arg);
	int	dominant = sv2int ($arg);
	int	boxMatrix = sv2int ($arg);
	int	boxCell = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKMATRIX * matrixWidget = (CDKMATRIX *)NULL;
	   char **	colTitles;
	   char **	rowTitles;
	   char *	Title;
	   int *	colWidths;
	   int *	colTypes;
	   int	rows, cols, widths, dtype;

	   checkCdkInit();
	   RETVAL = 0;

	   /* Make the arrays. */
	   MAKE_CHAR_ARRAY (1, rowtitles, rowTitles, rows);
	   MAKE_CHAR_ARRAY (1, coltitles, colTitles, cols);
	   MAKE_INT_ARRAY (1, colwidths, colWidths, widths);
	   MAKE_DTYPE_ARRAY (1, coltypes, colTypes, dtype);
	   MAKE_TITLE (title,Title);

	   /* Now check them... */
	   if (cols != widths)
	   {
	      croak ("Cdk::Matrix The col title array size is not the same as the widths array size.");
	   }
	   if (cols != dtype)
	   {
	      croak ("Cdk::Matrix The col title array size is not the same as the column value array size.");
	   }
	   if (vrows > rows || vcols > cols)
	   {
	      croak ("Cdk::Matrix The virtual matrix size is larger then the physical size.");
	   }

	   /* OK, everything is ok. Lets make the matrix. */
	   matrixWidget = newCDKMatrix (GCDKSCREEN,
					xPos, yPos,
					rows, cols,
					vrows, vcols,
					Title, rowTitles,
					colTitles,
					colWidths, colTypes,
					rowspace, colspace, filler,
					dominant,
					boxMatrix, boxCell, shadow);

	   /* Check the return type. */
	   if (matrixWidget == (CDKMATRIX *)NULL)
	   {
	      croak ("Cdk::Matrix Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = matrixWidget;
	   }
	   free (colTitles);
	   free (rowTitles);
	   free (colWidths);
	   free (colTypes);
	   free (Title);
	}
	OUTPUT:
	   RETVAL

void
Activate(object,...)
	CDKMATRIX *	object
	PPCODE:
	{
	   AV *		cellInfo = newAV();
	   chtype *	Keys;
	   int x, y, arrayLen;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      (void) activateCDKMatrix (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      (void) activateCDKMatrix (object, NULL);
	   }

	   /* Check the exit status.	*/
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }

	   /* Take the info from the matrix and make an array out of it. */
	   for (x=1; x <= object->rows; x++)
	   {
	      AV * av	= newAV();

	      for (y=1; y <= object->cols; y++)
	      {
		 char *data = object->info[CELL_INDEX(object,x,y)];
		 av_push (av, newSVpv (data, strlen (data)));
	      }

	      av_push (cellInfo, newRV((SV *)av));
	   }

	   /* Push the values on the return stack.	*/
	   XPUSHs (sv_2mortal(newSViv(object->rows)));
	   XPUSHs (sv_2mortal(newSViv(object->cols)));
	   XPUSHs (sv_2mortal(newRV((SV*)cellInfo)));
	}

int
Inject(object,key)
	CDKMATRIX *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKMatrix (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKMATRIX *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vMATRIX, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKMATRIX *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKMatrixPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKMATRIX *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKMatrixPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
GetDim(object)
	CDKMATRIX *	object
	PPCODE:
	{
	   XPUSHs (sv_2mortal(newSViv(object->rows)));
	   XPUSHs (sv_2mortal(newSViv(object->cols)));
	}

void
Draw(object,Box=TRUE)
	CDKMATRIX *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKMatrix (object,Box);
	}

void
Erase(object)
	CDKMATRIX *	object
	CODE:
	{
	   eraseCDKMatrix (object);
	}

void
Set(object,info)
	CDKMATRIX *	object
	SV *		info
	CODE:
	{
	   char **	Info;
	   int *	subSize;
	   int		matrixlen;
	   int		width = 1;

	   AV *array	= (AV *)SvRV(info);
	   int x, y;

	   matrixlen	= av_len (array) + 1;
	   subSize	= (int *)calloc((size_t)matrixlen + 2, sizeof(int));

	   if (subSize != 0)
	   {
	      for (x = 1; x <= matrixlen; x++)
	      {
		 SV *name		= *av_fetch(array, x - 1, FALSE);
		 AV *subArray	= (AV *)SvRV(name);
		 int subLen	= av_len (subArray) + 1;
		 width = MAXIMUM(width, subLen);
	      }
	      Info = (char **)calloc((size_t)((width + 1) * (matrixlen + 1)), sizeof(char *));

	      if (Info != 0)
	      {
		 for (x = 1; x <= matrixlen; x++)
		 {
		    SV *name		= *av_fetch(array, x - 1, FALSE);
		    AV *subArray	= (AV *)SvRV(name);
		    int subLen	= av_len (subArray) + 1;
		    subSize[x]	= subLen;

		    for (y=1; y <= subLen; y++)
		    {
		       SV *sv = *av_fetch(subArray, y - 1, FALSE);
		       Info[x * (matrixlen + 1) + y] = copyChar((char *)SvPV(sv,PL_na));
		    }
		 }

		 setCDKMatrixCells (object, Info, matrixlen, width, subSize);

		 free (Info);
	      }
	      free (subSize);
	   }
	}

void
SetCell(object,row,col,value)
	CDKMATRIX *	object
	int		row
	int		col
	char *		value
	CODE:
	{
	   setCDKMatrixCell (object,row,col,value);
	}

char *
GetCell(object,row,col)
	CDKMATRIX *	object
	int		row
	int		col
	CODE:
	{
	   RETVAL = getCDKMatrixCell (object,row,col);
	}
	OUTPUT:
	   RETVAL

int
GetRow(object)
	CDKMATRIX *	object
	CODE:
	{
	   RETVAL = getCDKMatrixRow (object);
	}
	OUTPUT:
	   RETVAL

int
GetCol(object)
	CDKMATRIX *	object
	CODE:
	{
	   RETVAL = getCDKMatrixCol (object);
	}
	OUTPUT:
	   RETVAL

void
SetBoxAttribute(object,Box=TRUE)
	CDKMATRIX *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKMatrixBoxAttribute (object, (chtype)Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKMATRIX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMatrixULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKMATRIX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMatrixURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKMATRIX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMatrixLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKMATRIX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMatrixLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKMATRIX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMatrixVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKMATRIX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMatrixHorizontalChar (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKMATRIX *	object
	char *		color
	CODE:
	{
	   setCDKMatrixBackgroundColor (object,color);
	}

void
Clean(object)
	CDKMATRIX *	object
	CODE:
	{
	   cleanCDKMatrix (object);
	}

void
Raise(object)
	CDKMATRIX *	object
	CODE:
	{
	   raiseCDKObject (vMATRIX, object);
	}

void
Lower(object)
	CDKMATRIX *	object
	CODE:
	{
	   lowerCDKObject (vMATRIX, object);
	}

WINDOW *
GetWindow(object)
	CDKMATRIX *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

void
Register(object)
	CDKMATRIX *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vMATRIX, object);
	}

void
Unregister(object)
	CDKMATRIX *	object
	CODE:
	{
	   unregisterCDKObject (vMATRIX, object);
	}

MODULE	= Cdk	PACKAGE = Cdk::Marquee

CDKMARQUEE *
New(width,xPos=CENTER,yPos=CENTER,Box=TRUE,shadow=FALSE)
	int	width
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKMARQUEE * marqueeWidget = (CDKMARQUEE *)NULL;

	   checkCdkInit();
	   RETVAL = 0;

	   marqueeWidget = newCDKMarquee (GCDKSCREEN,xPos,yPos,width,Box,shadow);

	   /* Check the return type. */
	   if (marqueeWidget == (CDKMARQUEE *)NULL)
	   {
	      croak ("Cdk::Marquee Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = marqueeWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object,message,delay,repeat,Box=TRUE)
	CDKMARQUEE *	object
	char *		message
	int		delay
	int		repeat
	int		Box = sv2int ($arg);
	CODE:
	{
	   RETVAL = activateCDKMarquee (object,message,delay,repeat,Box);
	}
	OUTPUT:
	   RETVAL

void
Deactivate(object)
	CDKMARQUEE *	object
	CODE:
	{
	   deactivateCDKMarquee (object);
	}

void
SetBoxAttribute(object,Box=TRUE)
	CDKMARQUEE *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKMarqueeBoxAttribute (object, (chtype)Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKMARQUEE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMarqueeULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKMARQUEE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMarqueeURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKMARQUEE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMarqueeLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKMARQUEE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMarqueeLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKMARQUEE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMarqueeVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKMARQUEE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKMarqueeHorizontalChar (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKMARQUEE *	object
	char *		color
	CODE:
	{
	   setCDKMarqueeBackgroundColor (object,color);
	}

void
Bind(object,key,functionRef)
	CDKMARQUEE *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vMARQUEE, object, key, PerlBindCB, function);
	}

void
Draw(object,Box=TRUE)
	CDKMARQUEE *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKMarquee (object,Box);
	}

void
Erase(object)
	CDKMARQUEE *	object
	CODE:
	{
	   eraseCDKMarquee (object);
	}

void
Register(object)
	CDKMARQUEE *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vMARQUEE, object);
	}

void
Unregister(object)
	CDKMARQUEE *	object
	CODE:
	{
	   unregisterCDKObject (vMARQUEE, object);
	}

void
Raise(object)
	CDKMARQUEE *	object
	CODE:
	{
	   raiseCDKObject (vMARQUEE, object);
	}

void
Lower(object)
	CDKMARQUEE *	object
	CODE:
	{
	   lowerCDKObject (vMARQUEE, object);
	}

WINDOW *
GetWindow(object)
	CDKMARQUEE *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Selection

CDKSELECTION *
New(title,list,choices,height,width,xPos=CENTER,yPos=CENTER,sPos=RIGHT,highlight=A_REVERSE,Box=TRUE,shadow=FALSE)
	SV *	title
	SV *	list
	SV *	choices
	int	height
	int	width
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	sPos = sv2int ($arg);
	chtype	highlight = sv2chtype ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKSELECTION * selectionWidget = (CDKSELECTION *)NULL;
	   char **	List;
	   char **	Choices;
	   char *	Title;
	   int listSize, choiceSize;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_CHAR_ARRAY(0, list, List, listSize);
	   MAKE_CHAR_ARRAY(0, choices, Choices, choiceSize);
	   MAKE_TITLE (title,Title);

	   selectionWidget = newCDKSelection (GCDKSCREEN, xPos, yPos, sPos,
						height, width,
						Title, List, listSize,
						Choices, choiceSize,
						highlight, Box, shadow);
	   free (List);
	   free (Choices);
	   free (Title);

	   /* Check the return type. */
	   if (selectionWidget == (CDKSELECTION *)NULL)
	   {
	      croak ("Cdk::Selection Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = selectionWidget;
	   }
	}
	OUTPUT:
	   RETVAL

void
Activate(object,...)
	CDKSELECTION *	object
	PPCODE:
	{
	   chtype *	Keys;
	   int arrayLen;
	   int x;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      (void) activateCDKSelection (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      (void) activateCDKSelection (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }

	   /* Push the values on the return stack.	*/
	   for (x=0; x < object->listSize ; x++)
	   {
	      XPUSHs (sv_2mortal(newSViv(object->selections[x])));
	   }
	}

int
Inject(object,key)
	CDKSELECTION *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKSelection (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKSELECTION *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vSELECTION, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKSELECTION *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKSelectionPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKSELECTION *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKSelectionPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKSELECTION *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKSelection (object,Box);
	}

void
Erase(object)
	CDKSELECTION *	object
	CODE:
	{
	   eraseCDKSelection (object);
	}

void
SetHighlight(object,highlight)
	CDKSELECTION *	object
	chtype		highlight = sv2chtype ($arg);
	CODE:
	{
	   setCDKSelectionHighlight (object,highlight);
	}

void
SetChoices(object,choices)
	CDKSELECTION *	object
	SV *		choices
	CODE:
	{
	   int *	defaultChoices;
	   int		choiceLength;

	   MAKE_INT_ARRAY (0, choices, defaultChoices, choiceLength);
	   setCDKSelectionChoices (object,defaultChoices);
	   free (defaultChoices);
	}

void
SetChoice(object,choice,cIndex)
	CDKSELECTION *	object
	int		choice
	int		cIndex
	CODE:
	{
	   setCDKSelectionChoice (object,cIndex,choice);
	}

void
SetModes(object,modes)
	CDKSELECTION *	object
	SV *		modes
	CODE:
	{
	   int *	Modes;
	   int		modeLength;

	   MAKE_INT_ARRAY (0, modes, Modes, modeLength);
	   setCDKSelectionModes (object,Modes);
	   free (Modes);
	}

void
SetMode(object,mode,cIndex)
	CDKSELECTION *	object
	int		mode
	int		cIndex
	CODE:
	{
	   setCDKSelectionMode (object,cIndex,mode);
	}

void
SetBox(object,Box=TRUE)
	CDKSELECTION *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKSelectionBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKSELECTION *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSelectionULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKSELECTION *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSelectionURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKSELECTION *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSelectionLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKSELECTION *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSelectionLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKSELECTION *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSelectionVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKSELECTION *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSelectionHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKSELECTION *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSelectionBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKSELECTION *	object
	char *		color
	CODE:
	{
	   setCDKSelectionBackgroundColor (object,color);
	}

void
Register(object)
	CDKSELECTION *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vSELECTION, object);
	}

void
Unregister(object)
	CDKSELECTION *	object
	CODE:
	{
	   unregisterCDKObject (vSELECTION, object);
	}

void
Raise(object)
	CDKSELECTION *	object
	CODE:
	{
	   raiseCDKObject (vSELECTION, object);
	}

void
Lower(object)
	CDKSELECTION *	object
	CODE:
	{
	   lowerCDKObject (vSELECTION, object);
	}

WINDOW *
GetWindow(object)
	CDKSELECTION *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Viewer

CDKVIEWER *
New(buttons,height,width,buttonHighlight=A_REVERSE,xpos=CENTER,ypos=CENTER,Box=TRUE,shadow=FALSE)
	SV *	buttons
	int	height
	int	width
	chtype	buttonHighlight = sv2chtype ($arg);
	int	xpos = sv2int ($arg);
	int	ypos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKVIEWER *	viewerWidget = (CDKVIEWER *)NULL;
	   char **	Buttons;
	   int		buttonCount;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_CHAR_ARRAY (0, buttons, Buttons, buttonCount);

	   viewerWidget = newCDKViewer (GCDKSCREEN, xpos, ypos,
					height, width,
					Buttons, buttonCount,
					buttonHighlight, Box, shadow);
	   free (Buttons);

	   /* Check the return type. */
	   if (viewerWidget == (CDKVIEWER *)NULL)
	   {
	      croak ("Cdk::Viewer Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = viewerWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object)
	CDKVIEWER *	object
	CODE:
	{
	   int value = activateCDKViewer (object, (chtype *)NULL);

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

void
SetInfo(object,info,interpret=TRUE)
	CDKVIEWER *	object
	SV *		info
	int		interpret = sv2int ($arg);
	CODE:
	{
	   char **	Info;
	   int		infolen;

	   MAKE_CHAR_ARRAY(0, info, Info, infolen);
	   setCDKViewerInfo (object, Info, infolen, interpret);
	   free (Info);
	}

void
SetTitle(object,value)
	CDKVIEWER *	object
	char *		value
	CODE:
	{
	   setCDKViewerTitle (object,value);
	}

void
SetHighlight(object,value)
	CDKVIEWER *	object
	chtype		value
	CODE:
	{
	   setCDKViewerHighlight (object,value);
	}

void
SetInfoLine(object,value)
	CDKVIEWER *	object
	int		value
	CODE:
	{
	   setCDKViewerInfoLine (object,value);
	}

void
SetBox(object,Box=TRUE)
	CDKVIEWER *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKViewerBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKVIEWER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKViewerULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKVIEWER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKViewerURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKVIEWER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKViewerLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKVIEWER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKViewerLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKVIEWER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKViewerVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKVIEWER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKViewerHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKVIEWER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKViewerBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKVIEWER *	object
	char *		color
	CODE:
	{
	   setCDKViewerBackgroundColor (object,color);
	}

void
Bind(object,key,functionRef)
	CDKVIEWER *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vVIEWER, object, key, PerlBindCB, function);
	}

void
Draw(object,Box=TRUE)
	CDKVIEWER *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKViewer (object,Box);
	}

void
Erase(object)
	CDKVIEWER *	object
	CODE:
	{
	   eraseCDKViewer (object);
	}

void
Register(object)
	CDKVIEWER *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vVIEWER, object);
	}

void
Unregister(object)
	CDKVIEWER *	object
	CODE:
	{
	   unregisterCDKObject (vVIEWER, object);
	}

void
Raise(object)
	CDKVIEWER *	object
	CODE:
	{
	   raiseCDKObject (vVIEWER, object);
	}

void
Lower(object)
	CDKVIEWER *	object
	CODE:
	{
	   lowerCDKObject (vVIEWER, object);
	}

WINDOW *
GetWindow(object)
	CDKVIEWER *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Graph

CDKGRAPH *
New(title,xtitle,ytitle,height,width,xpos=CENTER,ypos=CENTER)
	SV *	title
	char *	xtitle
	char *	ytitle
	int	height
	int	width
	int	xpos = sv2int ($arg);
	int	ypos = sv2int ($arg);
	CODE:
	{
	   CDKGRAPH *	graphWidget = (CDKGRAPH *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   graphWidget = newCDKGraph (GCDKSCREEN,xpos,ypos,height,width,Title,xtitle,ytitle);

	   free (Title);

	   /* Check the return type. */
	   if (graphWidget == (CDKGRAPH *)NULL)
	   {
	      croak ("Cdk::Graph Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = graphWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
SetValues(object,values,startAtZero=TRUE)
	CDKGRAPH *		object
	SV *			values
	int			startAtZero = sv2int ($arg);
	CODE:
	{
	   int *	Values;
	   int		valueCount;

	   MAKE_INT_ARRAY (0, values, Values, valueCount);
	   RETVAL = setCDKGraphValues (object,Values,valueCount,startAtZero);
	   free (Values);
	}
	OUTPUT:
	   RETVAL

void
SetCharacters(object,value)
	CDKGRAPH *	object
	char *		value
	CODE:
	{
	   setCDKGraphCharacters (object,value);
	}

void
SetDisplayType(object,value)
	CDKGRAPH *	object
	char *		value
	CODE:
	{
	   EGraphDisplayType displayType = vLINE;

	   if (strEQ (value, "PLOT"))
	   {
	      displayType = vPLOT;
	   }

	   setCDKGraphDisplayType (object,displayType);
	}

void
SetBox(object,Box=FALSE)
	CDKGRAPH *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKGraphBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKGRAPH *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKGraphULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKGRAPH *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKGraphURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKGRAPH *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKGraphLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKGRAPH *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKGraphLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKGRAPH *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKGraphVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKGRAPH *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKGraphHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKGRAPH *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKGraphBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKGRAPH *	object
	char *		color
	CODE:
	{
	   setCDKGraphBackgroundColor (object,color);
	}

void
Draw(object,Box=FALSE)
	CDKGRAPH *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKGraph (object,Box);
	}

void
Erase(object)
	CDKGRAPH *	object
	CODE:
	{
	   eraseCDKGraph (object);
	}

void
Register(object)
	CDKGRAPH *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vGRAPH, object);
	}

void
Unregister(object)
	CDKGRAPH *	object
	CODE:
	{
	   unregisterCDKObject (vGRAPH, object);
	}

void
Raise(object)
	CDKGRAPH *	object
	CODE:
	{
	   raiseCDKObject (vGRAPH, object);
	}

void
Lower(object)
	CDKGRAPH *	object
	CODE:
	{
	   lowerCDKObject (vGRAPH, object);
	}

WINDOW *
GetWindow(object)
	CDKGRAPH *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Radio

CDKRADIO *
New(title,list,height,width,xPos=CENTER,yPos=CENTER,sPos=RIGHT,choice="X",defaultItem=0,highlight=A_REVERSE,Box=TRUE,shadow=FALSE)
	SV *	title
	SV *	list
	int	height
	int	width
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	sPos = sv2int ($arg);
	chtype	choice = sv2chtype ($arg);
	int	defaultItem
	chtype	highlight = sv2chtype ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKRADIO *	radioWidget = (CDKRADIO *)NULL;
	   char **	List;
	   char *	Title;
	   int listlen;

	   MAKE_CHAR_ARRAY(0, list, List, listlen);
	   MAKE_TITLE (title,Title);

	   radioWidget = newCDKRadio (GCDKSCREEN,xPos,yPos,sPos,
					height,width,Title,
					List,listlen,
					choice,defaultItem,
					highlight,Box,shadow);
	   free (List);
	   free (Title);

	   /* Check the return type. */
	   if (radioWidget == (CDKRADIO *)NULL)
	   {
	      croak ("Cdk::Radio Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = radioWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object,...)
	CDKRADIO *	object
	CODE:
	{
	   chtype *	Keys;
	   int arrayLen;
	   int value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKRadio (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKRadio (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

int
Inject(object,key)
	CDKRADIO *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKRadio (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKRADIO *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vRADIO, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKRADIO *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKRadioPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKRADIO *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKRadioPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKRADIO *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKRadio (object,Box);
	}

void
Erase(object)
	CDKRADIO *	object
	CODE:
	{
	   eraseCDKRadio (object);
	}

void
SetHighlight(object,highlight)
	CDKRADIO *	object
	chtype		highlight = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioHighlight (object,highlight);
	}

void
SetChoiceCharacter(object,value)
	CDKRADIO *	object
	chtype		value = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioChoiceCharacter (object,value);
	}

void
SetLeftBrace(object,value)
	CDKRADIO *	object
	chtype		value = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioLeftBrace (object,value);
	}

void
SetRightBrace(object,value)
	CDKRADIO *	object
	chtype		value = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioRightBrace (object,value);
	}

void
SetBox(object,Box=TRUE)
	CDKRADIO *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKRadioBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKRADIO *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKRADIO *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKRADIO *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKRADIO *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKRADIO *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKRADIO *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKRADIO *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKRadioBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKRADIO *	object
	char *		color
	CODE:
	{
	   setCDKRadioBackgroundColor (object,color);
	}

void
Register(object)
	CDKRADIO *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vRADIO, object);
	}

void
Unregister(object)
	CDKRADIO *	object
	CODE:
	{
	   unregisterCDKObject (vRADIO, object);
	}

void
Raise(object)
	CDKRADIO *	object
	CODE:
	{
	   raiseCDKObject (vRADIO, object);
	}

void
Lower(object)
	CDKRADIO *	object
	CODE:
	{
	   lowerCDKObject (vRADIO, object);
	}

WINDOW *
GetWindow(object)
	CDKRADIO *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Template

CDKTEMPLATE *
New(title,label,plate,cOverlay,xpos=CENTER,ypos=CENTER,Box=TRUE,shadow=FALSE)
	SV *	title
	char *	label
	char *	plate
	char *	cOverlay
	int	xpos = sv2int ($arg);
	int	ypos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKTEMPLATE * templateWidget = (CDKTEMPLATE *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   templateWidget = newCDKTemplate (GCDKSCREEN,xpos,ypos,
						Title,label,
						plate,cOverlay,
						Box,shadow);
	   free (Title);

	   /* Check the return type. */
	   if (templateWidget == (CDKTEMPLATE *)NULL)
	   {
	      croak ("Cdk::Template Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = templateWidget;
	   }
	}
	OUTPUT:
	   RETVAL

char *
Activate(object,...)
	CDKTEMPLATE *	object
	CODE:
	{
	   chtype *	Keys;
	   int arrayLen;
	   char *value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKTemplate (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKTemplate (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

char *
Inject(object,key)
	CDKTEMPLATE *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   char *value = injectCDKTemplate (object,key);
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKTEMPLATE *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vTEMPLATE, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKTEMPLATE *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKTemplatePreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKTEMPLATE *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKTemplatePostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

char *
Mix(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   RETVAL = mixCDKTemplate (object);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKTEMPLATE *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKTemplate (object, Box);
	}

void
Erase(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   eraseCDKTemplate (object);
	}

void
SetValue(object,value)
	CDKTEMPLATE *	object
	char *		value
	CODE:
	{
	   setCDKTemplateValue (object,value);
	}

void
SetMin(object,value)
	CDKTEMPLATE *	object
	int		value
	CODE:
	{
	   setCDKTemplateMin (object,value);
	}

void
SetBox(object,Box=TRUE)
	CDKTEMPLATE *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKTemplateBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKTEMPLATE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKTemplateULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKTEMPLATE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKTemplateURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKTEMPLATE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKTemplateLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKTEMPLATE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKTemplateLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKTEMPLATE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKTemplateVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKTEMPLATE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKTemplateHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKTEMPLATE *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKTemplateBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKTEMPLATE *	object
	char *		color
	CODE:
	{
	   setCDKTemplateBackgroundColor (object,color);
	}

char *
Get(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   RETVAL = object->info;
	}
	OUTPUT:
	   RETVAL

void
Clean(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   cleanCDKTemplate (object);
	}

void
Register(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vTEMPLATE, object);
	}

void
Unregister(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   unregisterCDKObject (vTEMPLATE, object);
	}

void
Raise(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   raiseCDKObject (vTEMPLATE, object);
	}

void
Lower(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   lowerCDKObject (vTEMPLATE, object);
	}

WINDOW *
GetWindow(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Swindow
CDKSWINDOW *
New(title,savelines,height,width,xpos=CENTER,ypos=CENTER,Box=TRUE,shadow=FALSE)
	SV *	title
	int	savelines
	int	height
	int	width
	int	xpos = sv2int ($arg);
	int	ypos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKSWINDOW *	swindowWidget = (CDKSWINDOW *)NULL;
	   char *	Title;

	   MAKE_TITLE (title,Title);

	   swindowWidget = newCDKSwindow (GCDKSCREEN,xpos,ypos,
						height,width,
						Title,savelines,
						Box,shadow);
	   free (Title);

	   /* Check the return type. */
	   if (swindowWidget == (CDKSWINDOW *)NULL)
	   {
	      croak ("Cdk::Swindow Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = swindowWidget;
	   }
	}
	OUTPUT:
	   RETVAL

void
Activate(object,...)
	CDKSWINDOW *	object
	CODE:
	{
	   chtype *	Keys;
	   int arrayLen;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      activateCDKSwindow (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      activateCDKSwindow (object, NULL);
	   }
	}

int
Inject(object,key)
	CDKSWINDOW *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKSwindow (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKSWINDOW *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vSWINDOW, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKSWINDOW *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKSwindowPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKSWINDOW *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKSwindowPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
SetContents(object,info)
	CDKSWINDOW *	object
	SV *		info
	CODE:
	{
	   char **	Loginfo;
	   int		infolen;

	   MAKE_CHAR_ARRAY(0, info, Loginfo, infolen);
	   setCDKSwindowContents (object, Loginfo, infolen);
	   free (Loginfo);
	}

void
SetBox(object,Box=TRUE)
	CDKSWINDOW *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKSwindowBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKSWINDOW *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSwindowULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKSWINDOW *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSwindowURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKSWINDOW *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSwindowLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKSWINDOW *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSwindowLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKSWINDOW *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSwindowVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKSWINDOW *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSwindowHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKSWINDOW *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSwindowBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKSWINDOW *	object
	char *		color
	CODE:
	{
	   setCDKSwindowBackgroundColor (object,color);
	}

void
Addline(object,info,insertpos)
	CDKSWINDOW *	object
	char *		info
	int		insertpos = sv2int ($arg);
	CODE:
	{
	   addCDKSwindow (object, info, insertpos);
	}

void
Trim(object,start,finish)
	CDKSWINDOW *	object
	int		start = sv2int ($arg);
	int		finish = sv2int ($arg);
	CODE:
	{
	   trimCDKSwindow (object, start, finish);
	}

int
Exec(object,command,insertPos=BOTTOM)
	CDKSWINDOW *	object
	char *		command
	int		insertPos = sv2int ($arg);
	CODE:
	{
	   RETVAL = execCDKSwindow (object, command, insertPos);
	}
	OUTPUT:
	   RETVAL

void
Get(object)
	CDKSWINDOW *	object
	PPCODE:
	{
	   int x;
	   char *temp;

	   /* Push each item onto the stack.		*/
	   for (x=0; x < object->listSize ; x++)
	   {
	      /* We need to convert from chtype to char */
	      temp = chtype2Char (object->list[x]);

	      /* Push it on the stack.			*/
	      XPUSHs (sv_2mortal(newSVpv(temp, strlen(temp))));
	      freeChar (temp);
	   }
	}

void
Save(object)
	CDKSWINDOW *	object
	CODE:
	{
	   saveCDKSwindowInformation (object);
	}

void
Load(object)
	CDKSWINDOW *	object
	CODE:
	{
	   loadCDKSwindowInformation (object);
	}

int
Dump(object,filename)
	CDKSWINDOW *	object
	char *		filename
	CODE:
	{
	   RETVAL = dumpCDKSwindow (object, filename);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKSWINDOW *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKSwindow (object, Box);
	}

void
Erase(object)
	CDKSWINDOW *	object
	CODE:
	{
	   eraseCDKSwindow (object);
	}

void
Clean(object)
	CDKSWINDOW *	object
	CODE:
	{
	   cleanCDKSwindow (object);
	}

void
Register(object)
	CDKSWINDOW *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vSWINDOW, object);
	}

void
Unregister(object)
	CDKSWINDOW *	object
	CODE:
	{
	   unregisterCDKObject (vSWINDOW, object);
	}

void
Raise(object)
	CDKSWINDOW *	object
	CODE:
	{
	   raiseCDKObject (vSWINDOW, object);
	}

void
Lower(object)
	CDKSWINDOW *	object
	CODE:
	{
	   lowerCDKObject (vSWINDOW, object);
	}

WINDOW *
GetWindow(object)
	CDKSWINDOW *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Itemlist
CDKITEMLIST *
New(title,label,itemlist,defaultItem=0,xpos=CENTER,ypos=CENTER,Box=TRUE,shadow=FALSE)
	SV *	title
	char *	label
	SV *	itemlist
	int	defaultItem
	int	xpos = sv2int ($arg);
	int	ypos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKITEMLIST * itemlistWidget = (CDKITEMLIST *)NULL;
	   char *	Title;
	   char **	Itemlist;
	   int		itemLength;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_CHAR_ARRAY (0, itemlist, Itemlist, itemLength);
	   MAKE_TITLE (title,Title);

	   itemlistWidget = newCDKItemlist (GCDKSCREEN,xpos,ypos,
						Title,label,
						Itemlist,itemLength,
						defaultItem,Box,shadow);
	   free (Itemlist);
	   free (Title);

	   /* Check the return type. */
	   if (itemlistWidget == (CDKITEMLIST *)NULL)
	   {
	      croak ("Cdk::Itemlist Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = itemlistWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object,...)
	CDKITEMLIST *	object
	CODE:
	{
	   chtype *	Keys;
	   int arrayLen;
	   int value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKItemlist (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKItemlist (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

int
Inject(object,key)
	CDKITEMLIST *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKItemlist (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKITEMLIST *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vITEMLIST, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKITEMLIST *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKItemlistPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKITEMLIST *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKItemlistPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
SetValues(object,values)
	CDKITEMLIST *	object
	SV *		values
	CODE:
	{
	   char **	Values;
	   int		valueLength;

	   MAKE_CHAR_ARRAY(0, values, Values, valueLength);
	   setCDKItemlistValues (object, Values, valueLength, object->defaultItem);
	   free (Values);
	}

void
SetDefaultItem(object,value)
	CDKITEMLIST *	object
	int		value
	CODE:
	{
	   setCDKItemlistDefaultItem (object,value);
	}

void
SetCurrentItem(object,value)
	CDKITEMLIST *	object
	int		value
	CODE:
	{
	   setCDKItemlistCurrentItem (object,value);
	}

void
SetBox(object,Box=TRUE)
	CDKITEMLIST *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKItemlistBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKITEMLIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKItemlistULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKITEMLIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKItemlistURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKITEMLIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKItemlistLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKITEMLIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKItemlistLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKITEMLIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKItemlistVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKITEMLIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKItemlistHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKITEMLIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKItemlistBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKITEMLIST *	object
	char *		color
	CODE:
	{
	   setCDKItemlistBackgroundColor (object,color);
	}

char *
Get(object)
	CDKITEMLIST *	object
	CODE:
	{
	   RETVAL = chtype2Char (object->item[object->currentItem]);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKITEMLIST *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKItemlist (object,Box);
	}

void
Erase(object)
	CDKITEMLIST *	object
	CODE:
	{
	   eraseCDKItemlist (object);
	}

void
Register(object)
	CDKITEMLIST *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN,vITEMLIST,object);
	}

void
Unregister(object)
	CDKITEMLIST *	object
	CODE:
	{
	   unregisterCDKObject (vITEMLIST, object);
	}

void
Raise(object)
	CDKITEMLIST *	object
	CODE:
	{
	   raiseCDKObject (vITEMLIST, object);
	}

void
Lower(object)
	CDKITEMLIST *	object
	CODE:
	{
	   lowerCDKObject (vITEMLIST, object);
	}

WINDOW *
GetWindow(object)
	CDKITEMLIST *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Fselect
CDKFSELECT *
New(title,label,height,width,dAttrib="</N>",fAttrib="</N>",lAttrib="</N>",sAttrib="</N>",highlight="</R>",fieldAttribute=A_NORMAL,filler=".",xPos=CENTER,yPos=CENTER,Box=TRUE,shadow=FALSE)
	SV *	title
	char *	label
	int	height
	int	width
	char *	dAttrib
	char *	fAttrib
	char *	lAttrib
	char *	sAttrib
	chtype	highlight = sv2chtype ($arg);
	chtype	fieldAttribute = sv2chtype ($arg);
	chtype	filler = sv2chtype ($arg);
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKFSELECT * fselectWidget = (CDKFSELECT *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   fselectWidget = newCDKFselect (GCDKSCREEN,xPos,yPos,
						height,width,
						Title,label,
						fieldAttribute,filler,highlight,
						dAttrib,fAttrib,lAttrib,sAttrib,
						Box,shadow);
	   free (Title);

	   /* Check the return type. */
	   if (fselectWidget == (CDKFSELECT *)NULL)
	   {
	      croak ("Cdk::Fselect Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = fselectWidget;
	   }
	}
	OUTPUT:
	   RETVAL

char *
Activate(object,...)
	CDKFSELECT *	object
	CODE:
	{
	   chtype *	Keys;
	   int arrayLen;
	   char *value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKFselect (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKFselect (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

char *
Inject(object,key)
	CDKFSELECT *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   char *value = injectCDKFselect (object,key);
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

void
SetDirectory(object,value)
	CDKFSELECT *	object
	char *		value
	CODE:
	{
	   setCDKFselectDirectory (object,value);
	}

void
SetFillerChar(object,value)
	CDKFSELECT *	object
	chtype		value
	CODE:
	{
	   setCDKFselectFillerChar (object,value);
	}

void
SetHighlight(object,value)
	CDKFSELECT *	object
	chtype		value
	CODE:
	{
	   setCDKFselectHighlight (object,value);
	}

void
SetDirAttribute(object,value)
	CDKFSELECT *	object
	char *		value
	CODE:
	{
	   setCDKFselectDirAttribute (object,value);
	}

void
SetLinkAttribute(object,value)
	CDKFSELECT *	object
	char *		value
	CODE:
	{
	   setCDKFselectLinkAttribute (object,value);
	}

void
SetFileAttribute(object,value)
	CDKFSELECT *	object
	char *		value
	CODE:
	{
	   setCDKFselectFileAttribute (object,value);
	}

void
SetSocketkAttribute(object,value)
	CDKFSELECT *	object
	char *		value
	CODE:
	{
	   setCDKFselectSocketAttribute (object,value);
	}

void
SetBox(object,Box=TRUE)
	CDKFSELECT *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKFselectBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKFSELECT *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKFselectULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKFSELECT *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKFselectURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKFSELECT *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKFselectLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKFSELECT *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKFselectLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKFSELECT *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKFselectVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKFSELECT *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKFselectHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKFSELECT *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKFselectBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKFSELECT *	object
	char *		color
	CODE:
	{
	   setCDKFselectBackgroundColor (object,color);
	}

void
Bind(object,key,functionRef)
	CDKFSELECT *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vFSELECT, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKFSELECT *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKFselectPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKFSELECT *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKFselectPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKFSELECT *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKFselect (object,Box);
	}

void
Erase(object)
	CDKFSELECT *	object
	CODE:
	{
	   eraseCDKFselect (object);
	}

void
Register(object)
	CDKFSELECT *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN,vFSELECT,object);
	}

void
Unregister(object)
	CDKFSELECT *	object
	CODE:
	{
	   unregisterCDKObject (vFSELECT, object);
	}

void
Raise(object)
	CDKFSELECT *	object
	CODE:
	{
	   raiseCDKObject (vFSELECT, object);
	}

void
Lower(object)
	CDKFSELECT *	object
	CODE:
	{
	   lowerCDKObject (vFSELECT, object);
	}

WINDOW *
GetWindow(object)
	CDKFSELECT *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Slider
CDKSLIDER *
New(title,label,start,low,high,inc,fastInc,fieldWidth,xPos,yPos,filler,Box,shadow)
	SV *	title
	char *	label
	int	start
	int	low
	int	high
	int	inc
	int	fastInc
	int	fieldWidth
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	chtype	filler = sv2chtype ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKSLIDER *	sliderWidget = (CDKSLIDER *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   sliderWidget = newCDKSlider (GCDKSCREEN,
					xPos,yPos,
					Title, label,
					filler,fieldWidth,
					start,low,high,
					inc,fastInc,
					Box,shadow);
	   free (Title);

	   /* Check the return type. */
	   if (sliderWidget == (CDKSLIDER *)NULL)
	   {
	      croak ("Cdk::Slider Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = sliderWidget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object,...)
	CDKSLIDER *	object
	CODE:
	{
	   chtype *	Keys;
	   int arrayLen;
	   int value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKSlider (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKSlider (object, (chtype *)NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

int
Inject(object,key)
	CDKSLIDER *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int value = injectCDKSlider (object,key);
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

void
SetValue(object,value)
	CDKSLIDER*	object
	int		value
	CODE:
	{
	   setCDKSliderValue (object,value);
	}

void
SetLowHigh(object,low,high)
	CDKSLIDER *	object
	int		low
	int		high
	CODE:
	{
	   setCDKSliderLowHigh (object,low,high);
	}

void
SetBox(object,Box=TRUE)
	CDKSLIDER *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKSliderBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKSLIDER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSliderULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKSLIDER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSliderURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKSLIDER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSliderLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKSLIDER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSliderLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKSLIDER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSliderVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKSLIDER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSliderHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKSLIDER *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKSliderBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKSLIDER *	object
	char *		color
	CODE:
	{
	   setCDKSliderBackgroundColor (object,color);
	}

void
Bind(object,key,functionRef)
	CDKSLIDER *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vSLIDER, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKSLIDER *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKSliderPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKSLIDER *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKSliderPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKSLIDER *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKSlider (object,Box);
	}

void
Erase(object)
	CDKSLIDER *	object
	CODE:
	{
	   eraseCDKSlider (object);
	}

void
Register(object)
	CDKSLIDER *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN,vSLIDER,object);
	}

void
Unregister(object)
	CDKSLIDER *	object
	CODE:
	{
	   unregisterCDKObject (vSLIDER, object);
	}

void
Raise(object)
	CDKSLIDER *	object
	CODE:
	{
	   raiseCDKObject (vSLIDER, object);
	}

void
Lower(object)
	CDKSLIDER *	object
	CODE:
	{
	   lowerCDKObject (vSLIDER, object);
	}

WINDOW *
GetWindow(object)
	CDKSLIDER *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Alphalist
CDKALPHALIST *
New(title,label,list,height,width,xPos,yPos,highlight,filler,Box,shadow)
	SV *	title
	char *	label
	SV *	list
	int	height
	int	width
	chtype	highlight = sv2chtype ($arg);
	chtype	filler = sv2chtype ($arg);
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKALPHALIST * alphalistWidget = (CDKALPHALIST *)NULL;
	   char **	List;
	   char *	Title;
	   int listSize;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_CHAR_ARRAY(0, list, List, listSize);
	   MAKE_TITLE (title,Title);

	   alphalistWidget = newCDKAlphalist (GCDKSCREEN,xPos,yPos,
						height,width,
						Title,label,
						List,listSize,
						filler,highlight,
						Box,shadow);
	   free (List);
	   free (Title);

	   /* Check the return type. */
	   if (alphalistWidget == (CDKALPHALIST *)NULL)
	   {
	      croak ("Cdk::Alphalist Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = alphalistWidget;
	   }
	}
	OUTPUT:
	   RETVAL

void
Activate(object,...)
	CDKALPHALIST *	object
	PPCODE:
	{
	   SV *sv = (SV *)&PL_sv_undef;
	   chtype *	Keys;
	   int arrayLen;
	   char *value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKAlphalist (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKAlphalist (object, NULL);
	   }

	   if (object->exitType == vNORMAL)
	   {
	      sv = newSVpv (value, strlen (value));
	   }
	   XPUSHs (sv);
	}

char *
Inject(object,key)
	CDKALPHALIST *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   char *value = injectCDKAlphalist (object,key);
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

void
SetContents(object,list)
	CDKALPHALIST*	object
	SV *		list
	CODE:
	{
	   char **	List;
	   int		listSize;

	   MAKE_CHAR_ARRAY(0, list, List, listSize);
	   setCDKAlphalistContents (object, List, listSize);
	   free (List);
	}

void
SetFillerChar(object,filler)
	CDKALPHALIST*	object
	chtype	filler = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistFillerChar (object,filler);
	}

void
SetHighlight(object,highlight)
	CDKALPHALIST*	object
	chtype	highlight = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistHighlight (object,highlight);
	}

void
SetBox(object,Box=TRUE)
	CDKALPHALIST *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKAlphalistBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKALPHALIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKALPHALIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKALPHALIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKALPHALIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKALPHALIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKALPHALIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKALPHALIST *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKAlphalistBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKALPHALIST *	object
	char *		color
	CODE:
	{
	   setCDKAlphalistBackgroundColor (object,color);
	}

char *
Get(object)
	CDKALPHALIST *	object
	CODE:
	{
	   RETVAL = object->entryField->info;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKALPHALIST *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vALPHALIST, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKALPHALIST *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKAlphalistPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKALPHALIST *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKAlphalistPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKALPHALIST *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKAlphalist (object,Box);
	}

void
Erase(object)
	CDKALPHALIST *	object
	CODE:
	{
	   eraseCDKAlphalist (object);
	}

void
Register(object)
	CDKALPHALIST *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN,vALPHALIST,object);
	}

void
Unregister(object)
	CDKALPHALIST *	object
	CODE:
	{
	   unregisterCDKObject (vALPHALIST, object);
	}

void
Raise(object)
	CDKALPHALIST *	object
	CODE:
	{
	   raiseCDKObject (vALPHALIST, object);
	}

void
Lower(object)
	CDKALPHALIST *	object
	CODE:
	{
	   lowerCDKObject (vALPHALIST, object);
	}

WINDOW *
GetWindow(object)
	CDKALPHALIST *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Calendar

CDKCALENDAR *
New(title,day,month,year,dayAttrib,monthAttrib,yearAttrib,highlight,xPos=CENTER,yPos=CENTER,Box=TRUE,shadow=FALSE)
	SV *	title
	int	day
	int	month
	int	year
	chtype	dayAttrib = sv2chtype ($arg);
	chtype	monthAttrib = sv2chtype ($arg);
	chtype	yearAttrib = sv2chtype ($arg);
	chtype	highlight = sv2chtype ($arg);
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKCALENDAR * calendarWidget = (CDKCALENDAR *)NULL;
	   char *	Title;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_TITLE (title,Title);

	   calendarWidget = newCDKCalendar (GCDKSCREEN,xPos,yPos,Title,
						day,month,year,
						dayAttrib,monthAttrib,yearAttrib,
						highlight,Box,shadow);
	   free (Title);

	   /* Check the return type. */
	   if (calendarWidget == (CDKCALENDAR *)NULL)
	   {
	      croak ("Cdk::Calendar Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = calendarWidget;
	   }
	}
	OUTPUT:
	   RETVAL

void
Activate(object,...)
	CDKCALENDAR *	object
	PPCODE:
	{
	   chtype *	Keys;
	   int arrayLen;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      activateCDKCalendar (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      activateCDKCalendar (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }

	   XPUSHs (sv_2mortal(newSViv(object->day)));
	   XPUSHs (sv_2mortal(newSViv(object->month)));
	   XPUSHs (sv_2mortal(newSViv(object->year)));
	}

void
Inject(object,key)
	CDKCALENDAR *	object
	chtype		key = sv2chtype ($arg);
	PPCODE:
	{
	   (void) injectCDKCalendar (object,key);
	   if (object->exitType == vESCAPE_HIT ||
	       object->exitType == vEARLY_EXIT)
	   {
	      XSRETURN_UNDEF;
	   }

	   XPUSHs (sv_2mortal(newSViv(object->day)));
	   XPUSHs (sv_2mortal(newSViv(object->month)));
	   XPUSHs (sv_2mortal(newSViv(object->year)));
	}

void
SetDate(object,day,month,year)
	CDKCALENDAR *	object
	int		day
	int		month
	int		year
	CODE:
	{
	   setCDKCalendarDate (object,day,month,year);
	}

void
GetDate(object)
	CDKCALENDAR *	object
	PPCODE:
	{
	   XPUSHs (sv_2mortal(newSViv(object->day)));
	   XPUSHs (sv_2mortal(newSViv(object->month)));
	   XPUSHs (sv_2mortal(newSViv(object->year)));
	}

void
SetMarker(object,day,month,year,marker)
	CDKCALENDAR *	object
	int		day
	int		month
	int		year
	chtype		marker = sv2chtype ($arg);
	CODE:
	{
	   setCDKCalendarMarker (object,day,month,year,marker);
	}

void
RemoveMarker(object,day,month,year)
	CDKCALENDAR *	object
	int		day
	int		month
	int		year
	CODE:
	{
	   removeCDKCalendarMarker (object,day,month,year);
	}

void
SetDayAttribute(object,attribute)
	CDKCALENDAR *	object
	chtype		attribute = sv2chtype ($arg);
	CODE:
	{
	   setCDKCalendarDayAttribute (object, attribute);
	}

void
Bind(object,key,functionRef)
	CDKCALENDAR *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vCALENDAR, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKCALENDAR *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKCalendarPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKCALENDAR *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKCalendarPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKCALENDAR *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKCalendar (object,Box);
	}

void
Erase(object)
	CDKCALENDAR *	object
	CODE:
	{
	   eraseCDKCalendar(object);
	}

void
Set(object,year,month,day,yearAttrib,monthAttrib,dayAttrib,highlight,Box)
	CDKCALENDAR *	object
	int		day
	int		month
	int		year
	chtype		dayAttrib = sv2chtype ($arg);
	chtype		monthAttrib = sv2chtype ($arg);
	chtype		yearAttrib = sv2chtype ($arg);
	chtype		highlight = sv2chtype ($arg);
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKCalendar (object,day,month,year,yearAttrib,monthAttrib,dayAttrib,highlight,Box);
	}

void
Register(object)
	CDKCALENDAR *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vCALENDAR, object);
	}

void
Unregister(object)
	CDKCALENDAR *	object
	CODE:
	{
	   unregisterCDKObject (vCALENDAR, object);
	}

void
Raise(object)
	CDKCALENDAR *	object
	CODE:
	{
	   raiseCDKObject (vCALENDAR, object);
	}

void
Lower(object)
	CDKCALENDAR *	object
	CODE:
	{
	   lowerCDKObject (vCALENDAR, object);
	}

WINDOW *
GetWindow(object)
	CDKCALENDAR *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = Cdk::Buttonbox

CDKBUTTONBOX *
New(title,buttons,rows,cols,height,width,xPos=CENTER,yPos=CENTER,highlight=A_REVERSE,Box=TRUE,shadow=FALSE)
	SV *	title
	SV *	buttons
	int	rows
	int	cols
	int	height
	int	width
	int	xPos = sv2int ($arg);
	int	yPos = sv2int ($arg);
	chtype	highlight = sv2chtype ($arg);
	int	Box = sv2int ($arg);
	int	shadow = sv2int ($arg);
	CODE:
	{
	   CDKBUTTONBOX *	widget = (CDKBUTTONBOX *)NULL;
	   char **		Buttons;
	   char *		Title;
	   int			buttonCount;

	   checkCdkInit();
	   RETVAL = 0;

	   MAKE_CHAR_ARRAY (0, buttons, Buttons, buttonCount);
	   MAKE_TITLE (title,Title);

	   widget = newCDKButtonbox (GCDKSCREEN, xPos, yPos,
					height, width, Title,
					rows, cols,
					Buttons, buttonCount,
					highlight, Box, shadow);
	   free (Buttons);
	   free (Title);

	   /* Check the return type. */
	   if (widget == (CDKBUTTONBOX *)NULL)
	   {
	      croak ("Cdk::Buttonbox Could not create widget. Is the window too small?\n");
	   }
	   else
	   {
	      RETVAL = widget;
	   }
	}
	OUTPUT:
	   RETVAL

int
Activate(object,...)
	CDKBUTTONBOX *	object
	CODE:
	{
	   chtype *	Keys;
	   int arrayLen;
	   int value;

	   if (items > 1)
	   {
	      MAKE_CHTYPE_ARRAY(0, ST(1), Keys, arrayLen);
	      value = activateCDKButtonbox (object, Keys);
	      free (Keys);
	   }
	   else
	   {
	      value = activateCDKButtonbox (object, NULL);
	   }

	   if (object->exitType == vEARLY_EXIT ||
	       object->exitType == vESCAPE_HIT)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = value;
	}
	OUTPUT:
	   RETVAL

int
Inject(object,key)
	CDKBUTTONBOX *	object
	chtype		key = sv2chtype ($arg);
	CODE:
	{
	   int selection = injectCDKButtonbox (object,key);
	   if (selection == -1)
	   {
	      XSRETURN_UNDEF;
	   }
	   RETVAL = selection;
	}
	OUTPUT:
	   RETVAL

void
Bind(object,key,functionRef)
	CDKBUTTONBOX *	object
	chtype		key = sv2chtype ($arg);
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   bindCDKObject (vBUTTONBOX, object, key, PerlBindCB, function);
	}

int
PreProcess(object,functionRef)
	CDKBUTTONBOX *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKButtonboxPreProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

int
PostProcess(object,functionRef)
	CDKBUTTONBOX *	object
	SV *		functionRef
	CODE:
	{
	   SV *function = newSVsv (functionRef);
	   RETVAL = 0;
	   setCDKButtonboxPostProcess (object, PerlProcessCB, function);
	}
	OUTPUT:
	   RETVAL

void
Draw(object,Box=TRUE)
	CDKBUTTONBOX *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   drawCDKButtonbox (object,Box);
	}

void
Erase(object)
	CDKBUTTONBOX *	object
	CODE:
	{
	   eraseCDKButtonbox (object);
	}

void
SetHighlight(object,highlight=A_REVERSE)
	CDKBUTTONBOX *	object
	chtype		highlight = sv2chtype ($arg);
	CODE:
	{
	   setCDKButtonboxHighlight (object,highlight);
	}

void
SetBox(object,Box=TRUE)
	CDKBUTTONBOX *	object
	int		Box = sv2int ($arg);
	CODE:
	{
	   setCDKButtonboxBox (object,Box);
	}

void
SetULChar(object,character=ACS_ULCORNER)
	CDKBUTTONBOX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKButtonboxULChar (object,character);
	}

void
SetURChar(object,character=ACS_URCORNER)
	CDKBUTTONBOX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKButtonboxURChar (object,character);
	}

void
SetLLChar(object,character=ACS_LLCORNER)
	CDKBUTTONBOX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKButtonboxLLChar (object,character);
	}

void
SetLRChar(object,character=ACS_LRCORNER)
	CDKBUTTONBOX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKButtonboxLRChar (object,character);
	}

void
SetVerticalChar(object,character=ACS_VLINE)
	CDKBUTTONBOX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKButtonboxVerticalChar (object,character);
	}

void
SetHorizontalChar(object,character=ACS_HLINE)
	CDKBUTTONBOX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKButtonboxHorizontalChar (object,character);
	}

void
SetBoxAttribute(object,character=ACS_HLINE)
	CDKBUTTONBOX *	object
	chtype		character = sv2chtype ($arg);
	CODE:
	{
	   setCDKButtonboxBoxAttribute (object,character);
	}

void
SetBackgroundColor(object,color)
	CDKBUTTONBOX *	object
	char *		color
	CODE:
	{
	   setCDKButtonboxBackgroundColor (object,color);
	}

void
Register(object)
	CDKBUTTONBOX *	object
	CODE:
	{
	   registerCDKObject (GCDKSCREEN, vBUTTONBOX, object);
	}

void
Unregister(object)
	CDKBUTTONBOX *	object
	CODE:
	{
	   unregisterCDKObject (vBUTTONBOX, object);
	}

void
Raise(object)
	CDKBUTTONBOX *	object
	CODE:
	{
	   raiseCDKObject (vBUTTONBOX, object);
	}

void
Lower(object)
	CDKBUTTONBOX *	object
	CODE:
	{
	   lowerCDKObject (vBUTTONBOX, object);
	}

WINDOW *
GetWindow(object)
	CDKBUTTONBOX *	object
	CODE:
	{
	   RETVAL = object->win;
	}
	OUTPUT:
	   RETVAL

MODULE	= Cdk	PACKAGE = CDKLABELPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKLABEL *	object
	CODE:
	{
	   destroyCDKLabel (object);
	}

MODULE	= Cdk	PACKAGE = CDKBUTTONBOXPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKBUTTONBOX *	object
	CODE:
	{
	   destroyCDKButtonbox (object);
	}

MODULE	= Cdk	PACKAGE = CDKDIALOGPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKDIALOG *	object
	CODE:
	{
	   destroyCDKDialog (object);
	}

MODULE	= Cdk	PACKAGE = CDKENTRYPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKENTRY *	object
	CODE:
	{
	   destroyCDKEntry (object);
	}

MODULE	= Cdk	PACKAGE = CDKSCROLLPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKSCROLL *	object
	CODE:
	{
	   destroyCDKScroll (object);
	}

MODULE	= Cdk	PACKAGE = CDKSCALEPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKSCALE *	object
	CODE:
	{
	   destroyCDKScale (object);
	}

MODULE	= Cdk	PACKAGE = CDKHISTOGRAMPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKHISTOGRAM *	object
	CODE:
	{
	   destroyCDKHistogram (object);
	}

MODULE	= Cdk	PACKAGE = CDKMENUPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKMENU *	object
	CODE:
	{
	   destroyCDKMenu (object);
	}

MODULE	= Cdk	PACKAGE = CDKMENTRYPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKMENTRY *	object
	CODE:
	{
	   destroyCDKMentry (object);
	}

MODULE	= Cdk	PACKAGE = CDKMATRIXPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKMATRIX *	object
	CODE:
	{
	   destroyCDKMatrix (object);
	}

MODULE	= Cdk	PACKAGE = CDKMARQUEEPtr PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKMARQUEE *	object
	CODE:
	{
	   destroyCDKMarquee (object);
	}

MODULE	= Cdk	PACKAGE = CDKSELECTIONPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKSELECTION *	object
	CODE:
	{
	   destroyCDKSelection (object);
	}

MODULE	= Cdk	PACKAGE = CDKVIEWERPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKVIEWER *	object
	CODE:
	{
	   destroyCDKViewer (object);
	}

MODULE	= Cdk	PACKAGE = CDKGRAPHPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKGRAPH *	object
	CODE:
	{
	   destroyCDKGraph (object);
	}

MODULE	= Cdk	PACKAGE = CDKRADIOPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKRADIO *	object
	CODE:
	{
	   destroyCDKRadio (object);
	}

MODULE	= Cdk	PACKAGE = CDKTEMPLATEPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKTEMPLATE *	object
	CODE:
	{
	   destroyCDKTemplate (object);
	}

MODULE	= Cdk	PACKAGE = CDKSWINDOWPtr		PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKSWINDOW *	object
	CODE:
	{
	   destroyCDKSwindow (object);
	}

MODULE	= Cdk	PACKAGE = CDKITEMLISTPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKITEMLIST *	object
	CODE:
	{
	   destroyCDKItemlist (object);
	}

MODULE	= Cdk	PACKAGE = CDKFSELECTPtr		PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKFSELECT *	object
	CODE:
	{
	   destroyCDKFselect (object);
	}

MODULE	= Cdk	PACKAGE = CDKSLIDERPtr		PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKSLIDER *	object
	CODE:
	{
	   destroyCDKSlider (object);
	}

MODULE	= Cdk	PACKAGE = CDKALPHALISTPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKALPHALIST *	object
	CODE:
	{
	   destroyCDKAlphalist (object);
	}

MODULE	= Cdk	PACKAGE = CDKCALENDARPtr	PREFIX	= cdk_
void
cdk_DESTROY(object)
	CDKCALENDAR *	object
	CODE:
	{
	   destroyCDKCalendar (object);
	}
