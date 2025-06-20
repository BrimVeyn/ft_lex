%s s1 s2
%x x1 x2

%o 200000

DEFINE def*i?ne

	const stdoutW = stdout.writer();

%%

simple try stdoutW.print("simple", .{});return @intCast(yytext.len);

simple* {

	try stdoutW.print("simple*", .{});
	if (true) {
		return @intCast(yytext.len);
	}

}

(simple){2,4} try stdoutW.print("(simple){{2,4}}", .{}); return @intCast(yytext.len);

(aa|aaa)*aa		try stdoutW.print("(aa|aaa)*aa", .{});ECHO(); return @intCast(yytext.len);

alternative|ALTERNATIVE try stdoutW.print("alternative|ALTERNATIVE", .{}); return @intCast(yytext.len);

escaping\"\[\\\|\{\$ try stdoutW.print("escaping\\\"\\[\\\\\\|\\{{\\$", .{}); return @intCast(yytext.len);


^anchoring		try stdoutW.print("^anchoring", .{}); return @intCast(yytext.len);
anchoring		try stdoutW.print("anchoring", .{}); return @intCast(yytext.len);

^anchoring$		try stdoutW.print("^anchoring$", .{}); return @intCast(yytext.len);
anchoring$		try stdoutW.print("anchoring$", .{}); return @intCast(yytext.len);


"regex with"/\ trai*li*ng try stdoutW.print("\"regex with\"/trai*li*ng", .{}); return @intCast(yytext.len);

[]]*					try stdoutW.print("[]]*", .{}); return @intCast(yytext.len);

inverted[^ inverted]*	try stdoutW.print("inverted[^inverted]*", .{}); return @intCast(yytext.len);

class[[:digit:]]+		try stdoutW.print("class[[:digit:]]", .{}); return @intCast(yytext.len);

hex\x61*				try stdoutW.print("hex\x61*", .{}); return @intCast(yytext.len);

octa\154?\114?			try stdoutW.print("octa{c}?{c}?", .{'l', 'L'}); return @intCast(yytext.len);

{DEFINE}*				try stdoutW.print("{{DEFINE}}*", .{}); return @intCast(yytext.len);

switch_to_s1 BEGIN(.s1);

switch_to_x1 BEGIN(.x1);

<x1>switch_from_x1_to_INITIAL BEGIN(.INITIAL);

<s1>"state_specific" try stdoutW.print("<s1>\"state s1\"", .{}); return @intCast(yytext.len);

<s1>"state_specific"/with_trailing try stdoutW.print("<s1>\"state_specific\"/with_trailing", .{}); return @intCast(yytext.len);

<x1>"state_specific" try stdoutW.print("<x1>\"state s1\"", .{}); return @intCast(yytext.len);

<x1,INITIAL>"x1 or initial" try stdoutW.print("<x1,INITIAL>\"x1 or initial\"", .{}); return @intCast(yytext.len);

lexalternative	|
LEXALTERNATIVE 	try stdoutW.print("lexalternative | LEXALTERNATIVE", .{}); return @intCast(yytext.len);

A	{ 
	try stdoutW.print("A", .{});
	return @intCast(yytext.len);
}

AB	{ try stdoutW.print("AB", .{}); REJECT(); return @intCast(yytext.len); }

ABC try stdoutW.print("ABC", .{}); REJECT(); return @intCast(yytext.len);

BC	try stdoutW.print("BC", .{});return @intCast(yytext.len);

ab		unput('c'); yymore();try stdoutW.print("ab", .{});

cdfg	try stdoutW.print("cdfg", .{});return @intCast(yytext.len);

abcdefg yyless(4);try stdoutW.print("abcdefg", .{}); return @intCast(yytext.len);

efg	try stdoutW.print("cdef{c}", .{@as(u8, @intCast(input()))}); return @intCast(yytext.len);

.*	try stdoutW.print(".*", .{}); return @intCast(yytext.len);

%%

pub fn main() !u8 {
	while (true) {
		const ret = try yylex();
		if (ret == 0)
			break;
		try stdoutW.print(" ret: {d} yytext: [{s}]\n", .{ret, yytext});
	}
	return 0;
}
