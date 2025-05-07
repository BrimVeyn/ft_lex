DIGIT     [0-9]
LETTER    [a-zA-Z]
ALNUM     {LETTER}|{DIGIT}
PAIR      ab
TRIPLE    xyz
HEX       0x{DIGIT}+
ID        {LETTER}({LETTER}|{DIGIT})*
WS        [ \t]+
NEWLINE   \n
OP        (\+|\-|\*|\/)
CMP       (==|!=|<=|>=|<|>)

%%

(a|b)* printf("salut !\n");

(c|d)(c|d)* printf("fdp !\n");
