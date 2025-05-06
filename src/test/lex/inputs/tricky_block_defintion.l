%{
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

%}

%%
