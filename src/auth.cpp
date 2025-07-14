#include "include/auth.hpp"
#include "include/utils.hpp"
#include <algorithm>
#include <iostream>
#include <cstring>
#include <grp.h>
#include <pwd.h>
#include <security/pam_appl.h>
#include <security/pam_misc.h>
#include <syslog.h>
#include <vector>

// Data structure to pass user credentials to the PAM conversation function
struct PamAuthData {
    const std::string *password;
};

// PAM conversation function
static int pam_conv_func(int num_msg, const struct pam_message **msg,
                         struct pam_response **resp, void *appdata_ptr) {
    if (num_msg <= 0 || !appdata_ptr) {
        return PAM_CONV_ERR;
    }

    *resp = static_cast<struct pam_response *>(calloc(num_msg, sizeof(struct pam_response)));
    if (!*resp) {
        return PAM_BUF_ERR;
    }

    auto *data = static_cast<PamAuthData *>(appdata_ptr);

    for (int i = 0; i < num_msg; ++i) {
        if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF) {
            char *pass_dup = strdup(data->password->c_str());
            if (!pass_dup) {
                for (int j = 0; j < i; ++j) {
                    free((*resp)[j].resp);
                }
                free(*resp);
                *resp = nullptr;
                return PAM_BUF_ERR;
            }
            (*resp)[i].resp = pass_dup;
        }
    }
    return PAM_SUCCESS;
}

bool authenticate_user(const std::string &username, const std::string &password, const Config &config) {
    PamAuthData auth_data{&password};
    struct pam_conv conv = {pam_conv_func, &auth_data};
    pam_handle_t *pamh = nullptr;

    int ret = pam_start("voix", username.c_str(), &conv, &pamh);
    if (ret != PAM_SUCCESS) {
        log_message(LOG_ERR, "PAM initialization failed: " + std::string(pam_strerror(pamh, ret)), config.log_file);
        if (pamh) pam_end(pamh, ret);
        return false;
    }

    ret = pam_authenticate(pamh, 0);
    if (ret != PAM_SUCCESS) {
        log_message(LOG_WARNING, "PAM authentication failed for user " + username + ": " + std::string(pam_strerror(pamh, ret)), config.log_file);
        pam_end(pamh, ret);
        return false;
    }

    ret = pam_acct_mgmt(pamh, 0);
    if (ret != PAM_SUCCESS) {
        log_message(LOG_WARNING, "PAM account management failed for user " + username + ": " + std::string(pam_strerror(pamh, ret)), config.log_file);
        pam_end(pamh, ret);
        return false;
    }

    log_message(LOG_INFO, "PAM authentication successful for user: " + username, config.log_file);
    pam_end(pamh, ret);
    return true;
}

// Helper function to check group membership
static bool is_user_in_system_group(const std::string &user, const std::string &group) {
    struct passwd *pw = getpwnam(user.c_str());
    if (!pw) return false;

    int ngroups = 0;
    getgrouplist(user.c_str(), pw->pw_gid, nullptr, &ngroups);
    if (ngroups <= 0) return false;

    std::vector<gid_t> groups(ngroups);
    getgrouplist(user.c_str(), pw->pw_gid, groups.data(), &ngroups);

    for (int i = 0; i < ngroups; ++i) {
        struct group *gr = getgrgid(groups[i]);
        if (gr && group == gr->gr_name) {
            return true;
        }
    }
    return false;
}

bool check_permissions(const std::string &username, const Config &config) {
    // Check if user is in the allowed users list
    if (std::find(config.users.begin(), config.users.end(), username) != config.users.end()) {
        return true;
    }

    // Check if user is in any of the allowed groups
    for (const auto &group : config.groups) {
        if (is_user_in_system_group(username, group)) {
            return true;
        }
    }

    return false;
}

bool authenticate_and_escalate(const std::string &username, const Config &config) {
    if (!check_permissions(username, config)) {
        log_message(LOG_WARNING, "DENY user=" + username, config.log_file);
        std::cout << username << " not allowed. Add to /etc/voix/config.lua if this was intentional." << std::endl;
        return false;
    }

    for (int i = 0; i < config.max_auth_attempts; ++i) {
        std::string password = get_password();
        if (authenticate_user(username, password, config)) {
            if (setuid(0) != 0) {
                log_message(LOG_ERR, "SEUIDFAIL user=" + username, config.log_file);
                std::cerr << "Failed to escalate privileges." << std::endl;
                return false;
            }
            return true;
        }
        if (i < config.max_auth_attempts - 1) {
            std::cerr << "Authentication failed, please try again." << std::endl;
        }
    }

    log_message(LOG_WARNING, "AUTHFAIL user=" + username + " reason=max_attempts", config.log_file);
    std::cerr << "Too many authentication failures." << std::endl;
    return false;
}
