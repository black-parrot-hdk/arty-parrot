# arty-parrot

BlackParrot on the Arty series of Xilinx FPGA dev boards.

Currently, this repo supports only the Arty A7-100T. Support for other variants is anticipated, and
would likely be straightforward for other members of the Arty family.

Supported features:
- Unicore BlackParrot configuration (`e_bp_unicore_l1_tiny_cfg`)
- 256MB DDR3 RAM on-board
- Loading arbitrary programs at runtime via NBF interface
- Printing to host console

Not supported (yet!):
- Multicore configurations
- Interactive console input
- Other on-board I/O such as switches and LEDs

Other areas for improvement:
- Ability to save/load program images to/from flash
- Improve speed of loading large programs over UART interface
  - Bump the baud rate to the maximum we can reasonably support via standard hosts
  - Consider supporting reads/writes larger than 8 bytes at a time

## Repo structure

- `common/`: Board definition files and template constraints files for the Arty A7-100T.
- `py/`: Python scripts for interacting with a board over the USB serial interface.
- `src/`: RTL for the arty-parrot-specific host components in the design.
- `xdc/`: constraints files
- `nbf/`: NBF creation and sample files
- `rtl/`: BlackParrot RTL
- `sdk/`: BlackParrot SDK

## Usage

### Supported environment

We currently only provide appropriate scripts for Vivado project mode; non-project mode is likely
possible but not currently implemented.

The project in this repo targets Vivado 2019.1 by default. However, automatically upgrading to a
more recent version is possible. Instructions for doing so are planned.

### Getting Started with Arty A7

