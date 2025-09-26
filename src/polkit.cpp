#include "include/polkit.hpp"
#include <iostream>
#include <cstring>

// Polkit integration for GUI environments
#ifdef HAVE_POLKIT
#include <polkit/polkit.h>
#include <gio/gio.h>
#endif

// Polkit authentication function for GUI environments
#ifdef HAVE_POLKIT
bool check_polkit_auth(const std::string& action_id, const std::string& cmd) {
    GError *error = nullptr;
    PolkitAuthority *authority = polkit_authority_get_sync(nullptr, nullptr);
    if (!authority) {
        std::cerr << "Warning: Cannot connect to Polkit authority, falling back to PAM" << std::endl;
        return false;
    }

    // Use the new API instead of deprecated polkit_unix_process_new
    PolkitSubject *subject = polkit_unix_process_new_for_owner(getpid(), 0, -1);
    if (!subject) {
        g_object_unref(authority);
        std::cerr << "Warning: Cannot create Polkit subject, falling back to PAM" << std::endl;
        return false;
    }

    // Create details with command information
    PolkitDetails *details = polkit_details_new();
    polkit_details_insert(details, "command", cmd.c_str());

    PolkitAuthorizationResult *result = polkit_authority_check_authorization_sync(
        authority, subject, action_id.c_str(), details,
        POLKIT_CHECK_AUTHORIZATION_FLAGS_ALLOW_USER_INTERACTION,
        nullptr, &error);

    if (error) {
        std::cerr << "Warning: Polkit authorization failed: " << error->message << std::endl;
        g_error_free(error);
        g_object_unref(details);
        g_object_unref(subject);
        g_object_unref(authority);
        return false;
    }

    bool authorized = polkit_authorization_result_get_is_authorized(result);
    g_object_unref(result);
    g_object_unref(details);
    g_object_unref(subject);
    g_object_unref(authority);

    return authorized;
}
#else
bool check_polkit_auth(const std::string& action_id, const std::string& cmd) {
    std::cerr << "Warning: Polkit not available, falling back to PAM" << std::endl;
    return false;
}
#endif

// Check if we're in a GUI environment
bool is_gui_environment() {
    const char* session_type = getenv("XDG_SESSION_TYPE");
    if (session_type && strcmp(session_type, "tty") != 0) {
        return true; // X11, Wayland, etc.
    }

    const char* display = getenv("DISPLAY");
    if (display && strlen(display) > 0) {
        return true; // X11
    }

    const char* wayland_display = getenv("WAYLAND_DISPLAY");
    if (wayland_display && strlen(wayland_display) > 0) {
        return true; // Wayland
    }

    return false;
}
