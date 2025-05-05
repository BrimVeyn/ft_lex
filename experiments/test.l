DIGIT [0-9]\ d

al [0-9]

%%

[0-9]\		
		
"if"				|		
"then" |
"else" printf("hello !");

"some" {
	printf("some\n");

	if (yytext == 0) {
		printf("salope");
	}
}

[0-9 ]\	d printf("salut !\n");

%%

printf("Hello\n");
