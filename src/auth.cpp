#include "include/auth.hpp"
#include "include/logging.hpp"
#include "include/password.hpp"
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <grp.h>
#include <iostream>
#include <pwd.h>
#include <security/pam_appl.h>
#include <security/pam_misc.h>
#include <unistd.h>
#include <vector>
#include <cerrno>

// Data structure to pass user credentials to the PAM conversation function
struct PamAuthData {
  const std::string *password;
};

// Secure PAM conversation function with proper memory management
static int pam_conv_func(int num_msg, const struct pam_message **msg,
                         struct pam_response **resp, void *appdata_ptr) {
  if (num_msg <= 0 || num_msg > 16 || !appdata_ptr) {
    return PAM_CONV_ERR;
  }

  *resp = static_cast<struct pam_response *>(
      calloc(static_cast<size_t>(num_msg), sizeof(struct pam_response)));
  if (!*resp) {
    return PAM_BUF_ERR;
  }

  auto *data = static_cast<PamAuthData *>(appdata_ptr);
  if (!data || !data->password) {
    free(*resp);
    *resp = nullptr;
    return PAM_CONV_ERR;
  }

  for (int i = 0; i < num_msg; ++i) {
    // Initialize response to prevent uninitialized memory
    (*resp)[i].resp = nullptr;
    (*resp)[i].resp_retcode = 0;

    if (!msg[i]) {
      // Clean up previous responses
      for (int j = 0; j < i; ++j) {
        free((*resp)[j].resp);
      }
      free(*resp);
      *resp = nullptr;
      return PAM_CONV_ERR;
    }

    if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF) {
      // Validate password length
      const std::string& password = *data->password;
      if (password.length() > 1024) {
        for (int j = 0; j < i; ++j) {
          free((*resp)[j].resp);
        }
        free(*resp);
        *resp = nullptr;
        return PAM_CONV_ERR;
      }

      char *pass_dup = strdup(password.c_str());
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
    // Handle other message types if needed (currently ignore them)
  }
  return PAM_SUCCESS;
}

// Enhanced user authentication with comprehensive error handling
bool authenticate_user(const std::string &username, const std::string &password,
                       const Config &config) {
  // Input validation
  if (username.empty() || username.length() > 256 ||
      password.length() > 1024) {
    log_message(3, "AUTH_INVALID_INPUT user=" + username, config.log_file, false);
    return false;
  }

  PamAuthData auth_data{&password};
  struct pam_conv conv = {pam_conv_func, &auth_data};
  pam_handle_t *pamh = nullptr;

  int ret = pam_start("voix", username.c_str(), &conv, &pamh);
  if (ret != PAM_SUCCESS) {
    const char *error_msg = (pamh ? pam_strerror(pamh, ret) : "Unknown PAM error");
    log_message(3, "PAM initialization failed for user " + username + ": " + error_msg, config.log_file, false);
    if (pamh) {
      pam_end(pamh, ret);
    }
    return false;
  }

  // Set PAM flags for better security
  ret = pam_set_item(pamh, PAM_TTY, "voix");
  if (ret != PAM_SUCCESS) {
    log_message(3, "PAM TTY set failed for user " + username, config.log_file, false);
    pam_end(pamh, ret);
    return false;
  }

  // Authenticate user with secure flags
  ret = pam_authenticate(pamh, PAM_DISALLOW_NULL_AUTHTOK);
  if (ret != PAM_SUCCESS) {
    const char *error_msg = pam_strerror(pamh, ret);
    std::string error_prefix = "PAM authentication failed for user " + username + ": ";

    switch (ret) {
      case PAM_USER_UNKNOWN:
        error_prefix += "user unknown";
        break;
      case PAM_MAXTRIES:
        error_prefix += "max attempts exceeded";
        break;
      case PAM_ABORT:
        error_prefix += "abort called";
        break;
      default:
        error_prefix += "authentication error";
        break;
    }

    log_message(4, error_prefix, config.log_file, false);
    pam_end(pamh, ret);
    return false;
  }

  // Check account management
  ret = pam_acct_mgmt(pamh, PAM_DISALLOW_NULL_AUTHTOK);
  if (ret != PAM_SUCCESS) {
    std::string error_msg = "PAM account management failed for user " + username + ": ";
    if (ret == PAM_NEW_AUTHTOK_REQD) {
      error_msg += "new authentication token required";
    } else if (ret == PAM_ACCT_EXPIRED) {
      error_msg += "account expired";
    } else {
      error_msg += "account management error";
    }
    log_message(4, error_msg, config.log_file, false);
    pam_end(pamh, ret);
    return false;
  }

  // Set credentials
  ret = pam_setcred(pamh, PAM_ESTABLISH_CRED);
  if (ret != PAM_SUCCESS) {
    log_message(4, "PAM credential setting failed for user " + username, config.log_file, false);
    pam_end(pamh, ret);
    return false;
  }

  log_message(6, "PAM authentication successful for user " + username, config.log_file, true);
  pam_end(pamh, ret);
  return true;
}

