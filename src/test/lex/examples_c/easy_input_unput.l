%%

"skip" {
	char c;
	while ((c = input()) != 0) {
		printf("Read char: %c\n", c);
	}
}


"add" {
	printf("Adding a word to the input stream\n");

	char *some_text = "Expresso";

	while (*some_text) {
		unput(*some_text++);
	}
}

