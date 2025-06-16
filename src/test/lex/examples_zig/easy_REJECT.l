
	const stdoutW = stdout.writer();

%%

xyz { try stdoutW.print("Matched rule 1\n", .{});  REJECT(); }
xyz { try stdoutW.print("Matched rule 2\n", .{}); REJECT(); }
xyz  { try stdoutW.print("Matched rule 3\n", .{}); }
.   

%%

