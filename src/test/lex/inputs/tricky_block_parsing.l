%%

"complex" {
    printf("Opening {string { with \\"nested\\" braces }\n");

    const char *s = "String with \\"escaped\\" quotes and {{braces}}";
    char c = '}'; // character literal

    /*
    Comment block with fake code:
    if (x == 0) {
        printf("Inside a comment block with braces { and quotes \" }");
    }
    */

    // Comment with escaped newline \
    still part of the comment }

    // "Unclosed quote inside comment {
    const char *weird = "Nested \"string { in string\" still going }";

    {
        {
            if (1) {
                printf("{nested} blocks all the way { down }");
            }
        }
    }

    const char *str = "Escaped backslash before quote: \\\\\" still in string";

    #define TRICKY() do { \
        printf("Inside macro with braces { and } and \\\"string\\\""); \
    } while(0)

    TRICKY();

    #define MACRO(x) { printf(#x); } // Braces inside macro def
    MACRO("String inside macro with { and }");

    printf("Multiline string: \
	still going on next line with brace { and end }");
}

"comment_mess" {
    /*
    Comment with "fake" string and \
    multi-line continuation with backslash \\
    and ending */ printf("Did we exit?");
}

"nested_block" {
    // Block inside a block
    {
        {
            {
                if (1) {
                    printf("{Deep nesting level}");
                }
            }
        }
    }
}

"char_edge_case" {
    char c1 = '\'';   // char with escaped quote
    char c2 = '\\';   // backslash
    char c3 = '}';    // lone brace
    char c4 = '{';    // lone opening
    printf("Characters that can confuse a parser");
}

"backslash_madness" {
    const char *str = "Line with \\\n new line escape";
    // backslash that escapes the next quote: \" and backslash itself: \\
    const char *escaped = "\\\\\\";

    printf("Brace in string: { and } and more: \\\\\"");
}

"evil_string_combo" {
    const char *s = "Quote \\\" inside another \\\"quote\\\" with brace: }";
    const char *t = "End \\";
    printf("Can you still match braces?");
}

"macro_mess" {
    #define IF(x) if (x) { \
        printf("macro with { brace"); \
    }

    IF(1)
}

"misleading_literals" {
    // '}' looks like brace
    // '"' looks like string
    // \\\" looks like an escape
    // None of them are real in a comment
}

"fake_out" {
    char *trick = "End of string with comment symbol: // not a comment";
    char *deeper = "Another /* not a comment block */ really";
    printf("End }");
}
