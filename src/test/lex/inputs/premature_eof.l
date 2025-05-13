DIGIT    [0-9]
ID       [a-z][a-z0-9]*

%x YOANN

%%


{DIGIT}+ printf("hello world\n");

[a-z]+ printf("salut !\n");
