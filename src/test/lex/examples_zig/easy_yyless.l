%{


const Token = enum(usize) {
	END,
	HELLOPLUS,
	HELLO,
};

%}

	const stdoutW = stdout.writer();

%%
"hello"[A-Za-z]+   {
	try stdoutW.print("Matched: \"{s}\" initially\n", .{yytext});
	// If the input starts with "hello" followed by letters, but we only want "hello"
	// put the rest back by backing off to the end of "hello"
	yyless(5); // "hello" has 5 characters
	try stdoutW.print("Matched: \"{s}\"\n", .{yytext});
	return @intFromEnum(Token.HELLOPLUS);
}

"hello"         { 
	try stdoutW.print("Matched \"hello\"\n", .{});
	return @intFromEnum(Token.HELLO);
}

.|\n            { ECHO(); }

%%

fn printToken(n: Token) []const u8 {
	switch (n) {
		.HELLOPLUS => return "HELLOPLUS",
		.HELLO => return "HELLO",
		else => return "UNKNOWN",
	}
}

pub fn main() !u8 {
    var token: Token = undefined;
    while (true) {
		token = @enumFromInt(try yylex());
		if (token == .END) break;
        try stdoutW.print("Token: {s}\n", .{printToken(token)});
    }
    return 0;
}
