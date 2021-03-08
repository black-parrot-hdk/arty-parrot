## NBF (Network Boot File) Format

BlackParrot is configured using a NBF file. Each line of the NBF file has the following
format:

`OPCODE_ADDR_DATA`

The OPCODE field specifies the operation performaed by the NBF loader. It is 8-bits
in size where the 4 MSB is typically the opcode and the 4 LSB is typically the size
of the data field, specified as 2^N bytes. For example, a size of 3 means the command
has 8 bytes of data. Valid sizes are 2 and 3 for 32- and 64-bits, respectively.

The NBF loader in the FPGA Host can receive the following commands:
* 0x02 - Write 4-bytes to address
* 0x03 - Write 8-bytes to address
* 0x12 - Read 4-bytes from address
* 0x13 - Read 8-bytes from address
* 0xFE - Fence - fence memory operations in NBF loader
* 0xFF - Finish NBF - last command in NBF transaction

The FPGA Host can send the following commands to the PC Host:
* 0xF0 - Core finished, data = core ID
* 0xF1 - putchar - write a single character to PC Host, data = Id
* 0xF2 - putchar\_core - write a single character to PC Host, data = core Id, char
* 0xF3 -

The ADDR field provides a physical address of 40-bits. See BlackParrot's
[Platform Guide](https://github.com/black-parrot/black-parrot/blob/dev/docs/platform_guide.md)
for the default address map. The BlackParrot [address package defines](https://github.com/black-parrot/black-parrot/blob/dev/bp_common/src/include/bp_common_addr_pkgdef.svh)
and [config bus package defines](https://github.com/black-parrot/black-parrot/blob/dev/bp_common/src/include/bp_common_cfg_bus_pkgdef.svh)
show configuration registers that are accessible at specific addresses.

The DATA field provides the number of bytes specified by the size field
of the OPCODE. Data is padded to a width of 64-bits.

## BlackParrot FPGA Communication

When running on an FPGA, BlackParrot is configured using an NBF file that is the same
NBF file as the one generated for VCS or Verilator simulation. This file uses Write,
Fence, and Finish commands.

During execution, BlackParrot's minimal I/O capabilities are received by the FPGA
Host and transferred to the PC Host with NBF packets.
