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
- `proj/`: tcl script and accompanying IP configurations for generating a Vivado project.
- `py/`: Python scripts for interacting with a board over the USB serial interface.
- `src/`: RTL for the arty-parrot-specific host components in the design.
- `test/`: Some sample NBF files.

## Usage

### Supported environment

We currently only provide appropriate scripts for Vivado project mode; non-project mode is likely
possible but not currently implemented.

The project in this repo targets Vivado 2019.1 by default. However, automatically upgrading to a
more recent version is possible. Instructions for doing so are planned.

### Getting Started with Arty A7

We suggest following the [instructions](https://reference.digilentinc.com/programmable-logic/arty-a7/start)
provided by Digilent to setup Vivado for use with the Arty A7 boards.

In particular, it may help to install the Arty A7 board files as described in Step 3 of
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

**Option 1:** `generate\_project.tcl`

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

### Deploying and running programs

This project implements a UART-based (via USB) host communication mechanism. A host computer loads
code into memory of the BlackParrot system and then initiates execution from that memory image.

First, make sure you have:

- Python 3.8 or above
    - `pyserial` and `tqdm` installed (`python3 -m pip install pyserial tqdm`)
- A USB cable connected to the MicroUSB port of the Arty A7
- A .nbf file describing the program to load.
    - _TODO: provide instructons._ You need a file which _includes_ zeroes and ideally ends with an
      "unfreeze".

Begin by resetting the board using the red button labeled "RESET".

To load a program, you will use the `host.py` script provided in this repo. The most straightforward
usage is as follows:

```
./py/host.py -p <serial port name> load .\test\hello_world.nbf --listen
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

Apply patch for clocks. Mark any signals of interest. Then:
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
