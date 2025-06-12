%%

(ab|cd){3}/def {
	yymore();
}

a {
	yymore();
}

b {
	printf("Matched: %s\n", yytext);
}
