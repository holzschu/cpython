#include <Python.h>
#include <pthread.h>
#include <stdio.h>

struct invocation {
    int argc;
    char **argv;
    int status;
    int completed;
};

static void *run_python(void *argument) {
    struct invocation *invocation = argument;
    thread_stdin = stdin;
    thread_stdout = stdout;
    thread_stderr = stderr;
    invocation->status = Py_BytesMain(invocation->argc, invocation->argv);
    invocation->completed = 1;
    return NULL;
}

int main(int argc, char **argv) {
    argv[0] = "python3";
    /* a-Shell starts each native command on a fresh thread. */
    for (int run = 0; run < 2; run++) {
        struct invocation invocation = {argc, argv, 1, 0};
        pthread_t thread;
        if (pthread_create(&thread, NULL, run_python, &invocation) != 0 ||
            pthread_join(thread, NULL) != 0 || !invocation.completed || invocation.status != 0) {
            return 1;
        }
    }
    puts("SCIENCE_REENTRY_PASSED");
    return 0;
}
