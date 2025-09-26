#include "include/env.hpp"
#include <cstring>

extern char **environ;

void scrub_env() {
    const char* keep[] = {"DISPLAY", "TERM", nullptr};
    for (char** env = environ; *env; ++env) {
        bool safe = false;
        for (const char** k = keep; *k; ++k) {
            if (strncmp(*env, *k, strlen(*k)) == 0) {
                safe = true;
                break;
            }
        }
        if (!safe) {
            // Note: This is a simplification. A real implementation
            // would need to be more careful about modifying environ.
            *env = (char*)"";
        }
    }
}
