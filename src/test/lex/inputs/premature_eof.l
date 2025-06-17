ws    [ \t]
nonws [^ \t\n]
word  {ws}*{nonws}+
words {word}{ws}+

%{
	var cc: usize = 0;
	var wc: usize = 0;
	var lc: usize = 0;
%}

	const stdoutW = stdout.writer();

%%

[a-zA-Z]+		wc += 1; cc += yytext.len;

\n+			cc += yytext.len; lc += yytext.len;

%%

pub fn main() !u8 {
    var argIt = std.process.args();
    _ = argIt.skip();

    if (argIt.next()) |filename| {
        yyin = try std.fs.cwd().openFile(filename, .{});
    } else {
        yyin = stdin;
    }
	yyout = stdout;
    _ = try yylex();
	try stdoutW.print( "{d:8} {d:8} {d:8}\n", .{lc, wc, cc} );

    return 0;
}

