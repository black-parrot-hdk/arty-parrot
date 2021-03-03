import os
import sys
import serial
import argparse

parser = argparse.ArgumentParser(description='UART Driver')
parser.add_argument('-p', '--port', dest='port', type=str, default='/dev/ttyS4',
                    help='Serial port (full path)')
parser.add_argument('-b', '--baud', dest='baud', type=int, default=9600,
                    help='Baud Rate (bits per second)')
parser.add_argument('-d', '--data-bits', dest='bits', default=8, const=8,
                    nargs='?', choices=[5, 6, 7, 8],
                    help='Data bits [5, 6, 7, 8]')
parser.add_argument('-s', '--stop-bits', dest='stopbits', default=1, const=1,
                    nargs='?', choices=[1, 2],
                    help='Stop bits [1, 2]')
parser.add_argument('--parity', dest='parity', default='none', const='none',
                    nargs='?', choices=['none', 'even', 'odd'],
                    help='Parity [none, even, odd]')
parser.add_argument('-f', '--file', dest='infile', default=None, type=str,
                    help='Input file')
parser.add_argument('-m', '--mode', dest='mode', default='binary', const='hex',
                    nargs='?', choices=['binary', 'hex', 'input-ch', 'input-hex'],
                    help='Input file mode [binary, hex, input-ch, input-hex]. input- modes read from stdin')

def getArgs():
  return parser.parse_args()

def openFile(infile, mode):
  fp = os.path.abspath(os.path.realpath(infile))
  m = 'r'
  if (mode == 'binary'):
    m = 'rb'
  return open(fp, m)

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
  return bytes.fromhex(string)

if __name__ == '__main__':
  while (True):
    print('Enter characters to send:')
    user_input = input('$ ')
    print('{0}'.format(encodeString(user_input)))
