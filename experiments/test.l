%{
	#include "stdio.h"
%}

DIGIT [0-9]

%%

([0-9]     [0-9]) { printf("Salut c'est yoann \n"); }

. { printf("Unexcepcted character !\n"); }

%%
