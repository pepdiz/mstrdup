# mstrdup
A wrapper around microstrategy tools to duplicate a project

# Dependencies
This tools requires a MicroStrategy installation with the following tools installed:
* command manager
* ProjectDuplicate.exe

# Security issues
* The code contains administrative passwords in clear text (you should set the relevant ones in special variables in code)
* It also relies on hard coded paths you should update to fullfill your needs


