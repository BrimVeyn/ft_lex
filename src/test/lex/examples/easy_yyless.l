%{

#include <stdio.h>

enum {
	END,
	HELLOPLUS,
	HELLO,
};

char *printToken(int n);

%}

%%
"hello"[A-Za-z]+   {
	printf("Matched: \"%s\" initially\n", yytext);
	// If the input starts with "hello" followed by letters, but we only want "hello"
	// put the rest back by backing off to the end of "hello"
	yyless(5); // "hello" has 5 characters
	printf("Matched: \"%s\"\n", yytext);
	return 1;
}

"hello"         { 
	printf("Matched \"hello\"\n");
	return 2;
}

.|\n            { ECHO; }

%%

char *printToken(int n) {
	switch (n) {
		case HELLOPLUS: return "HELLOPLUS";
		case HELLO: return "HELLO";
		default: return "UNKNOWN";
	}
}

int main(void) {
    int token;
    while ((token = yylex())) {
        printf("Token: %s\n", printToken(token));
    }
    return 0;
}