The board manufacturer has resources available [here](https://reference.digilentinc.com/programmable-logic/arty-a7/start)
which we recommend referencing when working with the board.

You will need to ensure that your local installation of Vivado is aware of the Arty A7 board and its
components. If you have not yet installed Vivado, select the Artix-7 family of FPGA parts when asked
and that should be sufficient. Otherwise, if Vivado reports a failure finding the appropriate board
or part while following the below instructions, try one of the following options and re-run the
project generation:
- Under the "Tools" menu, click "Download Latest Boards..."
- Re-run the installer and select the Artix-7 family
- Manually install the Arty A7 board files as described in Step 3 of
  ["Installing Vivado and Digilent Board Files"](https://reference.digilentinc.com/vivado/installing-vivado/start).

### Opening in Vivado and running synthesis

Clone this repo, including submodules:

```
git clone --recursive https://github.com/black-parrot-hdk/arty-parrot.git
cd arty-parrot
```

#### Generate the project

Source the Vivado settings script for your machine. On Linux this is called `settings64.sh`.

If you are on a Linux host, generate the project using the following command:

```
make gen_proj
```

Otherwise, you can manually invoke Vivado. In a terminal, `cd` into the `proj/` directory and run
the following:

```
vivado -mode batch -source ./generate_project.tcl -tclargs --blackparrot_dir ../path/to/black-parrot --arty_dir ../
```

Once the project has been generated, open the `proj/arty-parrot/arty-parrot.xpr` project in the Vivado GUI.

If you introduce new BlackParrot files or reference a different version of the BlackParrot RTL, you
will have to either manually modify the files included in the project or delete the `arty-parrot`
directory and re-run the above. Re-generating the project automatically discovers the appropriate
files to include.

#### Synthesis and loading onto the board

**Option 1:** `generate\_bitstream.tcl`

On a Linux host, run synthesis, implementation, and bitstream generation with the following command:

```
make gen_bit
```

**Option 2:** Vivado GUI

Synthesis, implementation and bitstream generation should work out-of-the-box. Click the respective steps
in the left pane of the Vivado GUI to launch the corresponding task runs.

Similarly, once you have generated a bitstream, opening the Hardware Manager with the Arty board
connected should allow you to program it from the editor.

**IMPORTANT: You must _remove_ the "JP2" jumper for this project to work in its default
configuration.** The JP2 jumper, when connected, will trigger erroneous resets in response to USB
serial activity.

### Manual invocation of project creation script

If you would like to generate the project without the Makefile (e.g., on Windows), do the
following:
* If necessary for your host OS, source Vivado settings64.sh from the command prompt (settings64.bat on Windows)
* Run `vivado -mode batch -source generate_project.tcl -tclargs --blackparrot_dir <path> --arty_dir <path>`
    * The `--blackparrot_dir` argument is the base folder for BlackParrot repo without the trailing
      slash. This repo includes the black-parrot repo as a submodule under the folder name `rtl`;
      you should provide the path to that directory.
    * The `--arty_dir` argument is the base folder of this repository without the trailing slash.

On Windows machines, you may need to use single `/` characters (forward slashes) in the path, and
use absolute paths.

### Deploying and running programs

This project implements a UART-based (via USB) host communication mechanism. A host computer loads
code into memory of the BlackParrot system and then initiates execution from that memory image.

First, make sure you have:

- Python 3.8 or above
    - `pyserial` and `tqdm` installed (`python3 -m pip install pyserial tqdm`)
- A USB cable connected to the MicroUSB port of the Arty A7
- A RISC-V ELF image you want to run, with appropriate memory layout for BlackParrot

Programs are loaded into the arty-parrot system via .nbf (Network Boot Format) command listing
files. You can generate one either from a standalone ELF or from a sample provided by the
BlackParrot SDK. We also provide a sample .nbf in `nbf/samples/hello_world.nbf` if you want to start
with a pre-made file. Otherwise, run one of the following commands, according to the source you
have:

```bash
# If you have set up the BlackParrot SDK and want to run a provided program from the SDK
#   Output will be at: nbf/<SUITE>/<PROG>.riscv.nbf
make gen_nbf_from_sdk SUITE=bp-tests PROG=hello_world
# If you have a standalone ELF file
#   Output will be at: nbf/file.riscv.nbf
make gen_nbf_from_elf ELF=path/to/file.riscv
```

Now you can load it onto the board. Begin by resetting the system using the red button labeled
"RESET".

To load a program, you will use the `host.py` script provided in this repo. The most straightforward
usage is as follows:

```
./py/host.py -p <serial port name> load ./nbf/samples/hello_world.nbf --listen
```

The script will execute the provided `hello_world.nbf`, which loads the program into memory and then
unfreezes the core to begin execution. The host will listen for incoming commands, such as character
prints, until the program reports completion.

If you run the above using the provided `hello_world.nbf`, you should see the following:

```
loading nbf: 100%|███████████████████████| 350/350 [00:05<00:00, 62.48it/s]
[CMD  ] Load complete
[CMD  ]  Sent:     350 commands
[CMD  ]  Received: 350 commands
[CMD  ] Listening for incoming messages...
Hello world!
[RX   ] 80_0000000000_0000000000000000
FINISH: core 0, code 0
```

For more details on the usage of `host.py`, refer to its `--help` page.

## Debugging with Xilinx Integrated Logic Analyzer

_To be expanded._

The ILA core requires a clock faster than our current "core" clock (min 25MHz) but slower than our
memory clocks. To use the ILA, we must enable a new clock which is a convenient multiple of our core
clock and within the acceptable range. A 40MHz clock works well. The patch
`docs/0001-Add-debug-clock-and-mark-top-signals-for-debug.patch` has been provided to add this clock
to the existing PLL and shows how to mark signals for tracing. You can apply this patch with:

```
git am < docs/0001-Add-debug-clock-and-mark-top-signals-for-debug.patch
```

Once you have marked any other signals of interest:

1. Generate and open the project
1. Run synthesis (no implementation necessary)
1. Under "Synthesis" in the left sidebar, expand "Open Synthesized Design" and click "Set Up Debug"
1. Click "Next"
1. Remove any nets that you do not want to monitor, to save board resources
1. Select all enabled nets in the list, right-click, and click "Select Clock Domain..."
1. Select `dbg_clk` from the list and press "OK"
1. Click "Next"
1. Enable "Capture control" and click "Next"
1. Once the dialog is done processing, you should be left on the "Synthesized design" view.
1. **VERY important:** Use the menu or <kbd>Ctrl</kbd>+<kbd>S</kbd> to save your changes. If warned about synthesis going out-of-date, dismiss the dialog. In the "Save Constraints" window, Select "Create a new file" and give it a name like `debug_constraints.xdc`. Press "OK".

Now run Synthesis and then Implementation, and once complete, generate a bitstream and program the device as desired. It will automatically open the ILA viewer when you program the board.

## Simulations

Currently, the simulations in this repo don't cover the BlackParrot core, and instead focus on the
arty-parrot custom modules and integration. The simulations use Vivado's built-in XSim, which can be
activated via the "Run Simulation" button in the Vivado GUI. Note that, to simulate designs which
include the memory controller, you must do some manual setup; see `src/external/README.md`.
