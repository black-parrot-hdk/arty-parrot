import sys
import argparse

from enum import Enum
from typing import Optional

import serial
from tqdm import tqdm

from nbf import NBF_COMMAND_LENGTH_BYTES, NbfCommand, NbfFile, OPCODE_FINISH, OPCODE_PUTCH, OPCODE_READ_8, OPCODE_WRITE_8, ADDRESS_CSR_FREEZE

DRAM_REGION_START = 0x00_8000_0000
DRAM_REGION_END = 0x10_0000_0000

def _debug_format_message(command: NbfCommand) -> str:
    if command.opcode == OPCODE_PUTCH:
        return str(command) + f" (putch {repr(command.data[0:1].decode('utf-8'))})"
    else:
        return str(command)

class LogDomain(Enum):
    # meta info on requested commands
    COMMAND = 'command'
    # sent messages
    TRANSMIT = 'transmit'
    # received messages out-of-turn
    RECEIVE = 'receive'
    # received messages in response to a transmitted command
    REPLY = 'reply'

    @property
    def message_prefix(self):
        if self == LogDomain.COMMAND:
            return "[CMD  ]"
        elif self == LogDomain.TRANSMIT:
            return "[TX   ]"
        elif self == LogDomain.RECEIVE:
            return "[RX   ]"
        elif self == LogDomain.REPLY:
            return "[REPLY]"
        else:
            raise ValueError(f"unknown log domain '{self}'")

def _log(domain: LogDomain, message: str):
    tqdm.write(domain.message_prefix + " " + message)

class HostApp:
    def __init__(self, serial_port_name: str, serial_port_baud: int):
        self.port = serial.Serial(
            port=serial_port_name,
            baudrate=serial_port_baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1.0
        )
        self.commands_sent = 0
        self.commands_received = 0
        self.reply_violations = 0

    def _send_message(self, command: NbfCommand):
        self.port.write(command.to_bytes())
        self.port.flush()
        self.commands_sent += 1

    def _receive_message(self, block=True) -> Optional[NbfCommand]:
        if block or self.port.in_waiting >= NBF_COMMAND_LENGTH_BYTES:
            buffer = self.port.read(NBF_COMMAND_LENGTH_BYTES)

            if len(buffer) != NBF_COMMAND_LENGTH_BYTES:
                raise ValueError(f"serial port returned {len(buffer)} bytes, but {NBF_COMMAND_LENGTH_BYTES} requested")

            self.commands_received += 1
            return NbfCommand.from_bytes(buffer)
        else:
            return None

    def _receive_until_opcode(self, opcode: int) -> NbfCommand:
        message = self._receive_message()
        while message.opcode != opcode:
            _log(LogDomain.RECEIVE, _debug_format_message(message))
            message = self._receive_message()

        return message

    def print_summary_statistics(self):
        _log(LogDomain.COMMAND, f" Sent:     {self.commands_sent} commands")
        _log(LogDomain.COMMAND, f" Received: {self.commands_received} commands")
        if self.reply_violations > 0:
            _log(LogDomain.COMMAND, f" Reply violations: {self.reply_violations} commands")

    def _validate_reply(self, command: NbfCommand, reply: NbfCommand):
        if not command.is_correct_reply(reply):
            self.reply_violations += 1
            _log(LogDomain.REPLY, f'Unexpected reply: {command} -> {reply}')
            # TODO: abort on invalid reply?

    def load_file(self, source_file: str, ignore_unfreezes: bool = False):
        file = NbfFile(source_file)

        command: NbfCommand
        for command in tqdm(file, total=file.try_peek_length(), desc="loading nbf"):
            if ignore_unfreezes and command.matches(OPCODE_WRITE_8, ADDRESS_CSR_FREEZE, 0):
                continue

            self._send_message(command)
            if command.expects_reply():
                reply = self._receive_until_opcode(command.opcode)
                # TODO: verbose/echo mode

                self._validate_reply(command, reply)

        _log(LogDomain.COMMAND, "Load complete")

    def unfreeze(self):
        unfreeze_command = NbfCommand.with_values(OPCODE_WRITE_8, ADDRESS_CSR_FREEZE, 0)
        self._send_message(unfreeze_command)

        reply = self._receive_until_opcode(unfreeze_command.opcode)
        self._validate_reply(unfreeze_command, reply)

    def listen_perpetually(self, verbose: bool):
        _log(LogDomain.COMMAND, "Listening for incoming messages...")
        while message := self._receive_message():
            # in "verbose" mode, we'll always print the full message, even for putchar
            if not verbose and message.opcode == OPCODE_PUTCH:
                print(chr(message.data[0]), end = '')
                continue

            _log(LogDomain.RECEIVE, _debug_format_message(message))

            if message.opcode == OPCODE_FINISH:
                print(f"FINISH: core {message.address_int}, code {message.data_int}")
                # TODO: this assumes unicore
                return

    def verify(self, reference_file: str):
        file = NbfFile(reference_file)

        writes_checked = 0
        writes_corrupted = 0

        command: NbfCommand
        for command in tqdm(file, total=file.try_peek_length(), desc="verifying nbf"):
            if command.opcode != OPCODE_WRITE_8:
                continue

            if command.address_int < DRAM_REGION_START or command.address_int > DRAM_REGION_END - 8:
                continue

            read_message = NbfCommand.with_values(OPCODE_READ_8, command.address_int, 0)
            self._send_message(read_message)
            reply = self._receive_until_opcode(OPCODE_READ_8)
            self._validate_reply(read_message, reply)

            writes_checked += 1

            if reply.data != command.data:
                writes_corrupted += 1
                _log(LogDomain.COMMAND, f"Corruption detected at address 0x{command.address_hex_str}")
                _log(LogDomain.COMMAND, f" Expected: 0x{command.data_hex_str}")
                _log(LogDomain.COMMAND, f" Actual:   0x{reply.data_hex_str}")

        _log(LogDomain.COMMAND, "Verify complete")
        _log(LogDomain.COMMAND, f" Writes checked:       {writes_checked}")
        _log(LogDomain.COMMAND, f" Corrupt writes found: {writes_corrupted}")
        if writes_corrupted > 0:
            _log(LogDomain.COMMAND, "== CORRUPTION DETECTED ==")

