package require tdom
package provide app-mdup 0.1.0

namespace eval CFG { 
	package require fileutil
	proc PARAMS {} {
		list ADMIN_USER1 PWD1 ADMIN_USER2 PWD2 PRJSRC1 PRJSRC2 \
		      DEPLOY_DIR DEPLOY_HIST_PATH PATH_PROJECTDUPLICATE 		      
	}	
	# read params defined in config file f
	proc read f {
		try {set F [::fileutil::grep {=} $f]} on error r {return $r}
		foreach line $F { 
			set asig [split [lindex [split $line :] end] =] 
			if {[lsearch [::CFG::PARAMS] [lindex $asig 0]]>=0} {		
				set ::CFG::[lindex $asig 0] [lindex $asig 1]
			}
		}
	}
	# set default params, the variables set here should be a subset of PARAMS
	proc defaults {} {
		set ::CFG::ADMIN_USER1 {Administrator}
		set ::CFG::ADMIN_USER2 {Administrator}
		set ::CFG::PRJSRC1 {PRODUCCION}
		set ::CFG::PRJSRC2 {DESARROLLO}
		set ::CFG::DEPLOY_DIR {DesplieguesACME}
		set ::CFG::DEPLOY_HIST_PATH {T:/DATAWAREHOUSE/duplicado de proyectos}
		set ::CFG::PATH_PROJECTDUPLICATE {C:/Program Files (x86)/Common Files/MicroStrategy/ProjectDuplicate.exe}		
	}
	# write params to file f
	proc write f {		
		set fp [open $f w]
		foreach p [::CFG::vars] {
			puts $fp "$p=[set $p]"
		}
		close $fp
	}
	# return all vars registered
	proc vars {} {
		info vars ::CFG::*
	}
	# return all vars in a list
	proc lvars {} {
		join [lmap x [::CFG::vars] {list $x [set $x]}]
	}
	# check the existence of fully qualified var v 
	proc exist? v { return [expr {[info vars $v] != ""}] }
}


proc exitmessage m {
	wm withdraw .
	tk_messageBox -message "$m" -icon error -type ok -title "Duplicador ACME"
	exit
}

# config file
set CONFIG_FILE mdup.cfg
set HOME_DIR $env(HOME)

# default configuration variables
CFG::defaults
CFG::read [file join $::starkit::topdir $CONFIG_FILE]
CFG::read [file join $HOME_DIR $CONFIG_FILE]

if { ! [::CFG::exist? ::CFG::PWD1] || ! [::CFG::exist? ::CFG::PWD2] || $::CFG::PWD1 == "" || $::CFG::PWD2 == "" } {
	exitmessage "Error en parámetros, contraseñas incorrectas.\nEdita el fichero $CONFIG_FILE en el directorio $HOME_DIR para establecer las contraseñas PWD1 y PWD2"
}

if { ! [::CFG::exist? ::CFG::PATH_PROJECTDUPLICATE] || $::CFG::PATH_PROJECTDUPLICATE == "" || ! [file exists $::CFG::PATH_PROJECTDUPLICATE] } {
	exitmessage "$::CFG::PATH_PROJECTDUPLICATE \n No se puede encontrar la herramienta duplicateproject.exe.\nEdita el fichero $CONFIG_FILE en el directorio $HOME_DIR para establecer la ruta correcta a duplicateproject.exe"
}

set prg [lindex [split $argv0 /] end-1]
set dirDespliegue $::CFG::DEPLOY_DIR
set pathDespliegue [file join "C:/" $dirDespliegue]
set tmpxml [file join $env(TEMP) dup.xml]
set pathAmtega [file join $::CFG::DEPLOY_HIST_PATH $dirDespliegue]
set ficlogo [file join $::starkit::topdir wcoy4.gif]

if {[file exists $tmpxml]} {file delete $tmpxml}
	
proc elOtroLado { host } {
	if { $host == $::CFG::PRJSRC1 } {
		return $::CFG::PRJSRC2
	} else {
		return $::CFG::PRJSRC1
	}
}

proc makeTempXML { org dest nomprj desprj prlog stlog evlog } {
	global tmpxml

	set USR($::CFG::PRJSRC1) $::CFG::ADMIN_USER1
	set USR($::CFG::PRJSRC2) $::CFG::ADMIN_USER2

	set ficxml [file join $::starkit::topdir duplicado.xml]
	set fxml [open $ficxml]
	set XML [read $fxml]
	close $fxml

	set doc [dom parse $XML]
	set root [$doc documentElement]
	set orgnode [$root selectNodes {/MicroStrategyDuplicate/SourceProjectSource/PropertyDef[@Name='Name']}]
	set destnode [$root selectNodes {/MicroStrategyDuplicate/DestinationProjectSource/PropertyDef[@Name='Name']}]
	set orgusrnode [$root selectNodes {/MicroStrategyDuplicate/SourceProjectSource/PropertyDef[@Name='Login']}]
	set destusrnode [$root selectNodes {/MicroStrategyDuplicate/DestinationProjectSource/PropertyDef[@Name='Login']}]
	set orgprjnode [$root selectNodes {/MicroStrategyDuplicate/SourceProject/PropertyDef[@Name='Name']}]
	set destprjnode [$root selectNodes {/MicroStrategyDuplicate/DestinationProject/PropertyDef[@Name='Name']}]
	set destprjdesnode [$root selectNodes {/MicroStrategyDuplicate/DestinationProject/PropertyDef[@Name='Description']}]
	set processlognode [$root selectNodes {/MicroStrategyDuplicate/LogFiles/ProcessLogFile/PropertyDef[@Name='Location']}]
	set statlognode [$root selectNodes {/MicroStrategyDuplicate/LogFiles/StatisticsLogFile/PropertyDef[@Name='Location']}]
	set eventlognode [$root selectNodes {/MicroStrategyDuplicate/LogFiles/Events/PropertyDef[@Name='Location']}]

	$orgnode setAttribute Value $org
	$destnode setAttribute Value $dest
	$orgprjnode setAttribute Value $nomprj
	$orgusrnode setAttribute Value $USR($org)
	$destprjnode setAttribute Value $nomprj
	$destprjdesnode setAttribute Value $desprj
	$destusrnode setAttribute Value $USR($dest)
	$processlognode setAttribute Value  $prlog 	
	$statlognode setAttribute Value $stlog  	 
	$eventlognode setAttribute Value $evlog  	

	set ftmp [open $tmpxml w]
	puts $ftmp [$root asXML]
	close $ftmp
}

