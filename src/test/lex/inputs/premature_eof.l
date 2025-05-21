%s INCLUSIVE
%x EXCLUSIVE

%%

a {
	printf("Begin inclusive cond\n");
	BEGIN(INCLUSIVE);
}

b {
	printf("Begin exclusive cond\n");
	BEGIN(EXCLUSIVE);
}

<INCLUSIVE>"exit"   { 
	printf("OUT OF INCLUSIVE");
	BEGIN(INITIAL);
}
<EXCLUSIVE>"exit"   {
	printf("OUT OF EXCLUSIVE");
	BEGIN(INITIAL);
}
