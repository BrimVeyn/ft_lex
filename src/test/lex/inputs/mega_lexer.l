%{
#include <stdio.h>
%}

%%

"abstract"|"alignas"|"alignof"|"and"|"and_eq"|"asm"|"assert"|"atomic"|"auto"|"bitand"|"bitor" |
"bool"|"break"|"case"|"catch"|"char"|"char16_t"|"char32_t"|"class"|"compl"|"const"|"constexpr" |
"const_cast"|"continue"|"decltype"|"default"|"delete"|"do"|"double"|"dynamic_cast"|"else" |
"enum"|"explicit"|"export"|"extern"|"false"|"float"|"for"|"friend"|"goto"|"if"|"inline"|"int" |
"long"|"mutable"|"namespace"|"new"|"noexcept"|"not"|"not_eq"|"nullptr"|"operator"|"or"|"or_eq" |
"private"|"protected"|"public"|"register"|"reinterpret_cast"|"return"|"short"|"signed"|"sizeof" |
"static"|"static_assert"|"static_cast"|"struct"|"switch"|"template"|"this"|"thread_local" |
"throw"|"true"|"try"|"typedef"|"typeid"|"typename"|"union"|"unsigned"|"using"|"virtual"|"void" |
"volatile"|"wchar_t"|"while"|"xor"|"xor_eq"      { return KW; }

[_a-zA-Z][_a-zA-Z0-9]*                            { return IDENT; }

"0x"[0-9a-fA-F]+[uUlL]*                           { return HEXINT; }
"0b"[01]+                                         { return BININT; }
[0-9]+                                            { return INT; }
[0-9]+\.[0-9]*([eE][+-]?[0-9]+)?[fFlL]?            { return FLOAT; }

\"([^\"\\\n]|\\.)*\"                              { return STRING; }
\'([^\'\\\n]|\\.)\'                               { return CHAR; }

"//".*                                            { /* comment */ }
"/*"([^*]|\*[^/])*"*/"                            { /* block comment */ }

"=="|"!="|"<="|">="|"<"|">"|"="                   { return RELOP; }
"\+"|"-"|"*"|"/"|"%"|"++"|"--"                    { return ARITHOP; }
"&"|"&&"|"|"|"||"|"^"|"~"                         { return BITOP; }
"<<"|">>"|"<<="|">>="                             { return SHIFTOP; }

"::"|":"|","|";"|"."|"..."                        { return PUNCT; }
"->"|"->*"|"."|"->"|"=>"                          { return ARROW; }

"("                                             { return LPAREN; }
")"                                             { return RPAREN; }
"{"                                             { return LBRACE; }
"}"                                             { return RBRACE; }
"["                                             { return LBRACK; }
"]"                                             { return RBRACK; }

[ \t\r\n]+                                       { /* skip whitespace */ }

"foo"|"foobar"|"foobarbaz"|"foobarbazqux"|"foo42"|"foo42bar"|"foo_bar"|"foo1bar2baz"|"f00_b4r"|"f__b__z"   { return IDENT; }

"aaaaaaaaaaaaaaaaaaaa"|"aaaabaaacaaadaaafaaagaaahaaai"                { return LONG_A; }
"baaaaaaaaaaaaaaaaaaaaaaa"|"bbaaaabbbbcccdddeeefffggghhhiijjkk"       { return LONG_B; }
"z(([a-z][0-9]?){10,20})+"                                             { return PATTERN_Z; }

"((((x)+)+)+)+y"                                                      { return NESTED_XY; }

([_a-zA-Z][_a-zA-Z0-9]*){100,120}                                     { return LONG_IDENT; }

(0[xX][0-9a-fA-F]+|[0-9]+(\.[0-9]*)?([eE][+-]?[0-9]+)?)[uUlL]*         { return COMPLEX_NUM; }

(abc|abd|abe|abf|abg|abh|abi|abj|abk|abl|abm|abn|abo|abp|abq|abr|abs|abt|abu|abv|abw|abx|aby|abz)  { return MANY_AB; }

.                                                                      { return UNKNOWN; }

%%
