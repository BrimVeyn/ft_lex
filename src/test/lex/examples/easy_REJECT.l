%%

xyz { printf("Matched rule 1\n");  REJECT; }
xyz { printf("Matched rule 2\n"); REJECT; }
xyz  { printf("Matched rule 3\n"); }
.   ;

%%
