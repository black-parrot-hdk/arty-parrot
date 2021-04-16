import os
import sys
import serial
import argparse
import signal
import atexit
import time

## Global variables
# Serial Port
sp = None

## Program Arguments
def getArgs():
  parser = argparse.ArgumentParser(description='UART Driver')
  # UART parameters
  parser.add_argument('-p', '--port', dest='port', type=str, default='/dev/ttyS4',
                      help='Serial port (full path)')
  parser.add_argument('-b', '--baud', dest='baud', type=int, default=9600,
                      help='Baud Rate (bits per second)')
  parser.add_argument('-d', '--data-bits', dest='bits', default=8, const=8, type=int,
                      nargs='?', choices=[5, 6, 7, 8],
                      help='Data bits [5, 6, 7, 8]')
  parser.add_argument('-s', '--stop-bits', dest='stopbits', default=1, const=1, type=int,
                      nargs='?', choices=[1, 2],
                      help='Stop bits [1, 2]')
  parser.add_argument('--parity', dest='parity', default='none', const='none',
                      nargs='?', choices=['none', 'even', 'odd'],
                      help='Parity [none, even, odd]')
  parser.add_argument('-t', '--timeout', dest='timeout', default=1.0, type=float,
                      help='Read timeout')
  # Mode
  parser.add_argument('-m', '--mode', dest='mode', default='char', const='char',
                      nargs='?', choices=['nbf', 'char', 'hex'],
                      help='Input file mode [nbf, char, hex]. char and hex modes read from stdin')
  parser.add_argument('-f', '--file', dest='infile', default=None, type=str,
                      help='Input file')
  # NBF mode parameters
  parser.add_argument('--nbf-op-bytes', dest='nbf_op_bytes', default=1, type=int,
                      help='Number of bytes per NBF opcode')
  parser.add_argument('--nbf-addr-bytes', dest='nbf_addr_bytes', default=5, type=int,
                      help='Number of bytes per NBF address')
  parser.add_argument('--nbf-data-bytes', dest='nbf_data_bytes', default=8, type=int,
                      help='Number of bytes per NBF data')
  parser.add_argument('--nbf-listen-timeout', dest='nbf_listen_timeout', default=8, type=int,
                      help='Seconds to wait for NBF packets from FPGA before prompting user')
  return parser.parse_args()

def openFile(infile, mode):
  fp = os.path.abspath(os.path.realpath(infile))
  return open(fp, mode)

## Serial Port Functions
def openSerial(args):
  bytesize = serial.EIGHTBITS
  if (args.bits == 5):
    bytesize = serial.FIVEBITS
  elif (args.bits == 6):
    bytesize = serial.SIXBITS
  elif (args.bits == 7):
    bytesize = serial.SEVENBITS

  parity = serial.PARITY_NONE
  if (args.parity == 'even'):
    parity = serial.PARITY_EVEN
  elif (args.parity == 'odd'):
    parity = serial.PARITY_ODD

  stopbits = serial.STOPBITS_ONE
  if (args.stopbits == 2):
    stopbits = serial.STOPBITS_TWO

  timeout = args.timeout
  if (timeout < 0):
    timeout = None

  return serial.Serial(port=args.port, baudrate=args.baud, bytesize=bytesize,
                       parity=parity, stopbits=stopbits, timeout=timeout)

## Formatting Functions
def encodeString(string):
  return string.encode('utf-8')

def hexStringToBytes(string):
  try:
    b = bytes.fromhex(string)
  except:
    print('could not parse as hex: {0}'.format(string))
    b = None
  return b

## Exit and Signal handlers
def exitHandler():
  if not sp is None and sp.is_open:
    print("closing serial port: {0}".format(sp.name))
    sp.close()

def sigIntHandler(sig, frame):
  if not sp is None and sp.is_open:
    print("closing serial port: {0}".format(sp.name))
    sp.close()
  sys.exit(1)

## Interactive Modes
def interactiveHex(args):
  user_input = None
  while (True):
    print('Enter hex characters to send:')
    user_input = hexStringToBytes(input('$ '))
    if not user_input is None:
      user_input_length = len(user_input)
      sp.write(user_input)
      print('sent {0} bytes'.format(user_input_length))
      print('readback: {0}'.format(sp.read(user_input_length)))

def interactiveCh(args):
  user_input = None
  while (True):
    print('Enter characters to send:')
    user_input = encodeString(input('$ '))
    user_input_length = len(user_input)
    sp.write(user_input)
    print('sent {0} bytes'.format(user_input_length))
    print('readback: {0}'.format(sp.read(user_input_length)))

## NBF Mode

