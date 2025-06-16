%x FIRST SECOND

	const stdoutW = stdout.writer();

%%

"start_first" {
	try stdoutW.print("Entering FIRST condition", .{});
	BEGIN(.FIRST);
}

"start_second" {
	try stdoutW.print("Entering SECOND condition", .{});
	BEGIN(.SECOND);
}

<FIRST,SECOND>"exit" {
	try stdoutW.print("exiting start condition", .{});
	BEGIN(.INITIAL);
}

