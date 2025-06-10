%{
#include <stdio.h>
#include <string.h>

void debug_print(const char* msg);
%}

%%
    /* TEST 1: Basic unput chain */
"unput_chain" {
    debug_print("\nTEST 1: Basic unput chain");
    unput('A');
    unput('B');
    unput('C');
    int c;
    while ((c = input()) != 0) {
        printf("Read: %c\n", c);
    }
}

    /* TEST 2: Nested input/unput */
"nested_test" {
    debug_print("\nTEST 2: Nested input/unput");
    int c1 = input();
    printf("Read1: %c\n", c1);
    
    unput('X');
    unput(c1);
    
    int c2 = input();
    printf("Read2: %c\n", c2);
    int c3 = input();
    printf("Read3: %c\n", c3);
}

    /* TEST 3: Buffer boundary */
"buffer_boundary" {
    debug_print("\nTEST 3: Buffer boundary");
    // Fill buffer
    for (int i = 0; i < 10; i++) {
        unput('0' + i);
    }
    // Read back
    int c;
    while ((c = input()) != 0) {
        printf("%c", c);
    }
    printf("\n");
}

    /* TEST 4: Mixed operations */
"mixed_ops" {
    debug_print("\nTEST 4: Mixed operations");
    unput('D');
    input();  // Should read D
    unput('E');
    unput('F');
    input();  // Should read F
    input();  // Should read E
}

    /* TEST 5: Empty unput */
"empty_unput" {
    debug_print("\nTEST 5: Empty unput");
    unput(0);  // Should do nothing
    printf("After empty unput\n");
}

    /* TEST 6: Input at EOF */
"input_eof" {
    debug_print("\nTEST 6: Input at EOF");
    while (input() != 0) {
        // Exhaust input
    }
    printf("Reached EOF\n");
    unput('Z');
    printf("Read after EOF unput: %c\n", input());
}

    /* TEST 7: Multi-level unput */
"multi_unput" {
    debug_print("\nTEST 7: Multi-level unput");
    unput('1');
    input();  // Read 1
    unput('2');
    unput('3');
    input();  // Read 3
    unput('4');
    input();  // Read 4
    input();  // Read 2
}

    /* TEST 8: Interleaved unput */
"interleaved" {
    debug_print("\nTEST 8: Interleaved unput");
    printf("Read1: %c\n", input());
    unput('A');
    printf("Read2: %c\n", input());
    unput('B');
    unput('C');
    printf("Read3: %c\n", input());
    printf("Read4: %c\n", input());
    printf("Read5: %c\n", input());
}

.|\n    ; // Ignore other characters

%%

void debug_print(const char* msg) {
    printf("\n==================");
    printf("%s", msg);
    printf("==================\n");
}

int main() {
    yylex();
    return 0;
}
