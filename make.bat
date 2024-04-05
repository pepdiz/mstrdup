@echo off
set P=mstrdup.exe
tclkitsh.exe sdx.kit wrap mdup -runtime tclkit.exe
move /y mdup %P%
echo.
echo you can copy the file %P% to the destination folder of your choice
echo copy mdup.cfg file to your home folder and change passwords properly
      
