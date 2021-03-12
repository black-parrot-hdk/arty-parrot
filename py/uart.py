import os
import sys
import serial
import argparse
import signal
import atexit

parser = argparse.ArgumentParser(description='UART Driver')
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
parser.add_argument('-f', '--file', dest='infile', default=None, type=str,
                    help='Input file')
parser.add_argument('-m', '--mode', dest='mode', default='input-ch', const='input-ch',
                    nargs='?', choices=['binary', 'hex', 'nbf', 'input-ch', 'input-hex'],
                    help='Input file mode [binary, hex, nbf, input-ch, input-hex]. input- modes read from stdin')
parser.add_argument('-n', '--nbf-bits', dest='nbf', default=112, type=int,
                    help='Number of bits per NBF command (opcode + address + data)')

# serial port
sp = None

def getArgs():
  return parser.parse_args()

def openFile(infile, mode):
  fp = os.path.abspath(os.path.realpath(infile))
  return open(fp, mode)

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

  return serial.Serial(port=args.port, baudrate=args.baud, bytesize=bytesize,
                       parity=parity, stopbits=stopbits)

def closeSerial(serialPort):
  serialPort.close()

def encodeString(string):
  return string.encode('utf-8')

def hexStringToBytes(string):
  try:
    b = bytes.fromhex(string)
  except:
    print('could not parse as hex: {0}'.format(string))
    b = None
  return b

# Exit and Signal handlers
def exitHandler():
  print("goodbye!")
  if not sp is None and sp.is_open:
    print("closing serial port: {0}".format(sp.name))
    sp.close()

def signalHandler(sig, frame):
  print("signal handler")
  if not sp is None and sp.is_open:
    print("closing serial port: {0}".format(sp.name))
    sp.close()
  sys.exit(1)


# modes
def runBinary(args):
  pass

def runHex(args):
  pass

def readNBF():
  opcode = sp.read(1).hex()
  addr = sp.read(5).hex()
  data = sp.read(8).hex()
  print('NBF: {0}_{1}_{2}'.format(opcode, addr, data))

def nbfHasResponse(nbf_bytes):
  resp_ops = [b'\xff', b'\xfe', b'\x02', b'\x03']
  return (nbf_bytes[0] in resp_ops)

def sendNBF(args):
  # process input file as BlackParrot NBF format
  # each line of nbf file is hex characters
  # underscores may be present to separate hex
  try:
    bytes_written = 0
    with openFile(args.infile, 'r') as f:
      for line in f:
        line = line.strip().replace('_','')
        line_bytes = hexStringToBytes(line)
        sp.write(line_bytes)
        bytes_written += len(line_bytes)
        if (nbfHasResponse(line_bytes)):
          readNBF()
    print('wrote {0} bytes from nbf'.format(bytes_written))
    while (True):
      readNBF()
  except:
    print('failed to transfer nbf file')
    if not sp is None and sp.is_open:
      sp.close()

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

if __name__ == '__main__':
  atexit.register(exitHandler)
  signal.signal(signal.SIGINT, signalHandler)
  args = getArgs()
  try:
    sp = openSerial(args)
    if args.mode == 'input-ch':
      interactiveCh(args)
    elif args.mode == 'input-hex':
      interactiveHex(args)
    elif args.mode == 'binary':
      f = openFile(args.infile, 'rb')
      f.close()
      pass
    elif args.mode == 'hex':
      f = openFile(args.infile, 'r')
      f.close()
      pass
    elif args.mode == 'nbf':
      runNBF(args)
  except:
    print("caught an exception, closing")
