
	const stdoutW = stdout.writer();
%%

"skip" {
	while (true) {
		const c = input();
		if (c == 0) 
			break;
		try stdoutW.print("Read char: {c}\n", .{@as(u8, @intCast(c))});
	}
}


"add" {
	try stdoutW.print("Adding a word to the input stream\n", .{});

	const some_text = "Expresso";

	for (some_text) |c| {
		unput(c);
	}
}


