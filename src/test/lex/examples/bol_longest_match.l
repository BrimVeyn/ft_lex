%%

^foobar {
	printf("Matched foobar at bol\n");
}

(foobar)+ {
	printf("Matched foobar+\n");
}
