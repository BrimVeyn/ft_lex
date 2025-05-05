
DIGIT [0-9]

ID [_a-zA-Z][_a-zA-Z0-9]*

%%

{ID}	printf("Salut !\n");

{DIGIT},{DIGIT}+	printf("Float !\n");
