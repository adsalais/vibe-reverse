/* crackme1 — a tiny, safe license-check fixture (authored in-house, not malware).
 * The valid key is each username byte + 1. Used to test triage, static analysis,
 * and (later) a z3/angr solver. */
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc < 3) { printf("usage: %s <user> <key>\n", argv[0]); return 2; }
    char want[64] = {0};
    size_t n = strlen(argv[1]);
    if (n > 63) n = 63;
    for (size_t i = 0; i < n; i++) want[i] = (char)(argv[1][i] + 1);
    if (strcmp(want, argv[2]) == 0) { puts("Correct!"); return 0; }
    puts("Wrong.");
    return 1;
}
