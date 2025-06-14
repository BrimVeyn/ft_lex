%x SOME OTHER
%s SKIP

%%

^hello$ {
	printf("Exact line: hello\n");
}

^world/abc {
	printf("world at BOL followed by abc\n");
}

foo+/bar {
	printf("foo+ followed by bar\n");
}

"switch" {
	BEGIN(SOME);
}

<INITIAL>"skip" {
	BEGIN(SKIP);
}

<SKIP>[ \t\n]+ {
	// Ignore whitespace
}

<SKIP>"resume" {
	BEGIN(INITIAL);
}

<SOME>"to_other" {
	BEGIN(OTHER);
}

<OTHER>"to_some" {
	BEGIN(SOME);
}

<SOME>baz/qux {
	printf("baz with trailing context qux in SOME\n");
}

<OTHER>^quux/quuz {
	printf("quux at BOL with trailing quuz in OTHER\n");
}

"end"/(xyz)+ {
	printf("end followed by xyz+\n");
}

<SOME>^"start"/"middle" {
	printf("start at BOL with trailing middle in SOME\n");
}

"meta\+" {
	printf("Matched literal 'meta+'\n");
}

"\\escape" {
	printf("Matched literal '\\escape'\n");
}

.* {
	printf("OTHER: %s\n", yytext);
}

