
	int func(void);

%%

abc func();

def {
	printf("salut !\n");
}


%%

int func(void) {
	yymore();
	return 1;
}
