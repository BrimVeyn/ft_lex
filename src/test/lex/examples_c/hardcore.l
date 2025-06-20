%s s1 s2
%x x1 x2

DEFINE def*i?ne

%{
#include <stdio.h>
#include <locale.h>
%}

%%

simple printf("simple");return yyleng;

simple* {

	printf("simple*");
	if (1) {
		return yyleng;
	}

}

(simple){2,4} printf("(simple){2,4}"); return yyleng;

(aa|aaa)*aa		printf("(aa|aaa)*aa");ECHO; return yyleng;

alternative|ALTERNATIVE printf("alternative|ALTERNATIVE"); return yyleng;

escaping\"\[\\\|\{\$ printf("escaping\\\"\\[\\\\\\|\\{\\$"); return yyleng;


^anchoring		printf("^anchoring"); return yyleng;
anchoring		printf("anchoring"); return yyleng;

^anchoring$		printf("^anchoring$"); return yyleng;
anchoring$		printf("anchoring$"); return yyleng;


"regex with"/\ trai*li*ng printf("\"regex with\"/trai*li*ng"); return yyleng;

[]]*					printf("[]]*"); return yyleng;

inverted[^ inverted]*	printf("inverted[^inverted]*"); return yyleng;

class[[:digit:]]+		printf("class[[:digit:]]"); return yyleng;

hex\x61*				printf("hex\x61*"); return yyleng;

octa\154?\114?			printf("octa\154?\114?"); return yyleng;

{DEFINE}*				printf("{DEFINE}*"); return yyleng;

switch_to_s1 BEGIN(s1);

switch_to_x1 BEGIN(x1);

<x1>switch_from_x1_to_INITIAL BEGIN(INITIAL);

<s1>"state_specific" printf("<s1>\"state s1\""); return yyleng;

<s1>"state_specific"/with_trailing printf("<s1>\"state_specific\"/with_trailing"); return yyleng;

<x1>"state_specific" printf("<x1>\"state s1\""); return yyleng;

<x1,INITIAL>"x1 or initial" printf("<x1,INITIAL>\"x1 or initial\""); return yyleng;

lexalternative	|
LEXALTERNATIVE 	printf("lexalternative | LEXALTERNATIVE"); return yyleng;

A	{
	printf("Matched A: %s\n", yytext);
	printf("A"); return yyleng;
}

AB	{ printf("AB"); REJECT; return yyleng; }

ABC printf("ABC"); REJECT; return yyleng;

BC	printf("BC");return yyleng;

ab		unput('c'); yymore();printf("ab");

cdfg	printf("cdfg");return yyleng;

abcdefg yyless(4);printf("abcdefg"); return yyleng;

efg	printf("cdef%c", input()); return yyleng;

.*	printf(".*"); return yyleng;

%%

char	**files;
int		file_number;

int main(int argc, char **argv)
{
	setlocale(LC_ALL, "C");
	files = argv + 1;
	file_number = argc - 1;
	yywrap();
	int ret;
	while ((ret = yylex()))
		printf(" ret: %d yytext: [%s]\n", ret, yytext);
}

int yywrap()
{
	if (file_number < 1)
		return 1;
	if (yyin)
		fclose(yyin);
	yyin = fopen(*files, "r");
	files++;
	file_number--;
	return 0;
}
