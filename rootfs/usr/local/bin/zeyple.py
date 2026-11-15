#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from configparser import ConfigParser
import base64
import binascii
import copy
import email
import email.encoders
import email.mime.application
import email.mime.multipart
import email.mime.nonmultipart
import gpg
import logging
import os
import re
import smtplib
import subprocess
import sys
import tempfile


def encode_string(string):
    if isinstance(string, bytes):
        return string
    else:
        return string.encode('utf-8')


__title__ = 'Zeyple'
__version__ = '3.0.0'
__author__ = 'Cédric Félizard'
__license__ = 'AGPLv3+'
__copyright__ = 'Copyright 2012-2026 Cédric Félizard'
PGP_PREAMBLE = 'This is an OpenPGP/MIME encrypted message (RFC 4880 and 3156)'


def encrypted_packet_sequence(data):
    """Check complete OpenPGP packet framing; GnuPG validates the packet bodies."""
    offset = 0
    tags = []

    def read_integer(size):
        nonlocal offset
        if offset + size > len(data):
            raise ValueError('Truncated packet header')
        value = int.from_bytes(data[offset:offset + size], 'big')
        offset += size
        return value

    try:
        while offset < len(data):
            header = read_integer(1)
            if not header & 0x80:
                return False
            size = 0
            if header & 0x40:
                tag = header & 0x3f
                # New-format packets can have several partial-length chunks,
                # followed by a final chunk with a definite length (RFC 4880).
                while True:
                    length = read_integer(1)
                    partial = 224 <= length < 255
                    if length == 255:
                        length = read_integer(4)
                    elif partial:
                        length = 1 << (length & 0x1f)
                    elif length >= 192:
                        length = ((length - 192) << 8) + read_integer(1) + 192
                    if offset + length > len(data):
                        return False
                    offset += length
                    size += length
                    if not partial:
                        break
            else:
                tag = (header >> 2) & 0x0f
                length_type = header & 3
                size = len(data) - offset if length_type == 3 else read_integer(1 << length_type)
                if offset + size > len(data):
                    return False
                offset += size
            if not size:
                return False
            tags.append(tag)
    except ValueError:
        return False

    # Only session keys followed by one encrypted data packet are eligible.
    # Literal, compressed, signature and trailing packets must not bypass encryption.
    return len(tags) >= 2 and all(tag in (1, 3) for tag in tags[:-1]) and \
        tags[-1] in (9, 18, 20)


def strip_armor_headers(data):
    """Returns an ASCII-armored message without its armor headers, such as
    Comment, which are outside the ciphertext so they can hold plaintext"""
    lines = [line.strip() for line in data.strip().splitlines()]
    return b'\n'.join(lines[:1] + lines[lines.index(b''):]).decode('ascii') + '\n'


