%x FIRST SECOND

%%

"start_first" {
	printf("Entering FIRST condition");
	BEGIN(FIRST);
}

"start_second" {
	printf("Entering SECOND condition");
	BEGIN(SECOND);
}

<FIRST,SECOND>"exit" {
	printf("exiting start condition");
	BEGIN(INITIAL);
}
