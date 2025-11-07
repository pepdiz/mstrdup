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
 			set asig [split $line =]
			set vname [lindex [split [lindex $asig 0] :] end]
			set vval  [lindex $asig end] 
			if {[lsearch [::CFG::PARAMS] $vname]>=0} {	
				set ::CFG::$vname $vval
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

set myVlog 0
set CONSOLA 1

# config file
set CONFIG_FILE mdup.cfg
set HOME_DIR $env(HOME)

# default configuration variables
CFG::defaults
CFG::read [file join $::starkit::topdir $CONFIG_FILE]
CFG::read [file join $HOME_DIR $CONFIG_FILE]

if { ! [::CFG::exist? ::CFG::PWD1] || ! [::CFG::exist? ::CFG::PWD2] || $::CFG::PWD1 == "" || $::CFG::PWD2 == "" } {
	exitmessage "Error en parametros, contraseñas incorrectas.\nEdita el fichero $CONFIG_FILE en el directorio $HOME_DIR para establecer las contraseÃ±as PWD1 y PWD2"
}

if { ! [::CFG::exist? ::CFG::PATH_PROJECTDUPLICATE] || $::CFG::PATH_PROJECTDUPLICATE == "" || ! [file exists $::CFG::PATH_PROJECTDUPLICATE] } {
	exitmessage "$::CFG::PATH_PROJECTDUPLICATE \n No se puede encontrar la herramienta projectduplicate.exe.\nEdita el fichero $CONFIG_FILE en el directorio $HOME_DIR para establecer la ruta correcta a la herramienta"
}

set prg [lindex [split $argv0 /] end-1]
set dirDespliegue $::CFG::DEPLOY_DIR
set pathDespliegue [file join "C:/" $dirDespliegue]
set tmpxml [file join $env(TEMP) dup.xml]
set tmpcprj [file join $env(TEMP) prj.txt ]
set pathAmtega [file join $::CFG::DEPLOY_HIST_PATH $dirDespliegue]
set ficlogo [file join $::starkit::topdir wcoy4.gif]

proc cleanupTMP {} {
	global tmpxml tmpcprj
	file delete -force $tmpxml
	file delete -force $tmpcprj
}

proc exitmessage m {
	wm withdraw .
	tk_messageBox -message "$m" -icon error -type ok -title "Duplicador ACME"
	exit
}

proc err m { 
	tk_messageBox -message "$m" -icon error -type ok -title "Duplicador ACME"  
}

proc msg m {
	#~ global CONSOLA
	#~ if { $CONSOLA == 1} {
		#~ puts "$m\n"
	#~ } else {
		#~ tk_messageBox -message "$m" -icon error -type ok -title "Duplicador ACME"  
	#~ }
	# en modo consola también está en modo gráfico, así que tk_messageBox en lugar de puts
	tk_messageBox -message "$m" -title "Duplicador ACME"  
}

proc getProjects {prjsrc pw} {
	global tmpcprj
	set lprj [list]
	if {[auto_execok cmdmgr]!="" && [file readable $tmpcprj] } {
		set rex [exec {*}[auto_execok cmdmgr] -f $tmpcprj -n $prjsrc -u Administrator -p $pw -stoponerror -showoutput]	
		foreach {_ prj} [regexp -all -inline {Nombre = ([^\n]*)\n} $rex] { lappend lprj $prj }
	}
	return $lprj
}

proc cleanup folder {
	if {[file isdirectory $folder]} {
		file delete -force $folder
	}
}

 proc setupTMP {} {
	global tmpxml tmpcprj env
	set tmpxml [file join $env(TEMP) dup.xml]
	set tmpcprj [file join $env(TEMP) prj.txt ]
	set cprj [file join $::starkit::topdir prj.txt]
	file copy -force $cprj $tmpcprj	
#	if {![file exists $tmpcprj]} { err "no existe $tmpcprj" }
}

setupTMP

# Array para contener los proyectos de los Project Sources indicados en la configuracion
set PRJSRC($::CFG::PRJSRC1) [getProjects $::CFG::PRJSRC1 $::CFG::PWD1]
set PRJSRC($::CFG::PRJSRC2) [getProjects $::CFG::PRJSRC2 $::CFG::PWD2]


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
	global tmpxml pathDespliegue pathAmtega

## 	foreach x [list "origen $org" "destino $dest" "nombre_proyecto $nomprj" ] {
 # 		lassign $x n v
 # 		if {$v==""} {msg "Se debe indicar un valor para $n" } 
 # 	}
 ##
	if { $nomprj == "" } {
		msg "Se debe indicar un Nombre de Proyecto válido"
		return 1
	}
	
	if {! ( ( $org == "PRODUCCION" && $dest == "DESARROLLO" ) || 
	         ( $org == "DESARROLLO" && $dest == "PRODUCCION" ) ) } {
		 msg "Error indicando el destino al que copiar"
		 return 1
      	}
	
	set PW($::CFG::PRJSRC1) $::CFG::PWD1
	set PW($::CFG::PRJSRC2) $::CFG::PWD2
	set res 0
	
	if {[catch {
		set orgpw $PW($org)
		set destpw $PW($dest)
		}]} {log "origen o destino erroneo"; return 1}
	
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
#log " $results"
		if {$res} {
log "error $res - cleanup $carpetaDespliegue"
			cleanup $carpetaDespliegue 
		} else {
			set finfo [open [file join $carpetaDespliegue info.txt] w]
			puts $finfo "Copia de $nomprj \n origen: $org \n destino: $dest \n proyecto origen: $nomprj \n proyecto destino: $nomprj \n descripcion: $desprj "
			close $finfo
			
			log "Copia de $nomprj de $org a $dest en $carpetaDespliegue"
			
			if { [file isdirectory $pathAmtega]} {
				file copy $carpetaDespliegue $pathAmtega
			}
		}
	} else {
		log "error en fichero xml"
	}
	if {[file exists $tmpxml]} {file delete $tmpxml}
	return res
}

