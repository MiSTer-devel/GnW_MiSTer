# MiSTer Port of Game and Watch Games

The Game and Watch handheld devices emulator for MiSTer FPGA by Pierco.

This is still a work in progress:

- RTC is not working yet.
- SM5A is not implemented.
- SM511 is not implemented.
- Timing is not perfect.
- Two screen games have problems with anti-aliasing.

The core comes with a ROM generator so in theory, it could be possible to create new Game and Watch games. A SM510 assembler exists here: https://github.com/trevorjay/marios-binary-factory


I would like to thank Tonton for his work with the generator!! Thanks to him, pre-compiled games are available on archive.org:
https://archive.org/download/gnw-games

To convert a game yourself, find its MAME ROM and artwork files.
Open Tools/Generator.html, preferrably in an Edge browser.
In the yellow layers drop-down on the left:
Select the 'BG1' layer, load a background PNG image into it.
Select the 'SVG1' layer, load an LCD graphics SVG image into it.
Now correctly position and scale the LCD graphics layer using the position and scale controls, next to the layer drop-down.
You can also enter the x, y, w and h values manually.
Look all around the backdrop image for places where the LCD graphics should align correctly with the background.
For games with two screens, use BG2 and SVG2 for the second screen. Manually entering scaling and positioning values helps for a quick initial layout.
To disable anti-aliasion (it is currently causing artifacts with some games) enter a mask expansion value of zero.
Don't forget to select the correct ROM binary.
To set the correct button assignments in the Kn/Sn drop-down grid below, look at the section of your game in the MAME G&W sourcecode here:
https://github.com/mamedev/mame/blob/master/src/mame/drivers/hh_sm510.cpp
The order in the grid is the same as reading order, left to right, top to bottom.
The buttons might be named slightly differently in the code. Often occuring is TIME, GAME B, GAME A, ALARM.
Also often a whole row will only have one button assigned.
Finally, press the yellow 'export' button all the way on the right to save your bin file.
Place it in the 'games/Game & Watch' (with spaces) folder of your MiSTer.

A big thank you to all my Patreon contributors!!

Ashfall,
Gentlemen's Pixel Club,
Mike Holzinger,
SwedishGojira,
lamarax,
J BG,
Auryn Beorn,
Herbert Krammer,
Dimitris Zongas,
mutman,
Cory Stargel,
Christopher Garland,
Dany Kwan,
Stefan Pausch,
Grumpy Old Gamer,
Dave Ely,
axxxtz,
RaspberryAlpine,
Tonton Kaloun,
Johan Sjöstrand,
Philip Lawson,
Samuel Giroux,
Allen Tipper,
Darren Newman,
Alan Steremberg.
