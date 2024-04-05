# mstrdup
A wrapper around microstrategy tools to duplicate a project

The intended use is to duplicate a MicroStrategy project from one project source to another, usually from different environments. 
Every duplication is saved in a deploy history path and uses a temp directory for internal stuff (DEPLOY_DIR).
The duplication is based on microstrategy "projectduplicate" tool so you must provide the full path to the tool.

# Dependencies
This tools requires a MicroStrategy installation with the following tools installed:
* command manager
* ProjectDuplicate.exe

# Security issues
* The project keep passwords in clear text in a config file (you should set the relevant ones in the file and set up right permissions for it)
* It also relies on hard coded paths you should update to fullfill your needs by setting properties in config file

# Build
* clone the repository
* run make.bat at root folder

# Install 
Just copy the mdup.exe file to wherever you want

# Configuration
All configuration is done in a the configuration file *mdup.cfg* which must be located at user home directory. 
To know the right place just run mdup.exe first time (when there's no configuration file) and a message will be displayed telling the configuration file name and location.

Allowed properties in configuration file are:
* ADMIN_USER1
* PWD1
* ADMIN_USER2
* PWD2
* PRJSRC1
* PRJSRC2
* DEPLOY_DIR
* DEPLOY_HIST_PATH
* PATH_PROJECTDUPLICATE 	

PWD1 and PWD2 are required to be set or the program refuses to run. All the other properties are optional and will use default values, but you should change PATH_PROJECTDUPLICATE to fit your environment.



