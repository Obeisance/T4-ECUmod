This repository contains s-record files for the MC68376 processor
in a Lotus Elise T4 ECU. Some of the code is based on the 
ECU ROM.

Use the DaftOBD program (another of my repositories) to upload
this code to the ECU.

Assembly code files (*.X68) can be opened, modified and compiled 
using the EASy68k development and simulation environment:

http://www.easy68k.com/

The s-record (*.S68) can be integrated into a binary file using the EASyBIN 
utility that comes with EASy68k- open the binary, then open the 
s-record. Change the bounds of the binary file range back to 0x0 
thru 0x80000 and edit any binary data as necessary in order to access
the modified code. Then save the binary file. The resulting file should be
512kB in size.

-Obeisance