%{
#include <stdio.h>
%}

%s COMMENT
%x BLOCK

%%

"//"             { BEGIN(COMMENT); }   // Enter COMMENT mode
<COMMENT>"\n"    { BEGIN(INITIAL); }   // Exit COMMENT mode

<COMMENT>"TODO:".* { printf("Found TODO!\n"); }

"[ab]"*			{ printf("Sob\n"); }
<BLOCK>"}"				{ printf("Eof\n"); BEGIN(INITIAL); }
<BLOCK>"const fn" { printf("Found a funnction"); }

[\422]+       { printf("Matched \\n\n"); }

.                { printf("OTHER: %s\n", yytext); }

%%

