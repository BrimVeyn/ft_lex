%e 1500
%n 1500


O   [0-7]
D   [0-9]
NZ  [1-9]
L   [a-zA-Z_]
A   [a-zA-Z_0-9]
H   [a-fA-F0-9]
HP  (0[xX])
E   ([Ee][+-]?{D}+)
P   ([Pp][+-]?{D}+)
FS  (f|F|l|L)
IS  (((u|U)(l|L|ll|LL)?)|((l|L|ll|LL)(u|U)?))
CP  (u|U|L)
SP  (u8|u|U|L)
ES  (\\(['"\?\\abfnrtv]|[0-7]{1,3}|x[a-fA-F0-9]+))
WS  [ \t\v\n\f]

%{
#include <stdio.h>

%}

%%

"auto"					{ printf("AUTO\n"); }
"break"					{ printf("BREAK\n"); }
"case"					{ printf("CASE\n"); }
"char"					{ printf("CHAR\n"); }
"const"					{ printf("CONST\n"); }
"continue"				{ printf("CONTINUE\n"); }
"default"				{ printf("DEFAULT\n"); }
"do"					{ printf("DO\n"); }
"double"				{ printf("DOUBLE\n"); }
"else"					{ printf("ELSE\n"); }
"enum"					{ printf("ENUM\n"); }
"extern"				{ printf("EXTERN\n"); }
"float"					{ printf("FLOAT\n"); }
"for"					{ printf("FOR\n"); }
"goto"					{ printf("GOTO\n"); }
"if"					{ printf("IF\n"); }
"inline"				{ printf("INLINE\n"); }
"int"					{ printf("INT\n"); }
"long"					{ printf("LONG\n"); }
"register"				{ printf("REGISTER\n"); }
"restrict"				{ printf("RESTRICT\n"); }
"return"				{ printf("RETURN\n"); }
"short"					{ printf("SHORT\n"); }
"signed"				{ printf("SIGNED\n"); }
"sizeof"				{ printf("SIZEOF\n"); }
"static"				{ printf("STATIC\n"); }
"struct"				{ printf("STRUCT\n"); }
"switch"				{ printf("SWITCH\n"); }
"typedef"				{ printf("TYPEDEF\n"); }
"union"					{ printf("UNION\n"); }
"unsigned"				{ printf("UNSIGNED\n"); }
"void"					{ printf("VOID\n"); }
"volatile"				{ printf("VOLATILE\n"); }
"while"					{ printf("WHILE\n"); }
"_Alignas"                              { printf("ALIGNAS\n"); }
"_Alignof"                              { printf("ALIGNOF\n"); }
"_Atomic"                               { printf("ATOMIC\n"); }
"_Bool"                                 { printf("BOOL\n"); }
"_Complex"                              { printf("COMPLEX\n"); }
"_Generic"                              { printf("GENERIC\n"); }
"_Imaginary"                            { printf("IMAGINARY\n"); }
"_Noreturn"                             { printf("NORETURN\n"); }
"_Static_assert"                        { printf("STATIC_ASSERT\n"); }
"_Thread_local"                         { printf("THREAD_LOCAL\n"); }
"__func__"                              { printf("FUNC_NAME\n"); }

{L}{A}*					{ printf("check_type()\n"); }

{HP}{H}+{IS}?				{ printf("I_CONSTANT\n"); }
{NZ}{D}*{IS}?				{ printf("I_CONSTANT\n"); }
"0"{O}*{IS}?				{ printf("I_CONSTANT\n"); }
{CP}?"'"([^'\\\n]|{ES})+"'"		{ printf("I_CONSTANT\n"); }

{D}+{E}{FS}?				{ printf("F_CONSTANT\n"); }
{D}*"."{D}+{E}?{FS}?			{ printf("F_CONSTANT\n"); }
{D}+"."{E}?{FS}?			{ printf("F_CONSTANT\n"); }
{HP}{H}+{P}{FS}?			{ printf("F_CONSTANT\n"); }
{HP}{H}*"."{H}+{P}{FS}?			{ printf("F_CONSTANT\n"); }
{HP}{H}+"."{P}{FS}?			{ printf("F_CONSTANT\n"); }

({SP}?\"([^"\\\n]|{ES})*\"{WS}*)+	{ printf("STRING_LITERAL\n"); }

"..."					{ printf("ELLIPSIS\n"); }
">>="					{ printf("RIGHT_ASSIGN\n"); }
"<<="					{ printf("LEFT_ASSIGN\n"); }
"+="					{ printf("ADD_ASSIGN\n"); }
"-="					{ printf("SUB_ASSIGN\n"); }
"*="					{ printf("MUL_ASSIGN\n"); }
"/="					{ printf("DIV_ASSIGN\n"); }
"%="					{ printf("MOD_ASSIGN\n"); }
"&="					{ printf("AND_ASSIGN\n"); }
"^="					{ printf("XOR_ASSIGN\n"); }
"|="					{ printf("OR_ASSIGN\n"); }
">>"					{ printf("RIGHT_OP\n"); }
"<<"					{ printf("LEFT_OP\n"); }
"++"					{ printf("INC_OP\n"); }
"--"					{ printf("DEC_OP\n"); }
"->"					{ printf("PTR_OP\n"); }
"&&"					{ printf("AND_OP\n"); }
"||"					{ printf("OR_OP\n"); }
"<="					{ printf("LE_OP\n"); }
">="					{ printf("GE_OP\n"); }
"=="					{ printf("EQ_OP\n"); }
"!="					{ printf("NE_OP\n"); }
";"					{ printf("';'\n"); }
("{"|"<%")				{ printf("'{'\n"); }
("}"|"%>")				{ printf("'}'\n"); }
","					{ printf("','\n"); }
":"					{ printf("':'\n"); }
"="					{ printf("'='\n"); }
"("					{ printf("'('\n"); }
")"					{ printf("')'\n"); }
("["|"<:")				{ printf("'['\n"); }
("]"|":>")				{ printf("']'\n"); }
"."					{ printf("'.'\n"); }
"&"					{ printf("'&'\n"); }
"!"					{ printf("'!'\n"); }
"~"					{ printf("'~'\n"); }
"-"					{ printf("'-'\n"); }
"+"					{ printf("'+'\n"); }
"*"					{ printf("'*'\n"); }
"/"					{ printf("'/'\n"); }
"%"					{ printf("'%%'\n"); }
"<"					{ printf("'<'\n"); }
">"					{ printf("'>'\n"); }
"^"					{ printf("'^'\n"); }
"|"					{ printf("'|'\n"); }
"?"					{ printf("'?'\n"); }

{WS}+					{ /* whitespace separates tokens */ }
.					{ /* discard bad characters */ }



