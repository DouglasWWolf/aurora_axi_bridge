# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "VECTOR_00" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_01" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_02" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_03" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_04" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_05" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_06" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_07" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_08" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_09" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_10" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_11" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_12" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_13" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_14" -parent ${Page_0}
  ipgui::add_param $IPINST -name "VECTOR_15" -parent ${Page_0}


}

proc update_PARAM_VALUE.VECTOR_00 { PARAM_VALUE.VECTOR_00 } {
	# Procedure called to update VECTOR_00 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_00 { PARAM_VALUE.VECTOR_00 } {
	# Procedure called to validate VECTOR_00
	return true
}

proc update_PARAM_VALUE.VECTOR_01 { PARAM_VALUE.VECTOR_01 } {
	# Procedure called to update VECTOR_01 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_01 { PARAM_VALUE.VECTOR_01 } {
	# Procedure called to validate VECTOR_01
	return true
}

proc update_PARAM_VALUE.VECTOR_02 { PARAM_VALUE.VECTOR_02 } {
	# Procedure called to update VECTOR_02 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_02 { PARAM_VALUE.VECTOR_02 } {
	# Procedure called to validate VECTOR_02
	return true
}

proc update_PARAM_VALUE.VECTOR_03 { PARAM_VALUE.VECTOR_03 } {
	# Procedure called to update VECTOR_03 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_03 { PARAM_VALUE.VECTOR_03 } {
	# Procedure called to validate VECTOR_03
	return true
}

proc update_PARAM_VALUE.VECTOR_04 { PARAM_VALUE.VECTOR_04 } {
	# Procedure called to update VECTOR_04 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_04 { PARAM_VALUE.VECTOR_04 } {
	# Procedure called to validate VECTOR_04
	return true
}

proc update_PARAM_VALUE.VECTOR_05 { PARAM_VALUE.VECTOR_05 } {
	# Procedure called to update VECTOR_05 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_05 { PARAM_VALUE.VECTOR_05 } {
	# Procedure called to validate VECTOR_05
	return true
}

proc update_PARAM_VALUE.VECTOR_06 { PARAM_VALUE.VECTOR_06 } {
	# Procedure called to update VECTOR_06 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_06 { PARAM_VALUE.VECTOR_06 } {
	# Procedure called to validate VECTOR_06
	return true
}

proc update_PARAM_VALUE.VECTOR_07 { PARAM_VALUE.VECTOR_07 } {
	# Procedure called to update VECTOR_07 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_07 { PARAM_VALUE.VECTOR_07 } {
	# Procedure called to validate VECTOR_07
	return true
}

proc update_PARAM_VALUE.VECTOR_08 { PARAM_VALUE.VECTOR_08 } {
	# Procedure called to update VECTOR_08 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_08 { PARAM_VALUE.VECTOR_08 } {
	# Procedure called to validate VECTOR_08
	return true
}

proc update_PARAM_VALUE.VECTOR_09 { PARAM_VALUE.VECTOR_09 } {
	# Procedure called to update VECTOR_09 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_09 { PARAM_VALUE.VECTOR_09 } {
	# Procedure called to validate VECTOR_09
	return true
}

proc update_PARAM_VALUE.VECTOR_10 { PARAM_VALUE.VECTOR_10 } {
	# Procedure called to update VECTOR_10 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_10 { PARAM_VALUE.VECTOR_10 } {
	# Procedure called to validate VECTOR_10
	return true
}

proc update_PARAM_VALUE.VECTOR_11 { PARAM_VALUE.VECTOR_11 } {
	# Procedure called to update VECTOR_11 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_11 { PARAM_VALUE.VECTOR_11 } {
	# Procedure called to validate VECTOR_11
	return true
}

proc update_PARAM_VALUE.VECTOR_12 { PARAM_VALUE.VECTOR_12 } {
	# Procedure called to update VECTOR_12 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_12 { PARAM_VALUE.VECTOR_12 } {
	# Procedure called to validate VECTOR_12
	return true
}

proc update_PARAM_VALUE.VECTOR_13 { PARAM_VALUE.VECTOR_13 } {
	# Procedure called to update VECTOR_13 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_13 { PARAM_VALUE.VECTOR_13 } {
	# Procedure called to validate VECTOR_13
	return true
}

