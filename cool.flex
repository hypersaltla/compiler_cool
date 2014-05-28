/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr = 0;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */ 

%}

/*
 * Define names for regular expressions here.
 */

WS	[ \n\t\r\f\v]
CLASS	[cC][lL][aA][sS][sS]
ELSE	[eE][lL][sS][eE]
FI	[fF][iI]
IF	[iI][fF]
IN	[iI][nN]
INHERITS	[iI][nN][hH][eE][rR][iI][tT][sS]
LET	[lL][eE][tT]
LOOP	[lL][oO][oO][pP]
POOL	[pP][oO][oO][lL]
THEN	[tT][hH][eE][nN]
WHILE	[wW][hH][iI][lL][eE]
CASE	[cC][aA][sS][eE]
ESAC	[eE][sS][aA][cC]
OF	[oO][fF]
DARROW	=>
NEW	[nN][eE][wW]
ISVOID	[iI][sS][vV][oO][iI][dD]
/* STR_CONST	\"[^"\n]*(\"|\n)? */
INT_CONST	[0-9]+
BOOL_CONST	(t[rR][uU][eE]|f[aA][lL][sS][eE])
TYPEID	[A-Z][a-zA-Z0-9_]*
OBJECTID	[a-z][a-zA-Z0-9_]*
ASSIGN	<-
NOT	[nN][oO][tT]
LE	<=
SPEC (<|\+|-|\*|\/|\.|\~|\=|\)|\(|\{|\}|\:|;|,|@) 
CMT_ONE	--[^\n]*
CMT_LEFT	\(\*
CMT_RIGHT	\*\)
/*CMT_MUL_OPEN	\(\*([^\*]*(\*[^\)])?)* */

%%

{WS} { if(yytext[0] == '\n') curr_lineno++; }
 
 /*
  *  Nested comments
  */

{CMT_ONE} ;
{CMT_LEFT} {
	int stack_top = 1;
	char previous = '#';
	char cur;
	while( (cur = yyinput()) != EOF) {
		if(cur == ')' && previous == '*') {
			stack_top--;
			previous = '#';
		}
		else if(cur == '*' && previous == '(') {
			stack_top++;
			previous = '#';
		}
		else {
			previous = cur;
		}
		if(cur == '\n') curr_lineno++;
		if(stack_top == 0) {
			break;
		}
	}
	if(stack_top > 0) {
		cool_yylval.error_msg = "EOF in comment";
		return ERROR;
	}
}

{CMT_RIGHT} {
	cool_yylval.error_msg = "Unmatched *)";
	return ERROR;
}

 /*
  *  The multiple-character operators.
  */
{DARROW}   { return (DARROW); }
{LE}   { return LE; }
{ASSIGN}   { return ASSIGN; }
{SPEC}	{ return yytext[0]; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{CLASS}   { return CLASS; }
{ELSE}   { return ELSE; }
{FI}   { return FI; }
{IF}   { return IF; }
{IN}   { return IN; }
{INHERITS}   { return INHERITS; }
{LET}   { return LET; }
{LOOP}   { return LOOP; }
{POOL}   { return POOL; }
{THEN}   { return THEN; }
{WHILE}   { return WHILE; }
{CASE}   { return CASE; }
{ESAC}   { return ESAC; }
{OF}   { return OF; }
{NEW}   { return NEW; }
{ISVOID}   { return ISVOID; }
{NOT}   { return NOT; }


{BOOL_CONST} {
	if(yytext[0] == 't') {
		cool_yylval.symbol = inttable.add_int(1);
		cool_yylval.boolean = 1;
	}
	else {
		cool_yylval.symbol = inttable.add_int(0);
		cool_yylval.boolean = 0;
	}
	return BOOL_CONST;
}


{INT_CONST} {
	cool_yylval.symbol = inttable.add_string(yytext);
	return INT_CONST;
}

{TYPEID} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return TYPEID;
}

{OBJECTID} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return OBJECTID;
}


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

\" {
	string_buf_ptr = string_buf;
	char previous = '"';
	char cur;
	cool_yylval.error_msg = 0;
	while( (cur = yyinput()) != EOF ) {
		if(string_buf_ptr - string_buf == MAX_STR_CONST) {
			cool_yylval.error_msg = "String constant too long";
			return ERROR;
		}
		if(cur == 0) {
			cool_yylval.error_msg = "String contains null character";
		}
		if(previous == '\\') {
			switch (cur) {
				case 'n': cur = '\n'; break;
				case 't': cur = '\t'; break;
				case 'f': cur = '\f'; break;
				case 'v': cur = '\v'; break;
				case 'b': cur = '\b'; break;
				case '\n': curr_lineno++; break;
				case 0: cool_yylval.error_msg = "String contains escaped null character"; break;
				default : break;
			}
		}
		else if(cur == '\n') {
			cool_yylval.error_msg = "Unterminated string constant";
			curr_lineno++;
			return ERROR;
		}
		else if(cur == '"') {
			*string_buf_ptr = 0;
			if(cool_yylval.error_msg != 0) return ERROR;
			cool_yylval.symbol = stringtable.add_string(string_buf);
			return STR_CONST;
		}
		if( cur != '\\' || (cur == '\\' && previous == '\\'))
			*string_buf_ptr++ = cur;
		if( previous == '\\' && cur == '\\' )	
			previous = '#';
		else
			previous = cur;
	}
	cool_yylval.error_msg = "EOF in string constant";
	return ERROR;
}

. { 
	cool_yylval.error_msg = yytext;
	return ERROR;
}

%%
