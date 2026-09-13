#!/usr/bin/env python3
"""Replay an SMTP dialogue from a file, one command at a time.

The fixtures used to be piped straight into nc/openssl, which sends every
command without waiting for the server's replies. Postfix rejects that as
unauthorised pipelining (smtpd_forbid_unauth_pipelining, on by default since
postfix 3.9) with "554 5.5.0 Error: SMTP protocol synchronization", so no mail
was accepted at all. This reads each reply before sending the next command.

The exit status reflects whether the dialogue could be started, not whether the
server accepted the mail: several fixtures deliberately test a rejection, and
postfix ends those dialogues by hanging up.
"""
import argparse
import socket
import ssl
import sys

TIMEOUT = 30
HANGUP = (BrokenPipeError, ConnectionResetError, ssl.SSLEOFError, ssl.SSLZeroReturnError)


class Hangup(Exception):
    """The server ended the dialogue."""


def log(prefix, text):
    print(f"{prefix} {text}")
    sys.stdout.flush()


class Dialogue:
    def __init__(self, host, port):
        self.sock = socket.create_connection((host, port), TIMEOUT)
        self.sock.settimeout(TIMEOUT)
        self.f = self.sock.makefile("rb")
        self.host = host

    def read_reply(self):
        """Read one SMTP reply, following multi-line continuations."""
        last = ""
        while True:
            try:
                line = self.f.readline()
            except HANGUP as exc:
                raise Hangup(str(exc)) from exc
            if not line:
                raise Hangup("connection closed")
            last = line.rstrip(b"\r\n").decode("utf-8", "replace")
            log("S:", last)
            # a space in the fourth column marks the final line of a reply
            if len(last) < 4 or last[3] == " ":
                return last

    def send(self, line, expect_reply=True):
        log("C:", line)
        try:
            self.sock.sendall(line.encode() + b"\r\n")
        except HANGUP as exc:
            raise Hangup(str(exc)) from exc
        return self.read_reply() if expect_reply else None

    def wrap_tls(self):
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        self.sock = ctx.wrap_socket(self.sock, server_hostname=self.host)
        self.sock.settimeout(TIMEOUT)
        self.f = self.sock.makefile("rb")

    def starttls(self):
        self.send("EHLO smtp-send")
        self.send("STARTTLS")
        self.wrap_tls()

    def replay(self, lines):
        i, in_data = 0, False
        while i < len(lines):
            line = lines[i]
            if in_data:
                # inside DATA the server stays silent until the terminating dot
                self.send(line, expect_reply=False)
                if line == ".":
                    self.read_reply()
                    in_data = False
            else:
                reply = self.send(line)
                if line.upper().startswith("DATA"):
                    if reply.startswith("354"):
                        in_data = True
                    else:
                        # DATA refused (a fixture testing a rejection): skip the
                        # body instead of sending it as commands, which would
                        # trip the server's error limit
                        while i + 1 < len(lines) and lines[i + 1] != ".":
                            i += 1
                        i += 1
            i += 1

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("host")
    ap.add_argument("port", type=int)
    ap.add_argument("dialogue")
    ap.add_argument("--starttls", action="store_true",
                    help="negotiate TLS with STARTTLS before the dialogue")
    ap.add_argument("--tls", action="store_true",
                    help="wrap the connection in TLS immediately (smtps)")
    args = ap.parse_args()

    with open(args.dialogue, "rb") as fh:
        lines = [l.rstrip(b"\r\n").decode("utf-8", "replace")
                 for l in fh.read().split(b"\n")]
    while lines and lines[-1] == "":
        lines.pop()

    d = Dialogue(args.host, args.port)
    try:
        if args.tls:
            d.wrap_tls()
        d.read_reply()                 # 220 greeting
        if args.starttls:
            d.starttls()
        d.replay(lines)
    except Hangup as exc:
        log("S:", f"<server ended the dialogue: {exc}>")
    finally:
        d.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