proc logOnOff {} {
	if {$::myVlog == 1} {
		pack .l2
	} else {
		pack forget .l2
	}
}

proc log l {
	global CONSOLA
	if { $CONSOLA == 1} {
		msg "$l\n"
	} else {
 		.l2.fl.t configure -state normal
		.l2.fl.t insert end "$l\n"
		.l2.fl.t configure -state disabled
	}
}

proc showConfig {} {
  msg "[join [lmap x [::CFG::vars] {list $x [set $x]}] "\n" ]"
}

proc loadPrj ps {
	global PRJSRC
	.np set ""
	.np configure -values $PRJSRC($ps)
	if {[llength  $PRJSRC($ps)] > 0} { .np configure -state readonly } else { .np configure -state normal }
}

if {! [file isdirectory $pathDespliegue]} {
	if {[file exists $pathDespliegue]} {file rename $pathDespliegue "${pathDespliegue}_ [clock format [clock seconds] -format %Y%m%d%H%M].bak"}
	file mkdir $pathDespliegue
}

if {! [file isdirectory $pathAmtega]} {
	if {[file exists $pathAmtega]} {file rename $pathAmtega "${pathAmtega}_ [clock format [clock seconds] -format %Y%m%d%H%M].bak"}
	catch {file mkdir $pathAmtega} err resu
}

if {[file exists $tmpxml]} {file delete $tmpxml}

if { $argc > 0 } {
	wm withdraw .
	if {[lindex $argv 0] == "?" } {
		msg "sintaxis:\n $prg ORIGEN DESTINO NOMBREPRJ \[DESCRIPCION\]\n\no sin parámetros para uso interactivo"
	} else {
		copiarprj [lindex $argv 0] [lindex $argv 1] [lindex $argv 2] [lindex $argv 3]	
		cleanupTMP	
	}
	exit
} else {
	set CONSOLA 0
	
	package require Tk

	bind . <Destroy> {  cleanupTMP; exit;  }
    
	wm resizable . 0 0
	wm minsize . 350 130
	wm title . "Duplicador ACME"
	image create photo .coy -format gif -file $ficlogo
	frame .f 
	pack .f
	label .f.ll -image .coy
	pack .f.ll -side left 
	label .f.l1 -text "Copiar a: "
	pack .f.l1 -side left
	# cada vez que cambie el copiar a se recarga la lista del elemento adecuado del array
	radiobutton .f.rb1 -variable dest -value $::CFG::PRJSRC1 -text $::CFG::PRJSRC1 -command "loadPrj [elOtroLado $::CFG::PRJSRC1]"
	pack .f.rb1 -side left
	radiobutton .f.rb2 -variable dest -value $::CFG::PRJSRC2 -text $::CFG::PRJSRC2 -command "loadPrj [elOtroLado $::CFG::PRJSRC2]"
	pack .f.rb2 -side left
	label .lab2 -text "Nombre de Proyecto"
	pack .lab2
#	entry .np -textvariable nombreprj
	ttk::combobox .np -textvariable nombreprj
	pack .np -fill both
	label .lab3 -text "Descripcion del Proyecto"
	pack .lab3
	entry .dp -textvariable desprj
	pack .dp -fill both

	frame .l1
	pack .l1 -fill both 

#	button .l1.c -text "C" -command {showConfig}
#	pack .l1.c -side left
		
	checkbutton .l1.cb -text "L" -variable myVlog -command {logOnOff}
	pack .l1.cb -side left

	button .l1.b -text "Copiar proyecto" -command {copiarprj [elOtroLado $dest] $dest $nombreprj $desprj}
	pack .l1.b -side left -expand 1 

	# Line 2: Frame containing a text widget with scrollbars
	frame .l2
	pack .l2  -fill both 
	frame .l2.fl
	pack .l2.fl  -fill both -expand 1
	text .l2.fl.t -height 10 -width 40 -state disabled -yscrollcommand ".l2.fl.vsb set" -xscrollcommand ".l2.hsb set" -wrap none
	scrollbar .l2.fl.vsb -orient vertical -command ".l2.fl.t yview"
	pack .l2.fl.t -side left
	pack .l2.fl.vsb -side left  -fill y
	scrollbar .l2.hsb -orient horizontal -command ".l2.fl.t xview"
	pack .l2.hsb -fill x
	

	logOnOff

log "fichero configuración en $HOME_DIR "

	loadPrj [elOtroLado $::CFG::PRJSRC2]
	.f.rb2 select

}


