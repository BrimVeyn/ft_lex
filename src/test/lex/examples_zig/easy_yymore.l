%x STRING

	const stdoutW = stdout.writer();

%%
\"   BEGIN(.STRING);

<STRING>[^\\\n"]*  yymore();
<STRING>\n         try stdoutW.print("Unterminated string.", .{}); BEGIN(.INITIAL);
<STRING>\\\n      {
				     std.mem.copyBackwards(u8, yytext[2..], yytext[0..yytext.len - 2]);
					 yytext.len -= 2;
                     yymore();
                  }
<STRING>\"        {
					 yytext = yytext[0..yytext.len - 1];
                     try stdoutW.print("string = \"{s}\"", .{yytext});
					 BEGIN(.INITIAL);
                  }

%%
