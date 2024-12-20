# CYW55513/CYW55913 GNU make Build System Release Notes
This repo provides the build recipe make files and scripts for building and programming CYW55513/CYW55913 applications. Builds can be run either through a command-line interface (CLI) or through a supported IDE such as Eclipse or VS Code.

### What's Included?
This release of the CYW55513/CYW55913 GNU make build recipe includes complete support for building, programming, and debugging CYW55513/CYW55913 application projects. It is expected that a code example contains a top level make file for itself and references a Board Support Package (BSP) that defines specific items, like the CYW55513/CYW55913 part, for the target board. Supported functionality includes the following:

* Supported operations:
    * Build
    * Program
    * Debug
    * IDE Integration (Eclipse, VS Code)
* Supported toolchains:
    * GCC
    * ARM Compiler 6

This also includes the getlibs.bash script that can be used directly, or via the make target to download additional git repo based libraries for the application.

### What Changed?
#### v1.4.0
* Added Ninja support. Ninja build will be enabled by default with ModusToolbox 3.4, and latest core-make. To disable Ninja build set NINJA to empty-String. (For example: "make build NINJA=").

#### v1.3.1
* Minor bug fixes

#### v1.3.0
* Optimization for speed changed to optimization for size for the IAR toolchain
* The feature of setting the default location of the ARM and IAR toolchains has been deprecated
* Support for non-generated linker scripts when LINKER_SCRIPT is defined, example scripts in bsp
* Use setting APPEXEC={flash,psram,ram} to locate code/rodata in flash XIP, psram, or ram
* Asset search paths in PLACE_COMPONENT_IN_SRAM list specify code/rodata to be placed in ram
* Special section names are supported: .cy_ramfunc places code in ram, .cy_xip* places code in flash, .cy_psram* places code in psram

#### v1.2.1
* Fixed a bug causing image to not boot from RAM
* Fixed a bug causing incorrect XIP alignment

#### v1.2.0
* CYW55513 device support added

#### v1.1.1
* Minor change to symbol file handling

#### v1.0.0
* Initial production release

### Product/Asset Specific Instructions
Builds require that the ModusToolbox tools be installed on your machine. This comes with the ModusToolbox install. On Windows machines, it is recommended that CLI builds be executed using the Cygwin.bat located in ModusToolBox/tools\_x.y/modus-shell install directory. This guarantees a consistent shell environment for your builds.

To list the build options, run the "help" target by typing "make help" in CLI. For a verbose documentation on a specific subject type "make help CY\_HELP={variable/target}", where "variable" or "target" is one of the listed make variables or targets.

### Supported Software and Tools
This version of the CYW55513/CYW55913 build system was validated for compatibility with the following Software and Tools:

| Software and Tools                        | Version |
| :---                                      | :----:  |
| ModusToolbox Software Environment         | 3.4     |
| GCC Compiler                              | 11.3    |
| ARM Compiler                              | 6.16    |

Minimum required ModusToolbox Software Environment: v3.2

### More information
* [Infineon GitHub](https://github.com/Infineon)
* [ModusToolbox](https://www.infineon.com/cms/en/design-support/tools/sdk/modustoolbox-software)

---
(c) 2022-2024, Cypress Semiconductor Corporation (an Infineon company) or an affiliate of Cypress Semiconductor Corporation. All rights reserved.
