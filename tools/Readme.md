# MiSTer Game and Watch Game Converter Tool
I would like to thank Tonton for his work with the generator!!

To convert a game yourself, find its MAME ROM and artwork files.
Keep in mind that only games that use the SM-510 MCU are supported at the moment. You can check which games use which MCU in the MAME sourcecode linked below.
Open Tools/Generator.html, in an Edge or Chrome browser.

In the yellow layers drop-down on the left:
Select the 'BG1' layer, load a background PNG image into it.
Select the 'SVG1' layer, load an LCD graphics SVG image into it.

Now correctly position and scale the LCD graphics layer, using the position and scale controls next to the layer drop-down.
You can also enter the x, y, w and h values manually.
Look all around the backdrop image for areas where the LCD graphics should align correctly with the background.
(keep in mind that the actual Game and Watch games often don't align very precisely)
For games with two screens, use BG2 and SVG2 for the second screen. Manually entering scaling and positioning values helps for a quick initial layout.

To disable anti-aliasion (it is currently causing artifacts with some games) enter a mask expansion value of zero.

Don't forget to select the correct ROM binary.

To set the correct button assignments in the Kn/Sn drop-down grid below, look at the section of your game in the MAME G&W sourcecode here:
https://github.com/mamedev/mame/blob/master/src/mame/drivers/hh_sm510.cpp
The order in the grid is the same as reading order, left to right, top to bottom.
The buttons might be named slightly differently in the code. Often occuring is TIME, GAME B, GAME A, ALARM.
Also, often a whole row will only have one button assigned.

Don't change the default time location value.

Finally, press the yellow 'export' button all the way on the right to save your bin file.
Place it in the 'games/Game & Watch' (with spaces) folder of your MiSTer.

If you would like to save your current settings, to reuse or edit them another time, there are two buttons and a text field, at the bottom of the Generator page.
The left button converts your current settings to a text code, copy and save this to save your current settings.
The right button will load your settings from a previously saved text code, after you paste it into the text field.
Manually load your graphics layers again before loading the settings. The ROM file will also have to be manually loaded again.