proc copiarprj { org dest nomprj desprj } {
# return 1 if error , 0 if success
	global tmpxml pathDespliegue carpetaDespliegue pathAmtega

	set PW($::CFG::PRJSRC1) $::CFG::PWD1
	set PW($::CFG::PRJSRC2) $::CFG::PWD2
	set res 0
	
	if {[catch {
		set orgpw $PW($org)
		set destpw $PW($dest)
		}]} {puts "origen o destino erróneo"; return 1}
	
	set momento [clock format [clock seconds] -format %Y%m%d_%H%M%S]
	set carpetaDespliegue [file join $pathDespliegue [string map {" " _} $nomprj]_$momento]

	makeTempXML $org $dest $nomprj $desprj \
		[string map {/ \\} "${carpetaDespliegue}/process.log"] \
		[string map {/ \\} "${carpetaDespliegue}/stat.log"] \
		[string map {/ \\} "${carpetaDespliegue}/event.log"] 
		
	if {[file exists $tmpxml] && [file size $tmpxml]  > 0}  {
		set pathexe $::CFG::PATH_PROJECTDUPLICATE
		if {![file exists $pathexe]} {return 1}
		set res [catch {
			file mkdir $carpetaDespliegue
			exec $pathexe -f $tmpxml -sp $orgpw -dp $destpw
		} results options]
		if {$res} {
			cleanup $carpetaDespliegue 
		} else {
			set finfo [open [file join $carpetaDespliegue info.txt] w]
			puts $finfo "Copia de $nomprj \n origen: $org \n destino: $dest \n proyecto origen: $nomprj \n proyecto destino: $nomprj \n descripción: $desprj "
			close $finfo
			
			if { [file isdirectory $pathAmtega]} {
				file copy $carpetaDespliegue $pathAmtega
			}
		}
	}
	if {[file exists $tmpxml]} {file delete $tmpxml}
	return res
}

proc cleanup folder {
	if {[file isdirectory $folder]} {
		file delete -force $folder
	}
}

if {! [file isdirectory $pathDespliegue]} {
	if {[file exists $pathDespliegue]} {file rename $pathDespliegue "${pathDespliegue}_ [clock format [clock seconds] -format %Y%m%d%H%M].bak"}
	file mkdir $pathDespliegue
}

if {! [file isdirectory $pathAmtega]} {
	if {[file exists $pathAmtega]} {file rename $pathAmtega "${pathAmtega}_ [clock format [clock seconds] -format %Y%m%d%H%M].bak"}
	catch {file mkdir $pathAmtega} err resu
}

if { $argc > 0 } {
	wm withdraw .
	if {[lindex $argv 0] == "?" } {
		tk_messageBox -message "sintaxis:\n $prg ORIGEN DESTINO NOMBREPRJ \[DESCRIPCION\]\n\no sin parámetros para uso interactivo" -icon info -type ok -title "Duplicador ACME"
	} else {
		copiarprj [lindex $argv 0] [lindex $argv 1] [lindex $argv 2] [lindex $argv 3]	
		if {[file exists $tmpxml]} {file delete $tmpxml}	
	}
	exit
} else {

	package require Tk
	bind . <Destroy> { if {[file exists $tmpxml]} {file delete $tmpxml}; exit }
 
	wm resizable . 0 0
	wm minsize . 350 130
	wm title . "Duplicador ACME"
	#wm geometry . 300x200+100+100
	image create photo .coy -format gif -file $ficlogo
	frame .f 
	pack .f
	label .f.ll -image .coy
	pack .f.ll -side left 
	label .f.l1 -text "Copiar a: "
	pack .f.l1 -side left
	radiobutton .f.rb1 -variable dest -value $::CFG::PRJSRC1 -text $::CFG::PRJSRC1
	pack .f.rb1 -side left
	radiobutton .f.rb2 -variable dest -value $::CFG::PRJSRC2 -text $::CFG::PRJSRC2
	pack .f.rb2 -side left
	label .l2 -text "Nombre de Proyecto"
	pack .l2
	entry .np -textvariable nombreprj
	pack .np -fill both
	label .l3 -text "Descripción del Proyecto"
	pack .l3
	entry .dp -textvariable desprj
	pack .dp -fill both
	button .b -text "Copiar proyecto" -command {copiarprj [elOtroLado $dest] $dest $nombreprj $desprj}
	pack .b
	.f.rb2 select
 
}
