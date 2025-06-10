%x SOME

%%

foobar$ {
	printf("foobar at eol\n");
}

foobar/(foobar)+ {
	printf("foobar/(foobar)+ matched\n");
}

"some" {
	BEGIN(SOME);
}

<SOME>"exit" {
	BEGIN(INITIAL);
}

<SOME>foobar/(foobar)+ {
	printf("<SOME> foobar/(foobar)+ matched\n");
}

<SOME>^foobar {
	printf("<SOME> foobar at bol\n");
}