def _load_command(app: HostApp, args):
    app.load_file(args.file, ignore_unfreezes=args.no_unfreeze)
    app.print_summary_statistics()

    if args.listen:
        app.listen_perpetually(verbose=False)

def _unfreeze_command(app: HostApp, args):
    app.unfreeze()

    if args.listen:
        app.listen_perpetually(verbose=False)

def _verify_command(app: HostApp, args):
    app.verify(args.file)
    app.print_summary_statistics()

def _listen_command(app: HostApp, args):
    app.listen_perpetually(verbose=False)

if __name__ == "__main__":
    root_parser = argparse.ArgumentParser()
    root_parser.add_argument('-p', '--port', dest='port', type=str, default='/dev/ttyS4', help='Serial port (full path or name)')
    root_parser.add_argument('-b', '--baud', dest='baud_rate', type=int, default=115200, help='Serial port baud rate')

    command_parsers = root_parser.add_subparsers(dest="command")
    command_parsers.required = True

    load_parser = command_parsers.add_parser("load")
    load_parser.add_argument('file', help="NBF-formatted file to load")
    load_parser.add_argument('--no-unfreeze', action='store_true', dest='no_unfreeze', help='Suppress any "unfreeze" commands in the input file')
    load_parser.add_argument('--listen', action='store_true', dest='listen', help='Continue listening for incoming messages until program is aborted')
    # TODO: add --verify which automatically implies --no-unfreeze then manually unfreezes after
    # TODO: add --verbose which prints all sent and received commands
    load_parser.set_defaults(handler=_load_command)

    unfreeze_parser = command_parsers.add_parser("unfreeze")
    unfreeze_parser.add_argument('--listen', action='store_true', dest='listen', help='Continue listening for incoming messages until program is aborted')
    unfreeze_parser.set_defaults(handler=_unfreeze_command)

    verify_parser = command_parsers.add_parser("verify")
    verify_parser.add_argument('file', help="NBF-formatted file to load")
    verify_parser.set_defaults(handler=_verify_command)

    listen_parser = command_parsers.add_parser("listen")
    listen_parser.set_defaults(handler=_listen_command)

    args = root_parser.parse_args()

    app = HostApp(serial_port_name=args.port, serial_port_baud=args.baud_rate)
    try:
        args.handler(app, args)
    except KeyboardInterrupt:
        print("Aborted")
        sys.exit(1)
