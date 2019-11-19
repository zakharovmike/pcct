# pcct - placardi component tool
Component manager for [placardi/xynohm](https://github.com/placardi/xynohm)

Make managing components that much easier!

## How to use

* Initial setup

  * Copy the contents of ```support-files``` to ```~/Library/Application\ Support/pcct```
  * Compile the project and put the executable into ```/usr/local/bin/```

* Create path to your xynohm project

  * Run ```pcct sp <path/to/project>```
  * Example: ```~/<user>/Documents/git/<project-folder>```
  
* Create new component
  
  * Run ```pcct cc <component-name>```
  * Example: ```pcct cc header``` will create a component called ```header``` in ```<project-name>/src/components```
  * Can also create nested components like so: ```pcct cc side-menu/side-menu-item```
  
* Move or rename component

  * Run ```pcct mc <old/component/path-or-name> <new/component/path-or-name>```
  
* Delete component

  * Run ```pcct dc <component/to/delete>```
