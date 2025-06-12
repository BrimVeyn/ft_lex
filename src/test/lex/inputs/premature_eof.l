
	int func(void);

%%

abc{10000,20000}{20000} func();

abc/def {
	printf("salut !\n");
}


%%

int func(void) {
	return 1;
}
