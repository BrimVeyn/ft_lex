%{
#include <stdio.h>
#include <string.h>
%}

%%

fool/(ing|bar) {
	printf("matched foo followed by either ing or bar\n");
}

fooling+/bar {
	printf("matched fooling+ followed by bar\n");
}

.|\n                    { /* consume unknown */ }

%%