// Secure group membership check with bounds checking
static bool is_user_in_system_group(const std::string &user, const std::string &group) {
  if (user.empty() || group.empty() || group.length() > 256) {
    return false;
  }

  struct passwd *pw = getpwnam(user.c_str());
  if (!pw || !pw->pw_name) {
    return false;
  }

  int ngroups = 0;
  if (getgrouplist(user.c_str(), pw->pw_gid, nullptr, &ngroups) <= 0) {
    return false;
  }

  // Limit group list size to prevent DoS
  ngroups = std::min(ngroups, 128);

  std::vector<gid_t> groups(ngroups);
  int actual_ngroups = ngroups;
  if (getgrouplist(user.c_str(), pw->pw_gid, groups.data(), &actual_ngroups) <= 0) {
    return false;
  }

  for (int i = 0; i < actual_ngroups; ++i) {
    struct group *gr = getgrgid(groups[i]);
    if (gr && gr->gr_name && group == gr->gr_name) {
      return true;
    }
  }
  return false;
}

// Enhanced permission checking with security validation
bool check_permissions(const std::string &username, const Config &config) {
  if (username.empty() || username.length() > 256) {
    return false;
  }

  // Check if user is in the allowed users list
  if (std::find(config.users.begin(), config.users.end(), username) !=
      config.users.end()) {
    return true;
  }

  // Check if user is in any of the allowed groups
  for (const auto &group : config.groups) {
    if (!group.empty() && group.length() <= 256) {
      if (is_user_in_system_group(username, group)) {
        return true;
      }
    }
  }

  return false;
}

// Enhanced privilege escalation with comprehensive error handling
bool authenticate_and_escalate(const std::string &username,
                               const Config &config) {
  if (username.empty() || username.length() > 256) {
    log_message(4, "AUTH_INVALID_USER user=" + username, config.log_file, false);
    return false;
  }

  if (!check_permissions(username, config)) {
    log_message(4, "DENY user=" + username + " reason=not_authorized", config.log_file, false);
    std::cout << username << " is not authorized to use Voix." << std::endl;
    return false;
  }

  // Get actual UID before escalation for logging
  uid_t original_uid = getuid();
  gid_t original_gid = getgid();

  for (int i = 0; i < config.max_auth_attempts; ++i) {
    std::string password = get_password();

    // Validate password input
    if (password.empty()) {
      if (i < config.max_auth_attempts - 1) {
        std::cerr << "Password cannot be empty. Please try again." << std::endl;
      }
      continue;
    }

    if (password.length() > 1024) {
      std::cerr << "Password too long. Please try again." << std::endl;
      continue;
    }

    if (authenticate_user(username, password, config)) {
      // Test privilege escalation
      if (setuid(0) != 0) {
        log_message(3, "SEUIDFAIL user=" + username + " original_uid=" +
                  std::to_string(original_uid), config.log_file, false);
        std::cerr << "Failed to escalate privileges." << std::endl;
        return false;
      }

      // Verify we actually have root privileges
      if (geteuid() != 0) {
        log_message(3, "SEUIDVERIFYFAIL user=" + username + " euid=" +
                  std::to_string(geteuid()), config.log_file, false);
        std::cerr << "Privilege escalation verification failed." << std::endl;
        return false;
      }

      log_message(6, "SEUIDSUCCESS user=" + username + " from_uid=" +
                std::to_string(original_uid) + " from_gid=" +
                std::to_string(original_gid), config.log_file, true);
      return true;
    }

    // Clear password from memory
    std::fill(password.begin(), password.end(), '\0');

    if (i < config.max_auth_attempts - 1) {
      std::cerr << "Authentication failed, please try again." << std::endl;
    }
  }

  log_message(4, "AUTHFAIL user=" + username + " reason=max_attempts", config.log_file, false);
  std::cerr << "Too many authentication failures. Access denied." << std::endl;
  return false;
}
