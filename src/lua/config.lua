-- Voix Configuration File
-- This file defines who can run commands with elevated privileges.
-- By default, commands will run as the current user.

return {
  -- List of users who can run commands with elevated privileges
  users = {
    "root",
    "dae"
  },

  -- List of groups whose members can run commands with elevated privileges
  groups = {
    "wheel",
    "admin"
  },

  -- Maximum number of authentication attempts
  max_auth_attempts = 3
}
