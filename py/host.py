import sys
import argparse

from enum import Enum
from typing import Optional

import serial
from tqdm import tqdm

from nbf import NBF_COMMAND_LENGTH_BYTES, NbfCommand, NbfFile, OPCODE_PUTCH, OPCODE_WRITE_8, ADDRESS_CSR_FREEZE

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
    def __init__(self, serial_port_name: str):
        self.port = serial.Serial(
            port=serial_port_name,
            baudrate=115200,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1.0
        )
        self.commands_sent = 0
        self.commands_received = 0

    def _write_message(self, command: NbfCommand):
        self.port.write(command.to_bytes())
        self.commands_sent += 1

    def _read_message(self, block=True) -> Optional[NbfCommand]:
        if block or self.port.in_waiting >= NBF_COMMAND_LENGTH_BYTES:
            buffer = self.port.read(NBF_COMMAND_LENGTH_BYTES)

            if len(buffer) != NBF_COMMAND_LENGTH_BYTES:
                raise ValueError(f"serial port returned {len(buffer)} bytes, but {NBF_COMMAND_LENGTH_BYTES} requested")

            self.commands_received += 1
            return NbfCommand.from_bytes(buffer)
        else:
            return None

    def _read_until_opcode(self, opcode: int) -> NbfCommand:
        message = self._read_message()
        while message.opcode != opcode:
            _log(LogDomain.RECEIVE, _debug_format_message(message))
            message = self._read_message()

        return message

    def _flush(self):
        self.port.flush()

    def load_file(self, source_file: str, ignore_unfreezes: bool = False):
        file = NbfFile(source_file)

        command: NbfCommand
        for command in tqdm(file, desc="loading nbf"):
            if ignore_unfreezes and command.matches(OPCODE_WRITE_8, ADDRESS_CSR_FREEZE, 0):
                continue

            self._write_message(command)
            if command.expects_reply():
                reply = self._read_until_opcode(command.opcode)
                # TODO: verbose/echo mode

                if not command.is_correct_reply(reply):
                    _log(LogDomain.REPLY, f'Unexpected reply: {command} -> {reply}')

        self._flush()
        _log(LogDomain.COMMAND, "Load complete:")
        _log(LogDomain.COMMAND, f" Sent:     {self.commands_sent} commands")
        _log(LogDomain.COMMAND, f" Received: {self.commands_received} commands")

    def unfreeze(self):
        unfreeze_command = NbfCommand.with_values(OPCODE_WRITE_8, ADDRESS_CSR_FREEZE, 0)
        self._write_message(unfreeze_command)
        self._flush()

        reply = self._read_until_opcode(unfreeze_command.opcode)

        if not unfreeze_command.is_correct_reply(reply):
            _log(LogDomain.REPLY, f'Unexpected reply: {unfreeze_command} -> {reply}')


    def listen_perpetually(self, verbose: bool):
        _log(LogDomain.COMMAND, "Listening for incoming messages...")
        while message := self._read_message():
            # in "verbose" mode, we'll always print the full message, even for putchar
            if not verbose and message.opcode == OPCODE_PUTCH:
                print(chr(message.data[0]), end = '')
                continue

            _log(LogDomain.RECEIVE, _debug_format_message(message))

def _load_command(app: HostApp, args):
    app.load_file(args.file, ignore_unfreezes=args.no_unfreeze)

    if args.listen:
        app.listen_perpetually(verbose=False)

def _unfreeze_command(app: HostApp, args):
    app.unfreeze()

    if args.listen:
        app.listen_perpetually(verbose=False)

if __name__ == "__main__":
    root_parser = argparse.ArgumentParser()
    root_parser.add_argument('-p', '--port', dest='port', type=str, default='/dev/ttyS4', help='Serial port (full path or name)')

    command_parsers = root_parser.add_subparsers(dest="command")
    command_parsers.required = True

    load_parser = command_parsers.add_parser("load")
    load_parser.add_argument('file', help="NBF-formatted file to load")
    load_parser.add_argument('--no-unfreeze', action='store_true', dest='no_unfreeze', help='Suppress any "unfreeze" commands in the input file')
    load_parser.add_argument('--listen', action='store_true', dest='listen', help='Continue listening for incoming messages until program is aborted')
    load_parser.set_defaults(handler=_load_command)

    unfreeze_parser = command_parsers.add_parser("unfreeze")
    unfreeze_parser.add_argument('--listen', action='store_true', dest='listen', help='Continue listening for incoming messages until program is aborted')
    unfreeze_parser.set_defaults(handler=_unfreeze_command)

    args = root_parser.parse_args()

    app = HostApp(serial_port_name=args.port)
    try:
        args.handler(app, args)
    except KeyboardInterrupt:
        print("Aborted")
        sys.exit(1)