class Zeyple:
    """Zeyple Encrypts Your Precious Log Emails"""

    def __init__(self, config_fname='zeyple.conf'):
        self.config = self.load_configuration(config_fname)

        log_file = self.config.get('zeyple', 'log_file')
        logging.basicConfig(
            filename=log_file, level=logging.DEBUG,
            format='%(asctime)s %(process)s %(levelname)s %(message)s'
        )

        # raise now rather than when handling an error if the value is invalid
        self.force_encrypt

        logging.info("Zeyple ready to encrypt outgoing emails")

    def load_configuration(self, filename):
        """Reads and parses the config file"""

        config = ConfigParser()
        config.read([
            os.path.join('/etc/', filename),
            filename,
        ])
        if not config.sections():
            raise IOError('Cannot open config file.')
        return config

    @property
    def gpg(self):
        protocol = gpg.constants.PROTOCOL_OpenPGP

        if self.config.has_option('gpg', 'executable'):
            executable = self.config.get('gpg', 'executable')
        else:
            executable = None  # Default value

        home_dir = self.config.get('gpg', 'home')

        ctx = gpg.Context()
        ctx.set_engine_info(protocol, executable, home_dir)
        ctx.armor = True

        return ctx

    def process_message(self, message_data, recipients):
        """Encrypts the message with recipient keys"""
        message_data = encode_string(message_data)

        in_message = email.message_from_bytes(message_data)
        logging.info(
            "Processing outgoing message %s", in_message['Message-id'])

        if not recipients:
            logging.warning("Cannot find any recipients, ignoring")

        already_encrypted = self._is_encrypted(in_message)
        if already_encrypted:
            in_message = self._strip_plaintext(in_message)

        sent_messages = []
        # copies of in_message must be deep: shallow ones share its headers, so changing
        # them for one recipient would also change them for the next one
        for recipient in recipients:
            logging.info("Recipient: %s", recipient)

            if already_encrypted:
                logging.info("Message is already encrypted, sending its ciphertext as is")
                out_message = copy.deepcopy(in_message)

            else:
                key_id = self._user_key(recipient)
                logging.info("Key ID: %s", key_id)

                if key_id:
                    out_message = self._encrypt_message(in_message, key_id)

                elif self.force_encrypt:
                    logging.error("No keys found, message will not be sent!")
                    continue

                else:
                    logging.warning("No keys found, message will be sent unencrypted")
                    out_message = copy.deepcopy(in_message)

            self._add_zeyple_header(out_message)
            self._send_message(out_message, recipient)
            sent_messages.append(out_message)

        return sent_messages

    @property
    def force_encrypt(self):
        return self.config.getboolean('zeyple', 'force_encrypt', fallback=False)

    def _is_encrypted(self, message):
        """Returns whether the whole message is already encrypted with PGP"""
        if message.get_content_type() == 'multipart/encrypted':
            # PGP/MIME (RFC 3156): a version part then the encrypted data
            parts = message.get_payload() if message.is_multipart() else []
            protocol = str(message.get_param('protocol', '')).lower()
            if protocol != 'application/pgp-encrypted' or len(parts) != 2 or message.defects:
                return False
            if parts[0].get_content_type() != 'application/pgp-encrypted' or \
               parts[1].get_content_type() != 'application/octet-stream':
                return False
            # _strip_plaintext() replaces the preamble, epilogue and version part
            version = parts[0].get_payload(decode=True)
            payload = parts[1].get_payload(decode=True)
            # Decoding can record defects, such as ignored invalid base64 text.
            return not any(part.defects for part in parts) and \
                (version or b'').strip().splitlines()[:1] == [b'Version: 1'] and \
                self._is_pgp_message(payload)

        if message.is_multipart():
            return False

        # inline PGP: the body must be nothing but an encrypted block
        payload = message.get_payload(decode=True)
        return not message.defects and self._is_pgp_message(payload)

    def _is_pgp_message(self, data):
        """Returns whether data is an ASCII-armored OpenPGP encrypted message"""
        lines = [line.strip() for line in (data or b'').strip().splitlines()]
        if len(lines) < 3 or b'' not in lines or \
           lines[0] != b'-----BEGIN PGP MESSAGE-----' or \
           lines[-1] != b'-----END PGP MESSAGE-----':
            return False

        # skip the armor headers, which end with a blank line and which
        # _strip_plaintext() removes, and the checksum, which can't hold anything else
        body = lines[lines.index(b'') + 1:-1]
        if body and body[-1].startswith(b'='):
            if not re.fullmatch(rb'=[A-Za-z0-9+/]{4}', body[-1]):
                return False
            body = body[:-1]

        try:
            packets = base64.b64decode(b''.join(body), validate=True)
        except binascii.Error:
            return False

        if not encrypted_packet_sequence(packets):
            return False

        # Neither the first packet tag nor GPGME's identify() validates a
        # complete message. Use GnuPG's parser, without decrypting or accessing
        # the recipient keyring. Framing above also catches truncated ciphertext
        # that --list-only deliberately skips without reporting an error.
        # the same gpg as GPGME uses, also when PATH doesn't lead to it
        executable = self.config.get('gpg', 'executable', fallback=None) or \
            self.gpg.engine_info.file_name
        try:
            with tempfile.TemporaryDirectory(prefix='zeyple-pgp-') as home:
                result = subprocess.run(
                    [executable, '--no-options', '--batch', '--no-tty', '--no-autostart',
                     '--no-auto-key-retrieve', '--homedir', home, '--list-only', '--list-packets'],
                    input=data, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    timeout=30,
                )
            return result.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            logging.warning('Cannot validate existing PGP encryption; applying recipient policy')
            return False

    def _strip_plaintext(self, message):
        """Returns a copy of an already encrypted message with only its ciphertext:
        armor headers, MIME preamble, epilogue and part headers are outside it, so
        they could hold plaintext, and the recipient doesn't need them"""
        out_message = copy.deepcopy(message)
        if message.get_content_type() == 'multipart/encrypted':
            payload = message.get_payload()[1].get_payload(decode=True)
            out_message.preamble = PGP_PREAMBLE
            out_message.epilogue = None
            out_message.set_payload([
                self._get_version_part(),
                self._get_encrypted_part(strip_armor_headers(payload)),
            ])
        else:
            # armor is plain ASCII, so it needs no transfer encoding
            del out_message['Content-Transfer-Encoding']
            out_message.set_payload(strip_armor_headers(message.get_payload(decode=True)))
        return out_message

    def _get_version_part(self):
        ret = email.mime.application.MIMEApplication(
            'Version: 1\n',
            'pgp-encrypted',
            email.encoders.encode_noop,
        )
        ret.add_header(
            'Content-Description',
            "PGP/MIME version identification",
        )
        del ret['MIME-Version']
        return ret

    def _get_encrypted_part(self, payload):
        ret = email.mime.application.MIMEApplication(
            payload,
            'octet-stream',
            email.encoders.encode_noop,
            name="encrypted.asc",
        )
        ret.add_header('Content-Description', "OpenPGP encrypted message")
        ret.add_header(
            'Content-Disposition',
            'inline',
            filename='encrypted.asc',
        )
        del ret['MIME-Version']
        return ret

    def _encrypt_message(self, in_message, key_id):
        if in_message.is_multipart():
            # get the body (after the first \n\n)
            payload = in_message.as_string().split("\n\n", 1)[1].strip()

            # prepend the Content-Type including the boundary
            content_type = "Content-Type: " + in_message["Content-Type"]
            payload = content_type + "\n\n" + payload

            message = email.message.Message()
            message.set_payload(payload)

            payload = message.get_payload()

        else:
            message = email.mime.nonmultipart.MIMENonMultipart(
                in_message.get_content_maintype(),
                in_message.get_content_subtype()
            )
            payload = encode_string(in_message.get_payload())
            message.set_payload(payload)

            # list of additional parameters in content-type
            params = in_message.get_params()
            if params:
                # first item is the main/sub type so discard it
                del params[0]
                for param, value in params:
                    message.set_param(param, value, "Content-Type", False)

            encoding = in_message["Content-Transfer-Encoding"]
            if encoding:
                message.add_header("Content-Transfer-Encoding", encoding)

            del message['MIME-Version']

            mixed = email.mime.multipart.MIMEMultipart(
                'mixed',
                None,
                [message],
            )

            # remove superfluous header
            del mixed['MIME-Version']

            payload = mixed.as_bytes()

        encrypted_payload = self._encrypt_payload(payload, [key_id])

        version = self._get_version_part()
        encrypted = self._get_encrypted_part(encrypted_payload)

        out_message = copy.deepcopy(in_message)
        out_message.preamble = PGP_PREAMBLE
        # The original epilogue is already inside encrypted_payload. Keeping it
        # on the copied outer message would also send it in plaintext.
        out_message.epilogue = None

        if 'Content-Type' not in out_message:
            out_message['Content-Type'] = 'multipart/encrypted'
        else:
            out_message.replace_header(
                'Content-Type',
                'multipart/encrypted',
            )
        del out_message['Content-Transfer-Encoding']
        out_message.set_param('protocol', 'application/pgp-encrypted')
        out_message.set_payload([version, encrypted])

        return out_message

    def _encrypt_payload(self, payload, key_ids):
        """Encrypts the payload with the given keys"""
        payload = encode_string(payload)

        recipient = [self.gpg.get_key(key_id) for key_id in key_ids]

        for key in recipient:
            if key.expired:
                raise gpg.errors.GPGMEError(
                    "Key with user email {0} "
                    "is expired!".format(key.uids[0].email))

        (ciphertext, encresult, signresult) = self.gpg.encrypt(
            gpg.Data(string=payload),
            recipients=recipient,
            sign=False,
            always_trust=True
        )

        return ciphertext

    def _user_key(self, email):
        """Returns the GPG key for the given email address"""
        logging.info("Trying to encrypt for %s", email)

        # Explicit matching of email and uid.email necessary.
        # Otherwise gpg.keylist will return a list of keys
        # for searches like "n"
        for key in self.gpg.keylist(email):
            for uid in key.uids:
                if uid.email.lower() == email.lower():
                    return key.subkeys[0].keyid

        # Strip sub addressing tag
        submail = re.sub('(\\+[^@]+)', '', email)
        if submail != email:
            return self._user_key(submail)

        return None

    def _add_zeyple_header(self, message):
        if self.config.has_option('zeyple', 'add_header') and \
           self.config.getboolean('zeyple', 'add_header'):
            message.add_header(
                'X-Zeyple',
                "processed by {0} v{1}".format(__title__, __version__)
            )

    def _send_message(self, message, recipient):
        """Sends the given message through the SMTP relay"""
        logging.info("Sending message %s", message['Message-id'])

        smtp = smtplib.SMTP(self.config.get('relay', 'host'),
                            self.config.getint('relay', 'port'))

        smtp.sendmail(message['From'], recipient, message.as_string())
        smtp.quit()

        logging.info("Message %s sent", message['Message-id'])


def is_temporary(error):
    """Returns whether the relay failed in a way that retrying later could fix"""
    if isinstance(error, smtplib.SMTPRecipientsRefused):
        codes = [code for code, _ in error.recipients.values()]
    elif isinstance(error, smtplib.SMTPResponseException):
        codes = [error.smtp_code]
    else:
        # the relay can't be reached (smtplib errors are OSErrors too)
        return isinstance(error, OSError)

    return all(400 <= code < 500 for code in codes)


def main():
    recipients = sys.argv[1:]

    binary_stdin = sys.stdin.buffer
    message = binary_stdin.read()

    zeyple = None
    try:
        zeyple = Zeyple()
        zeyple.process_message(message, recipients)
    except Exception as error:
        # Never let Postfix bounce the message as the bounce would contain it unencrypted.
        # Retrying could still end in a bounce, so with force_encrypt only retry when the
        # relay is temporarily unavailable.
        if zeyple and zeyple.force_encrypt and not is_temporary(error):
            logging.exception("Cannot process message, dropping it as force_encrypt is set")
            return 0

        logging.exception("Cannot process message, Postfix will retry later")
        return os.EX_TEMPFAIL

    return 0


if __name__ == '__main__':
    sys.exit(main())
