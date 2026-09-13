bind_socket = "*:11332";

# Deny privileged File/Path/Shm message inputs: the worker binds a
# non-loopback TCP socket, so any client reaching it could otherwise make
# rspamd read arbitrary files readable by the rspamd user. Nothing here
# uses those inputs (postfix talks milter, rspamc streams on stdin).
# Defaults to true in rspamd 4.1.x and to false in the next major release.
allow_file_and_shm_inputs = false;

upstream "local" {
  self_scan = yes;
}