# encode 'op_addr_data' hex nbf string to bytes
def encodeNBF(string: str):
  def parse_and_swap_endianness(part: str):
    b = bytearray(hexStringToBytes(part))
    b.reverse()
    return bytes(b)
  part_bytes = map(parse_and_swap_endianness, string.strip().split('_'))
  return b''.join(part_bytes)

# decode (op, addr, data) bytes to 'op_addr_data' hex nbf string
def decodeNBF(op_bytes, addr_bytes, data_bytes):
  return '{0}_{1}_{2}'.format(op_bytes.hex(), addr_bytes.hex(), data_bytes.hex())

# split 'op_addr_data' hex string into (op, addr, data) hex string tuple
def splitNBF(args, nbf):
  nbf_parts = nbf.strip().split('_')
  opcode = nbf_parts[0]
  addr = nbf_parts[1]
  data = nbf_parts[2]
  return (opcode, addr, data)

# determine if NBF command has response
def nbfHasResponse(opcode_hex):
  # BP NBF opcodes requiring response from FPGA
  resp_ops = ['02', '03', '12', '13', 'fe', 'ff']
  return (opcode_hex in resp_ops)

# read NBF packet from serial port, return (op, addr, data) hex strings
def readNBF(args):
  def swap_endianness(b: bytes):
    b = bytearray(b)
    b.reverse()
    return bytes(b)

  opcode = sp.read(args.nbf_op_bytes)
  addr = swap_endianness(sp.read(args.nbf_addr_bytes))
  data = swap_endianness(sp.read(args.nbf_data_bytes))

  if (len(opcode) != args.nbf_op_bytes) or (len(addr) != args.nbf_addr_bytes) or (len(data) != args.nbf_data_bytes):
    print('Failed to receive full NBF packet')
    return (None, None, None)
  return (opcode.hex(), addr.hex(), data.hex())

# write NBF packet to serial port, return bytes written
# also waits for response if command has a response
def writeNBF(args, nbf_hex):
  try:
    bytes_written = 0
    (opcode, addr, data) = splitNBF(args, nbf_hex)
    nbf_bytes = encodeNBF(nbf_hex)
    bytes_written = len(nbf_bytes)
    print('SEND:  {0}'.format(nbf_hex.strip()))
    sp.write(nbf_bytes)
    if (nbfHasResponse(opcode)):
      (opcode_in, addr_in, data_in) = readNBF(args)
      print('REPLY: {0}_{1}_{2}'.format(opcode_in, addr_in, data_in))
    return bytes_written
  except RuntimeError as e:
    raise
    print('failed to transfer nbf file')
    return 0

# transfer NBF file, command by command
def sendNBF(args):
  # process input file as BlackParrot NBF format
  # each line of nbf file is hex characters
  # underscores may be present to separate hex
  try:
    bytes_written = 0
    with openFile(os.path.abspath(args.infile), 'r') as f:
      for nbf in f:
        bytes_written += writeNBF(args, nbf)
    print('wrote {0} bytes'.format(bytes_written))
  except RuntimeError as e:
    print('failed to transfer nbf file...closing')
    if not sp is None and sp.is_open:
      sp.close()

# listen on serial port for NBF packets
def listenNBF(args):
  timeout_cnt = 0
  # loop until user says stop
  while(True):
    # check if serial port has bytes, and try to process if it does
    # some bytes received, read them from serial port
    if sp.in_waiting > 0:
      (opcode_in, addr_in, data_in) = readNBF(args)
      if (opcode_in is None):
        return
      print('REPLY: {0}_{1}_{2}'.format(opcode_in, addr_in, data_in))
      if opcode_in == '82':
        # putch
        print("char: " + chr(int(data_in, 16)))
      timeout_cnt = 0
    # no bytes received, increment timeout counter
    # sleep for a second
    else:
      timeout_cnt += 1
      time.sleep(1)

    if timeout_cnt > args.nbf_listen_timeout:
      resp = input('$ Continue executing (y/n)? ')
      if (resp.lower() in ['n', 'no']):
        return
      else:
        timeout_cnt = 0


# NBF mode entry
def runNBF(args):
  sendNBF(args)
  listenNBF(args)

## Main
if __name__ == '__main__':
  atexit.register(exitHandler)
  signal.signal(signal.SIGINT, sigIntHandler)
  args = getArgs()
  try:
    sp = openSerial(args)
    if args.mode == 'char':
      interactiveCh(args)
    elif args.mode == 'hex':
      interactiveHex(args)
    elif args.mode == 'nbf':
      runNBF(args)
  except Exception as e:
    print("caught an exception, closing")
    print(e)
