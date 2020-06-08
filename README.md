# Gustometer scripts repository
### Francesco Pudda, July, 2019

In this repository I'm sharing scripts I wrote during my master thesis project. The different folders represent different stages of the project and are written in Italian for sharing with future students. I might translate them into english in the future (at least comments).
A gustometer is a tongue stimolation device for recording gustotory evoked potentials. I had to design and develop every part of it whose a thorough explanation can be found in my thesis [1][tesi] (in italian onfortunately).

### FirmwareGustometro

In this folder it is located the firmware of the Arduino controller used to control the pumps of the device. The firmware is written in Arduino language which is a semplified version of C++. The main loop is in ArduinoFirmware.ino while additional functions called from the loop are in FunzioniAggiuntive.ino.

### GustometroGUI

Here there are scripts for the GUI that controls the microcontroller. It is written in Processing (Java) and its purpose is to send coded commands to Arduino that will execute them.

### LibreriaModificata

In this folder a couple of changed file of the AccelStepper Arduino library. This was done to change a low level behaviour that would hinder the process of device calibration. More info in my thesis [1][tesi].

### ScriptPythonDiAnalisi

Finally the scripts for analysing the calibration signals recorded. These are written in Python and there are different scripts according to the protocol used.

[tesi]: https://drive.google.com/file/d/1MpWf74F7Askw95WlKBHsPX3RWCzP9pI4/view?usp=sharing