proc update_PARAM_VALUE.VECTOR_14 { PARAM_VALUE.VECTOR_14 } {
	# Procedure called to update VECTOR_14 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_14 { PARAM_VALUE.VECTOR_14 } {
	# Procedure called to validate VECTOR_14
	return true
}

proc update_PARAM_VALUE.VECTOR_15 { PARAM_VALUE.VECTOR_15 } {
	# Procedure called to update VECTOR_15 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VECTOR_15 { PARAM_VALUE.VECTOR_15 } {
	# Procedure called to validate VECTOR_15
	return true
}


proc update_MODELPARAM_VALUE.VECTOR_00 { MODELPARAM_VALUE.VECTOR_00 PARAM_VALUE.VECTOR_00 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_00}] ${MODELPARAM_VALUE.VECTOR_00}
}

proc update_MODELPARAM_VALUE.VECTOR_01 { MODELPARAM_VALUE.VECTOR_01 PARAM_VALUE.VECTOR_01 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_01}] ${MODELPARAM_VALUE.VECTOR_01}
}

proc update_MODELPARAM_VALUE.VECTOR_02 { MODELPARAM_VALUE.VECTOR_02 PARAM_VALUE.VECTOR_02 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_02}] ${MODELPARAM_VALUE.VECTOR_02}
}

proc update_MODELPARAM_VALUE.VECTOR_03 { MODELPARAM_VALUE.VECTOR_03 PARAM_VALUE.VECTOR_03 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_03}] ${MODELPARAM_VALUE.VECTOR_03}
}

proc update_MODELPARAM_VALUE.VECTOR_04 { MODELPARAM_VALUE.VECTOR_04 PARAM_VALUE.VECTOR_04 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_04}] ${MODELPARAM_VALUE.VECTOR_04}
}

proc update_MODELPARAM_VALUE.VECTOR_05 { MODELPARAM_VALUE.VECTOR_05 PARAM_VALUE.VECTOR_05 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_05}] ${MODELPARAM_VALUE.VECTOR_05}
}

proc update_MODELPARAM_VALUE.VECTOR_06 { MODELPARAM_VALUE.VECTOR_06 PARAM_VALUE.VECTOR_06 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_06}] ${MODELPARAM_VALUE.VECTOR_06}
}

proc update_MODELPARAM_VALUE.VECTOR_07 { MODELPARAM_VALUE.VECTOR_07 PARAM_VALUE.VECTOR_07 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_07}] ${MODELPARAM_VALUE.VECTOR_07}
}

proc update_MODELPARAM_VALUE.VECTOR_08 { MODELPARAM_VALUE.VECTOR_08 PARAM_VALUE.VECTOR_08 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_08}] ${MODELPARAM_VALUE.VECTOR_08}
}

proc update_MODELPARAM_VALUE.VECTOR_09 { MODELPARAM_VALUE.VECTOR_09 PARAM_VALUE.VECTOR_09 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_09}] ${MODELPARAM_VALUE.VECTOR_09}
}

proc update_MODELPARAM_VALUE.VECTOR_10 { MODELPARAM_VALUE.VECTOR_10 PARAM_VALUE.VECTOR_10 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_10}] ${MODELPARAM_VALUE.VECTOR_10}
}

proc update_MODELPARAM_VALUE.VECTOR_11 { MODELPARAM_VALUE.VECTOR_11 PARAM_VALUE.VECTOR_11 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_11}] ${MODELPARAM_VALUE.VECTOR_11}
}

proc update_MODELPARAM_VALUE.VECTOR_12 { MODELPARAM_VALUE.VECTOR_12 PARAM_VALUE.VECTOR_12 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_12}] ${MODELPARAM_VALUE.VECTOR_12}
}

proc update_MODELPARAM_VALUE.VECTOR_13 { MODELPARAM_VALUE.VECTOR_13 PARAM_VALUE.VECTOR_13 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_13}] ${MODELPARAM_VALUE.VECTOR_13}
}

proc update_MODELPARAM_VALUE.VECTOR_14 { MODELPARAM_VALUE.VECTOR_14 PARAM_VALUE.VECTOR_14 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_14}] ${MODELPARAM_VALUE.VECTOR_14}
}

proc update_MODELPARAM_VALUE.VECTOR_15 { MODELPARAM_VALUE.VECTOR_15 PARAM_VALUE.VECTOR_15 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VECTOR_15}] ${MODELPARAM_VALUE.VECTOR_15}
}

