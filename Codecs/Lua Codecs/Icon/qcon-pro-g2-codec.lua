k_lcd_row_width=56
k_lcd_channel_width=7
k_vpot_min_value=0
k_vpot_max_value=10
k_vpot_spread_max_value=5
k_vpot_center_value=5
k_vpot_spread_scale=(k_vpot_spread_max_value-k_vpot_min_value)/(k_vpot_max_value-k_vpot_min_value)

k_fader_min_value=0
k_fader_max_value=1023
k_ext_controller_min_value=0
k_ext_controller_max_value=127

k_min_peak_value=0
-- FL: Peak max value for vertical. For horizontal it's 0xd.
k_max_peak_value=14
k_peak_meter_update_interval=50

-- 56 = Mackie Control
k_control_model=56

k_unit_channel_count=8

g_selected_model=0
g_num_channels=0
g_num_rows=0

g_no_feedback_items={}
g_min_fader_index=-1
g_max_fader_index=-1
g_min_rotary_index=-1
g_max_rotary_index=-1
g_min_rotary_button_index=-1
g_max_rotary_button_index=-1
g_min_record_button_index=-1
g_max_record_button_index=-1
g_min_solo_button_index=-1
g_max_solo_button_index=-1
g_min_mute_button_index=-1
g_max_mute_button_index=-1
g_min_select_button_index=-1
g_max_select_button_index=-1
g_min_peak_index=-1
g_max_peak_index=-1
g_min_row1_lcd_channel_index=-1
g_max_row1_lcd_channel_index=-1
g_min_row2_lcd_channel_index=-1
g_max_row2_lcd_channel_index=-1
g_min_lcd_row_index=-1
g_max_lcd_row_index=-1
g_assignment_display_index=-1
g_bars_display_index=-1
g_beats_display_index=-1
g_sub_division_display_index=-1
g_ticks_display_index=-1
g_hours_display_index=-1
g_minutes_display_index=-1
g_seconds_display_index=-1
g_cents_display_index=-1
g_smpte_button_index=-1

g_last_input_time = 0
g_last_input_item = -1
g_last_channel_input_time={ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, }
g_last_channel_input_item={}

g_new_peak_enabled_states={}
g_new_peak_level_states={}
g_sent_peak_enabled_states={}
g_sent_peak_level_states={}
-- FL: One for each port.
g_last_peak_update={0, 0}

g_new_display_output_state={}
g_sent_display_output_state={}

-- FL: 2 rows, up to 16 channels
g_lcd_channel_enabled_states={{},{},{},{},{},{},{},{}}
g_lcd_channel_states={{},{},{},{},{},{},{},{}}
g_lcd_row_enabled_states={}
g_lcd_row_states={}

g_new_smpte_led_state=0
g_new_beats_led_state=0
g_sent_smpte_led_state=-1
g_sent_beats_led_state=-1

-- FL: Sticky param texts for C4
g_param_enabled_states={}
g_param_name_states={}
g_param_value_states={}

-- FL: Stores machine state for each channel, to make smaller MIDI messages.
g_new_lcd_output_states={{},{},{},{},{},{},{},{}}
g_sent_lcd_output_states={{},{},{},{},{},{},{},{}}

g_time_millis_show_feedback_msg=2000

g_split_button_index=-1

g_new_split_button_value=0
g_sent_split_button_value=0
g_new_split_enabled=false
g_sent_split_enabled=false



function add_to_split_button(x)
	local new_value=g_new_split_button_value+x
	if new_value>2 then
		new_value=0
	end
	return new_value
end



function from_hex(nr)
	return tonumber(nr,16)
end



function to_hex(nr)
	return string.format("%02x",nr)
end



local function get_port_for_channel(channel)
	local port_no=1
	return port_no
end



local function get_channels_for_port(port)
	assert(port>=1)
	assert(port<=2)
	return 1,8
end



local function get_model_type_for_channel(channel)
	return k_control_model
end



local function get_channel_index_for_channel(channel)
	local index=channel
	return index
end



function make_rotary_control_byte(mode,value)
	-- FL: control_byte=center_dot<<6 + out_mode<<4 + out_value
	if mode==7 then
		-- mode=Off
		control_byte=0
	elseif mode==6 then
		-- mode==On/Off
		if value>0 then
			control_byte=64
		else
			control_byte=0
		end
	elseif mode==5 then
		-- mode==Spread
		control_byte=48+value*k_vpot_spread_scale+1
	elseif mode==4 then
		-- mode==Boost/Cut
		control_byte=16+value+1
	elseif mode==3 then
		-- mode==Wrap
		control_byte=32+value+1
	elseif mode==2 then
		-- mode==Single Dot, Bipolar
		control_byte=value+1
		if value==k_vpot_center_value then
			control_byte=control_byte+64
		end
	else
		-- mode==Single Dot
		control_byte=value+1
	end
	return control_byte
end



function remote_init(manufacturer,model)
	local global_items={}
	local global_auto_inputs={}
	local global_auto_outputs={}

	------------------------------------------------- Faders ------------------------------------------------

	local function MakeFaderMIDIInputMask(channel)
		assert(channel>=1)
		assert(channel<=9)
		local mask="e"..(channel-1).."<?xxx>?yy"
		return mask
	end

	local function MakeFaderMIDIInputValueFormula()
		return "x+y*8"
	end

	local function MakeFaderMIDIOutputMask(channel)
		assert(channel>=1)
		assert(channel<=9)
		local mask="e"..(channel-1).."<0xxx>0yy"
		return mask
	end

	local function MakeFaderMIDIOutputXFormula()
		return "bit.band(value,7)*enabled"
	end

	local function MakeFaderMIDIOutputYFormula()
		return "bit.rshift(value,3)*enabled"
	end

	local function define_faders()
		g_min_fader_index=table.getn(global_items)+1
		for i=1,g_num_channels do
			local item_name="Fader "..i
			table.insert(global_items,{ name=item_name,input="value",output="value",min=k_fader_min_value,max=k_fader_max_value})
			local port_no=get_port_for_channel(i)
			local index=get_channel_index_for_channel(i)
			table.insert(global_auto_inputs,{ name=item_name,pattern=MakeFaderMIDIInputMask(index),value=MakeFaderMIDIInputValueFormula(),port=port_no })
			table.insert(global_auto_outputs,{ name=item_name,pattern=MakeFaderMIDIOutputMask(index),x=MakeFaderMIDIOutputXFormula(),y=MakeFaderMIDIOutputYFormula(),port=port_no })
		end
		g_max_fader_index=table.getn(global_items)
	end

	local function define_master_fader()
		local port_no=1
		local item_name="Master Fader"
		table.insert(global_items,{ name=item_name,input="value",output="value",min=k_fader_min_value,max=k_fader_max_value})
		table.insert(global_auto_inputs,{ name=item_name,pattern=MakeFaderMIDIInputMask(9),value=MakeFaderMIDIInputValueFormula(),port=port_no })
		table.insert(global_auto_outputs,{ name=item_name,pattern=MakeFaderMIDIOutputMask(9),x=MakeFaderMIDIOutputXFormula(),y=MakeFaderMIDIOutputYFormula(),port=port_no })
	end

	------------------------------------------------- Rotaries ------------------------------------------------

	local function MakeRotaryMIDIInputMask(channel)
		assert(channel>=1)
		assert(channel<=k_unit_channel_count)
		local mask="b01"..(channel-1).."<?y??>x"
		return mask
	end

	local function MakeRotaryMIDIInputValueFormula()
		return "x*(1-2*y)"
	end

	local function MakeRotaryMIDIOutputMask(channel)
		assert(channel>=1)
		assert(channel<=k_unit_channel_count)
		local mask="b03"..(channel-1).."xx"
		return mask
	end

	local function MakeRotaryMIDIOutputXFormula()
		return "make_rotary_control_byte(mode,value)*enabled"
	end

	local function define_rotaries()
		g_min_rotary_index=table.getn(global_items)+1
		for i=1,g_num_channels do
			local item_name="Rotary "..i
			local mode_names={"Single Dot","Single Dot, Bipolar","Wrap","Boost/Cut","Spread","On/Off","Off"}
			table.insert(global_items,{ name=item_name, input="delta", output="value", min=0, max=k_vpot_max_value,modes=mode_names })
			local port_no=get_port_for_channel(i)
			local index=get_channel_index_for_channel(i)
			table.insert(global_auto_inputs,{ name=item_name,pattern=MakeRotaryMIDIInputMask(index),value=MakeRotaryMIDIInputValueFormula(),port=port_no })
			table.insert(global_auto_outputs,{ name=item_name,pattern=MakeRotaryMIDIOutputMask(index),x=MakeRotaryMIDIOutputXFormula(),port=port_no })
		end
		g_max_rotary_index=table.getn(global_items)
	end

	----------------------------------------------- Button/LED masks ----------------------------------------------

	local function MakeButtonMIDIInputMask(button_id)
		assert(button_id>=0)
		assert(button_id<=from_hex("67"))
		local mask="90"..to_hex(button_id).."<?xxx>x"
		return mask
	end

	local function MakeButtonInputValueFormula()
		return "x/127"
	end

	local function MakeLEDMIDIOutputMask(led_id)
		assert(led_id>=0)
		assert(led_id<=from_hex("73"))
		local mask="90"..to_hex(led_id).."xx"
		return mask
	end

	local function MakeLEDOutputXFormula()
		return "value*(127-(mode-1)*126)*enabled"
	end

	------------------------------------------------- Rotary buttons ------------------------------------------------

	local function define_rotary_buttons()
		g_min_rotary_button_index=table.getn(global_items)+1
		for i=1,g_num_channels do
			local item_name="Rotary Button "..i
			table.insert(global_items,{ name=item_name, input="button", output="text" })
			local port_no=get_port_for_channel(i)
			local index=get_channel_index_for_channel(i)
			local button_id=from_hex("20")+index-1
			table.insert(global_auto_inputs,{ name=item_name,pattern=MakeButtonMIDIInputMask(button_id),value=MakeButtonInputValueFormula(),port=port_no })
		end
		g_max_rotary_button_index=table.getn(global_items)
	end

	------------------------------------------------- Record buttons ------------------------------------------------

	local function define_record_buttons()
		g_min_record_button_index=table.getn(global_items)+1
		for i=1,g_num_channels do
			local item_name="Record "..i
			table.insert(global_items,{ name=item_name, input="button", output="value", modes={ "Solid", "Flash" } })
			local port_no=get_port_for_channel(i)
			local index=get_channel_index_for_channel(i)
			local button_id=from_hex("00")+index-1
			table.insert(global_auto_inputs,{ name=item_name,pattern=MakeButtonMIDIInputMask(button_id),value=MakeButtonInputValueFormula(),port=port_no })
			table.insert(global_auto_outputs,{ name=item_name,pattern=MakeLEDMIDIOutputMask(button_id),x=MakeLEDOutputXFormula(),port=port_no })
		end
		g_max_record_button_index=table.getn(global_items)
	end

	------------------------------------------------- Solo buttons ------------------------------------------------

	local function define_solo_buttons()
		g_min_solo_button_index=table.getn(global_items)+1
		for i=1,g_num_channels do
			local item_name="Solo "..i
			table.insert(global_items,{ name=item_name, input="button", output="value", modes={ "Solid", "Flash" } })
			local port_no=get_port_for_channel(i)
			local index=get_channel_index_for_channel(i)
			local button_id=from_hex("08")+index-1
			table.insert(global_auto_inputs,{ name=item_name,pattern=MakeButtonMIDIInputMask(button_id),value=MakeButtonInputValueFormula(),port=port_no })
			table.insert(global_auto_outputs,{ name=item_name,pattern=MakeLEDMIDIOutputMask(button_id),x=MakeLEDOutputXFormula(),port=port_no })
		end
		g_max_solo_button_index=table.getn(global_items)
	end

	------------------------------------------------- Mute buttons ------------------------------------------------

	local function define_mute_buttons()
		g_min_mute_button_index=table.getn(global_items)+1
		for i=1,g_num_channels do
			local item_name="Mute "..i
			table.insert(global_items,{ name=item_name, input="button", output="value", modes={ "Solid", "Flash" } })
			local port_no=get_port_for_channel(i)
			local index=get_channel_index_for_channel(i)
			local button_id=from_hex("10")+index-1
			table.insert(global_auto_inputs,{ name=item_name,pattern=MakeButtonMIDIInputMask(button_id),value=MakeButtonInputValueFormula(),port=port_no })
			table.insert(global_auto_outputs,{ name=item_name,pattern=MakeLEDMIDIOutputMask(button_id),x=MakeLEDOutputXFormula(),port=port_no })
		end
		g_max_mute_button_index=table.getn(global_items)
	end

	------------------------------------------------- Select buttons ------------------------------------------------

	local function define_select_buttons()
		g_min_select_button_index=table.getn(global_items)+1
		for i=1,g_num_channels do
			local item_name="Select "..i
			table.insert(global_items,{ name=item_name, input="button", output="value", modes={ "Solid", "Flash" } })
			local port_no=get_port_for_channel(i)
			local index=get_channel_index_for_channel(i)
			local button_id=from_hex("18")+index-1
			table.insert(global_auto_inputs,{ name=item_name,pattern=MakeButtonMIDIInputMask(button_id),value=MakeButtonInputValueFormula(),port=port_no })
			table.insert(global_auto_outputs,{ name=item_name,pattern=MakeLEDMIDIOutputMask(button_id),x=MakeLEDOutputXFormula(),port=port_no })
		end
		g_max_select_button_index=table.getn(global_items)
	end

	------------------------------------------------- Input buttons ------------------------------------------------

	local function define_buttons()
		local inputButtonDefs =
		{
			{ id=from_hex("28"), name="Page Up Button 1", type="inout" },
			{ id=from_hex("2a"), name="Page Down Button 2", type="inout" },
			{ id=from_hex("2c"), name="Pan Button", type="inout" },
			{ id=from_hex("29"), name="Inserts Button", type="inout" },
			{ id=from_hex("2b"), name="EQ Button", type="inout" },
			{ id=from_hex("2d"), name="FX Send Button", type="inout" },

			{ id=from_hex("2e"), name="Fader Bank Left Button" },
			{ id=from_hex("2f"), name="Fader Bank Right Button" },
			{ id=from_hex("30"), name="Channel Left Button" },
			{ id=from_hex("31"), name="Channel Right Button" },

			{ id=from_hex("32"), name="Flip Button", type="inout" },

			{ id=from_hex("34"), name="Name/Value Button", type="inout" },
			{ id=from_hex("35"), name="SMPTE/Beats Button", type="inout" },

			{ id=from_hex("47"), name="Undo Button" },
			{ id=from_hex("33"), name="Redo Button" },
			{ id=from_hex("49"), name="Save Button" },

			{ id=from_hex("36"), name="F1 Button" },
			{ id=from_hex("37"), name="F2 Button" },
			{ id=from_hex("38"), name="F3 Button" },
			{ id=from_hex("39"), name="F4 Button" },
			{ id=from_hex("3a"), name="F5 Button" },
			{ id=from_hex("3b"), name="F6 Button" },
			{ id=from_hex("3c"), name="F7 Button" },
			{ id=from_hex("3d"), name="F8 Button" },

			{ id=from_hex("46"), name="Layer Button", type="inout" },

			{ id=from_hex("4f"), name="Read/Off Button", type="inout" },
			{ id=from_hex("4a"), name="Write Button", type="inout" },
			{ id=from_hex("4b"), name="Sends Button", type="inout" },
			{ id=from_hex("4d"), name="Project Button", type="inout" }, 
			{ id=from_hex("4e"), name="Mixer Button", type="inout" },
			{ id=from_hex("4c"), name="Motors Button", type="inout" },

			{ id=from_hex("54"), name="VST Button", type="inout" },
			{ id=from_hex("55"), name="Master Button", type="inout" },

			{ id=from_hex("5a"), name="Clr Solo Button", type="inout" },
			{ id=from_hex("59"), name="Shift Button", type="inout" },

			{ id=from_hex("57"), name="Frm Left Button", type="inout" },
			{ id=from_hex("58"), name="Frm Right Button", type="inout" },
			{ id=from_hex("56"), name="Loop Button", type="inout" },
			{ id=from_hex("57"), name="PI Button", type="inout" },

			{ id=from_hex("5b"), name="Rewind Button", type="inout" },
			{ id=from_hex("5c"), name="Fast Fwd Button", type="inout" },
			{ id=from_hex("5d"), name="Stop Button", type="inout" },
			{ id=from_hex("5e"), name="Play Button", type="inout" },
			{ id=from_hex("5f"), name="Record Button", type="inout" },

			{ id=from_hex("60"), name="Up Button" },
			{ id=from_hex("61"), name="Down Button" },
			{ id=from_hex("62"), name="Left Button" },
			{ id=from_hex("63"), name="Right Button" },
			{ id=from_hex("64"), name="Zoom Button", type="inout" },
			{ id=from_hex("65"), name="Scrub Button", type="inout" },
		}
		local port_no=1
		for k,v in pairs(inputButtonDefs) do
			local item_name=v.name
			local button_id=v.id
			if (v.type=="inout") then
				table.insert(global_items,{ name=item_name, input="button", output="value", modes={ "Solid", "Flash" } })
				table.insert(global_auto_inputs,{ name=item_name,pattern=MakeButtonMIDIInputMask(button_id),value=MakeButtonInputValueFormula(),port=port_no })
				table.insert(global_auto_outputs,{ name=item_name,pattern=MakeLEDMIDIOutputMask(button_id),x=MakeLEDOutputXFormula(),port=port_no })
			else
				table.insert(global_items,{ name=item_name, input="button", output="text" })
				table.insert(global_auto_inputs,{ name=item_name,pattern=MakeButtonMIDIInputMask(button_id),value=MakeButtonInputValueFormula(),port=port_no })
			end
			-- store some special indexes
			if item_name=="SMPTE/Beats Button" then
				g_smpte_button_index=table.getn(global_items)
			end
			if item_name=="Rewind Button" or item_name=="Fast Fwd Button" or item_name=="Stop Button" or item_name=="Play Button" or item_name=="Record Button" then
				index=table.getn(global_items)
				g_no_feedback_items[index]=true
			end
		end
	end

	------------------------------------------------- LEDs ------------------------------------------------

	local function define_leds()
		local port_no=1
		local LEDDefs =
		{
			{ id=from_hex("18"), name="Select LED 1" },
			{ id=from_hex("19"), name="Select LED 2" },
			{ id=from_hex("1a"), name="Select LED 3" },
			{ id=from_hex("1b"), name="Select LED 4" },
			{ id=from_hex("1c"), name="Select LED 5" },
			{ id=from_hex("1d"), name="Select LED 6" },
			{ id=from_hex("1e"), name="Select LED 7" },
			{ id=from_hex("1f"), name="Select LED 8" },

			{ id=from_hex("36"), name="F1 LED" },
			{ id=from_hex("37"), name="F2 LED" },
			{ id=from_hex("38"), name="F3 LED" },
			{ id=from_hex("39"), name="F4 LED" },
			{ id=from_hex("3a"), name="F5 LED" },
			{ id=from_hex("3b"), name="F6 LED" },
			{ id=from_hex("3c"), name="F7 LED" },
			{ id=from_hex("3d"), name="F8 LED" },

			{ id=from_hex("33"), name="Redo LED" },
			{ id=from_hex("32"), name="Flip LED" },
			{ id=from_hex("4d"), name="Project LED" },
			{ id=from_hex("55"), name="Master LED" },
			{ id=from_hex("46"), name="Layer LED" },
			{ id=from_hex("59"), name="Shift LED" },
			{ id=from_hex("54"), name="VST LED" },
			{ id=from_hex("57"), name="Frm Left LED" },
			{ id=from_hex("58"), name="Frm Right LED" },
			
			{ id=from_hex("71"), name="SMPTE LED" }, -- toggles with uppper
			{ id=from_hex("72"), name="Beats LED" }, -- toggles with lower
			{ id=from_hex("73"), name="Rude Solo LED" },
		}
		for k,v in pairs(LEDDefs) do
			local item_name=v.name
			local button_id=v.id
			table.insert(global_items,{ name=item_name, output="value", min=0, max=1, modes={ "Solid", "Flash" } })
			table.insert(global_auto_outputs,{ name=item_name,pattern=MakeLEDMIDIOutputMask(button_id),x=MakeLEDOutputXFormula(),port=port_no })
		end
	end

	------------------------------------------------- Jog Wheel ------------------------------------------------

	local function MakeJogWheelMIDIInputMask()
		local mask="b03c<?y??>x"
		return mask
	end

	local function MakeJogWheelMIDIInputValueFormula()
		return "x*(1-2*y)"
	end

	local function define_jog_wheel()
		local port_no=1
		local item_name="Jog Wheel"
		table.insert(global_items,{ name=item_name, input="delta", output="text" })
		table.insert(global_auto_inputs,{ name=item_name,pattern=MakeJogWheelMIDIInputMask(i),value=MakeJogWheelMIDIInputValueFormula(),port=port_no })
	end

	------------------------------------------------- Rear Panel Switches ------------------------------------------------

	local function define_rear_switches()
		local inputButtonDefs =
		{
			{ id=from_hex("66"), name="Rear Panel Switch A" },
			{ id=from_hex("67"), name="Rear Panel Switch B" },
		}
		local port_no=1
		for k,v in pairs(inputButtonDefs) do
			local item_name=v.name
			local button_id=v.id
			table.insert(global_items,{ name=item_name, input="value", min=0, max=1 })
			table.insert(global_auto_inputs,{ name=item_name,pattern=MakeButtonMIDIInputMask(button_id),value=MakeButtonInputValueFormula(),port=port_no })
		end
	end

	------------------------------------------------- Rear controller ------------------------------------------------

	local function MakeRearControllerMIDIInputMask()
		local mask="b02exx"
		return mask
	end

	local function MakeRearControllerMIDIInputValueFormula()
		return "x"
	end

	local function define_rear_controller()
		local port_no=1
		local item_name="Rear Panel Controller"
		table.insert(global_items,{ name=item_name, input="value", min=k_ext_controller_min_value, max=k_ext_controller_max_value })
		table.insert(global_auto_inputs,{ name=item_name,pattern=MakeRearControllerMIDIInputMask(i),value=MakeRearControllerMIDIInputValueFormula(),port=port_no })
	end

	------------------------------------------------- Peak meters ------------------------------------------------

	local function define_peak_meters()
		g_min_peak_index=table.getn(global_items)+1
		for i=1,g_num_channels do
			local item_name="Peak Meter "..i
			table.insert(global_items,{ name=item_name, input="noinput", output="value", min=k_min_peak_value, max=k_max_peak_value })
			g_new_peak_enabled_states[i]=false
			g_new_peak_level_states[i]=0
			g_sent_peak_enabled_states[i]=false
			g_sent_peak_level_states[i]=0
		end
		g_max_peak_index=table.getn(global_items)
	end

	------------------------------------------------- LCD ------------------------------------------------

	local function define_channel_texts()
		do
			g_min_row1_lcd_channel_index=table.getn(global_items)+1
			for i=1,g_num_channels do
				local item_name="LCD Row 1 Channel "..i
				table.insert(global_items,{ name=item_name, input="noinput", output="text" })
				g_lcd_channel_enabled_states[1][i]=false
				g_lcd_channel_states[1][i]=""
				g_new_lcd_output_states[1][i]=string.rep(" ",k_lcd_channel_width)
				g_sent_lcd_output_states[1][i]=string.rep("#",k_lcd_channel_width)
			end
			g_max_row1_lcd_channel_index=table.getn(global_items)
		end
		do
			g_min_row2_lcd_channel_index=table.getn(global_items)+1
			for i=1,g_num_channels do
				local item_name="LCD Row 2 Channel "..i
				table.insert(global_items,{ name=item_name, input="noinput", output="text"})
				g_lcd_channel_enabled_states[2][i]=false
				g_lcd_channel_states[2][i]=""
				g_new_lcd_output_states[2][i]=string.rep(" ",k_lcd_channel_width)
				g_sent_lcd_output_states[2][i]=string.rep("#",k_lcd_channel_width)
			end
			g_max_row2_lcd_channel_index=table.getn(global_items)
		end
	end

	local function define_row_texts()
		g_min_lcd_row_index=table.getn(global_items)+1
		for i=1,g_num_rows do
			local item_name="LCD Row "..i
			-- FL: LCD Rows are always on main control surface (== Control if combo).
			table.insert(global_items,{ name=item_name, input="noinput", output="text" })
			g_lcd_row_enabled_states[i]=false
			g_lcd_row_states[i]=""
		end
		g_max_lcd_row_index=table.getn(global_items)
	end

	------------------------------------------------- Pos Displays ------------------------------------------------

	local function define_time_displays()
		table.insert(global_items,{ name="Assignment Display", input="noinput", output="text" })
		g_assignment_display_index=table.getn(global_items)
		
		table.insert(global_items,{ name="Bars Display", input="noinput", output="text" })
		g_bars_display_index=table.getn(global_items)
		table.insert(global_items,{ name="Beats Display", input="noinput", output="text" })
		g_beats_display_index=table.getn(global_items)
		table.insert(global_items,{ name="Sub-division Display", input="noinput", output="text" })
		g_sub_division_display_index=table.getn(global_items)
		table.insert(global_items,{ name="Ticks Display", input="noinput", output="text" })
		g_ticks_display_index=table.getn(global_items)

		for display_pos=1,12 do
			g_new_display_output_state[display_pos]=string.byte(" ")
			g_sent_display_output_state[display_pos]=string.byte("#")
		end
	end

	------------------------------------------------------------

	assert(manufacturer=="Icon")
	assert(model=="QConProG2")

	if model=="QConProG2" then
		g_selected_model=k_control_model
		g_num_channels=k_unit_channel_count
		g_num_rows=2
		define_faders()
		define_master_fader()
		define_rotaries()
		define_rotary_buttons()
		define_record_buttons()
		define_solo_buttons()
		define_mute_buttons()
		define_select_buttons()
		define_buttons()
		define_leds()
		define_jog_wheel()
		define_rear_switches()
		define_rear_controller()
		define_peak_meters()
		define_channel_texts()
		define_row_texts()
		define_time_displays()
	end

	for feedback_index=1,g_num_channels do
		g_last_channel_input_time[feedback_index]=0
		g_last_channel_input_item[feedback_index]=-1
	end

	remote.define_items(global_items)
	remote.define_auto_inputs(global_auto_inputs)
	remote.define_auto_outputs(global_auto_outputs)
end



-- FL: To test MIDI input speed.
--[[
function remote_process_midi(event)
	remote.match_midi("bz<?xxx>?0y",event)
	remote.match_midi("bz<?xxx>?1y",event)
	remote.match_midi("bz<?xxx>?2y",event)
	remote.match_midi("bz<?xxx>?3y",event)
	remote.match_midi("bz<?xxx>?4y",event)
	remote.match_midi("bz<?xxx>?5y",event)
	remote.match_midi("bz<?xxx>?6y",event)
	remote.match_midi("bz<?xxx>?7y",event)
	remote.match_midi("bz<?xxx>?8y",event)
	ret=remote.match_midi("ez<?xxx>?yy",event)
	if ret~=nil then
		local msg={ time_stamp=event.time_stamp, item=ret.z+1, value=ret.y*8+ret.x }
		remote.handle_input(msg)
		return true
	end
	return false
end
]]



function remote_on_auto_input(item)
	if g_no_feedback_items[item]==true then
		return
	end
	local time=remote.get_time_ms()
	-- change: by commenting the input time for rotaries, the feedback display is
	-- the same now for rotaries:display in lcd row instead channel column
	--if item>=g_min_rotary_index and item<=g_max_rotary_index then
	--	local channel=item-g_min_rotary_index+1
	--	g_last_channel_input_time[channel]=time
	--	g_last_channel_input_item[channel]=item
	--elseif item>=g_min_rotary_button_index and item<=g_max_rotary_button_index then
	--	local channel=item-g_min_rotary_button_index+1
	--	g_last_channel_input_time[channel]=time
	--	g_last_channel_input_item[channel]=item
	--else
		g_last_input_time=time
		g_last_input_item=item
	--end
end

g_empty_strings = {
	" ",
	"  ",
	"   ",
	"    ",
	"     ",
	"      ",
	"       ",
}

g_leading_zeroes = {
	"0",
	"00",
	"000",
	"0000",
	"00000",
	"000000",
	"0000000",
}

g_disabled = {
	"9",
	"99",
	"999",
	"9999",
	"99999",
	"999999",
	"9999999",
}



local function set_text_exact(text,wanted_size)
--	assert(wanted_size<8)
	local size_diff=wanted_size-string.len(text)
	if size_diff<0 then
		text=string.sub(text,1,wanted_size)
	elseif size_diff>0 then
		text=text..g_empty_strings[size_diff]
	end
--	assert(string.len(text)==wanted_size)
	return text
end



local function set_text_exact_right(text,wanted_size)
--	assert(wanted_size<8)
	local size_diff=wanted_size-string.len(text)
	if size_diff<0 then
		text=string.sub(text,1-size_diff)
	elseif size_diff>0 then
		text=g_empty_strings[size_diff]..text
	end
--	assert(string.len(text)==wanted_size)
	return text
end



local function set_lcd_row_text(row,text)
	local wrong_size=k_lcd_row_width-string.len(text)
	if wrong_size>0 then
		text=text..string.rep(" ",wrong_size)  --linksbuendig
	--	text=string.rep(" ",wrong_size)..text  --rechtsbuendig
	end
	-- FL: "LCD Row x" items are always on port 1, ie the Control's Display if combo.
	local start_channel,stop_channel=get_channels_for_port(1)
	for channel=start_channel,start_channel+7 do
		local channel_index=get_channel_index_for_channel(channel)
		local start=1+(channel_index-1)*k_lcd_channel_width
		local stop=start+6
		g_new_lcd_output_states[row][channel]=string.sub(text,start,stop)
	end
end



local function set_lcd_channel_text(row,channel,text)
--	local fill_length=k_lcd_channel_width-string.len(text)
--	if fill_length>0 then
--		text=text..string.rep(" ",fill_length)
--	end
--	g_new_lcd_output_states[row][channel]=string.sub(text,1,k_lcd_channel_width)
	g_new_lcd_output_states[row][channel]=set_text_exact(text,k_lcd_channel_width)
end



local function set_display_value(start,size,text,enabled)
	if not enabled then
		--text=g_empty_strings[size]
		text=g_disabled[size]
	else
		-- FL: Fill display size, right justified
		text=set_text_exact_right(text,size)
	end
	for i=1,size do
		local char=string.byte(text,i)
		g_new_display_output_state[start+i-1]=char
	end
end



function remote_set_state(changed_items)
	-- FL: Collect all changed states
	for kk,item_index in ipairs(changed_items) do
		if item_index>=g_min_peak_index and item_index<=g_max_peak_index then
			local peak_index=item_index-g_min_peak_index+1
			g_new_peak_enabled_states[peak_index]=remote.is_item_enabled(item_index)
			g_new_peak_level_states[peak_index]=remote.get_item_value(item_index)
		elseif item_index>=g_min_row1_lcd_channel_index and item_index<=g_max_row1_lcd_channel_index then
			local lcd_index=item_index-g_min_row1_lcd_channel_index+1
			g_lcd_channel_enabled_states[1][lcd_index]=remote.is_item_enabled(item_index)
			g_lcd_channel_states[1][lcd_index]=remote.get_item_text_value(item_index)
		elseif item_index>=g_min_row2_lcd_channel_index and item_index<=g_max_row2_lcd_channel_index then
			local lcd_index=item_index-g_min_row2_lcd_channel_index+1
			g_lcd_channel_enabled_states[2][lcd_index]=remote.is_item_enabled(item_index)
			g_lcd_channel_states[2][lcd_index]=remote.get_item_text_value(item_index)
		elseif item_index>=g_min_lcd_row_index and item_index<=g_max_lcd_row_index then
			local row=item_index-g_min_lcd_row_index+1
			g_lcd_row_enabled_states[row]=remote.is_item_enabled(item_index)
			g_lcd_row_states[row]=remote.get_item_text_value(item_index)
		end

		if item_index==g_assignment_display_index then
			set_display_value(1,2,remote.get_item_text_value(item_index),remote.is_item_enabled(item_index))
		elseif item_index==g_bars_display_index then
			set_display_value(3,3,remote.get_item_text_value(item_index),remote.is_item_enabled(item_index))
		elseif item_index==g_beats_display_index then
			set_display_value(6,2,remote.get_item_text_value(item_index),remote.is_item_enabled(item_index))
		elseif item_index==g_sub_division_display_index then
			set_display_value(8,2,remote.get_item_text_value(item_index),remote.is_item_enabled(item_index))
		elseif item_index==g_ticks_display_index then
			set_display_value(10,3,remote.get_item_text_value(item_index),remote.is_item_enabled(item_index))
		elseif item_index==g_smpte_button_index then
			-- FL: This button is hardwired to SMPTE and Beats LEDs
			if not remote.is_item_enabled(item_index) then
				g_new_smpte_led_state=0
				g_new_beats_led_state=0
			elseif remote.get_item_value(item_index)==0 then
				g_new_smpte_led_state=1
				g_new_beats_led_state=0
			else
				g_new_smpte_led_state=0
				g_new_beats_led_state=1
			end
		end		
	end

	local lcd_row_enabled={}
	for row=1,g_num_rows do
		lcd_row_enabled[row]=g_lcd_row_enabled_states[row]
	end

	-- FL: Set channel texts and disable row text
	for channel=1,g_num_channels do
		local port_no=get_port_for_channel(channel)
		for row=1,2 do
			if g_lcd_channel_enabled_states[row][channel]==true then
				if port_no==1 then
					-- FL: If on main display display, disable "LCD Row 1" or "LCD Row 2", channel text is "above" row text.
					lcd_row_enabled[row]=false
				end
				set_lcd_channel_text(row,channel,g_lcd_channel_states[row][channel])
			end
		end
	end
	-- FL: Or set row texts/clear unused channels
	for row=1,g_num_rows do
		if lcd_row_enabled[row]==true then
			set_lcd_row_text(row,g_lcd_row_states[row])
		end
		for channel=1,g_num_channels do
			local port_no=get_port_for_channel(channel)
			if g_lcd_channel_enabled_states[row][channel]==false then
				-- FL: If on Extender or if LCD row is disabled, clear unused channel
				if port_no==2 or lcd_row_enabled[row]==false then
					set_lcd_channel_text(row,channel,"")
				end
			end
		end
	end

	-- FL: Write global temporary parameter feedback on main display row 1.
	local feedback_row_1_enabled=false
	local now_ms = remote.get_time_ms()
	-- FL: Check if there has been any input in the last two second.
	-- Note: this is effectively the time in millis to show the feedback on the display
	if g_last_input_item~=-1 and (now_ms-g_last_input_time) < g_time_millis_show_feedback_msg then
		if remote.is_item_enabled(g_last_input_item) then
			--local feedback_text=remote.get_item_name_and_value(g_last_input_item)
			local feedback_text=remote.get_item_name(g_last_input_item).." "..remote.get_item_text_value(g_last_input_item)
			-- FL: No feedback if text is empty
			if string.len(feedback_text)>1 then
				set_lcd_row_text(2,feedback_text)
				feedback_row_1_enabled=true
			end
		end
	end

	-- FL: Write temporary channel parameter feedback.
	for feedback_index=1,g_num_channels do
		local channel_time=g_last_channel_input_time[feedback_index]
		local channel_item=g_last_channel_input_item[feedback_index]
		-- FL: Check if there has been any channel input in the last second.
		if channel_item~=-1 and (now_ms-channel_time) < g_time_millis_show_feedback_msg then
			if remote.is_item_enabled(channel_item) then
				local port_no=get_port_for_channel(feedback_index)
				-- FL: Feed back on row is always on port 1, so if port==2 channel feedback always shows.
				if port_no==2 or feedback_row_1_enabled==false then
					local feedback_text=remote.get_item_text_value(channel_item)
					if string.len(feedback_text)>0 then
						set_lcd_channel_text(1,feedback_index,remote.get_item_short_name(channel_item))
						set_lcd_channel_text(2,feedback_index,feedback_text)
					end
				end
			end
		end
	end
end



local function GetModelByte(model_type)
	local model_byte=20
	-- FL: hex 14 = mackie control
	return model_byte
end



function MakePeakMeterEnabledMIDIMessage(channel,enabled,port_no,model_type)
	assert(channel>=1)
	assert(channel<=g_num_channels)
	local model_byte=GetModelByte(model_type)
	local control_byte=0
	if enabled then
		control_byte=3
	end
--	local event=remote.make_midi("f0 00 00 66 xx 20 yy zz f7", { x=model_byte, y=channel-1, z=control_byte, port=port_no })
	local event={ 240, 0, 0, 102, model_byte, 32, channel-1, control_byte, 247 }
	if port_no~=-1 then
		event.port=port_no
	end
	return event
end



function MakePeakMeterLevelMIDIMessage(channel,level,port_no)
	assert(channel>=1)
	assert(channel<=g_num_channels)
	assert(level>=k_min_peak_value);
	assert(level<=k_max_peak_value);
--		local event=remote.make_midi("d0 <0xxx><yyyy>", { x=channel-1, y=level, port=port_no  })
	local event={ 208, (channel-1)*16+level }
	if port_no~=-1 then
		event.port=port_no
	end
	return event
end



local function MakeOneLCDMIDIMessage(row,startPos,text,port_no,model_type)
	local model_byte=GetModelByte(model_type)
	local start_byte=startPos-1
	if row==2 or row==4 or row==6 or row==8 then
		start_byte=start_byte+k_lcd_row_width
	end
	local lcd_byte=18
--	local event=remote.make_midi("f0 00 00 66 yy zz xx", { x=start_byte, y=model_byte, z=lcd_byte, port=port_no })
	local event={ 240, 0, 0, 102, model_byte, lcd_byte, start_byte }
	start=8
	stop=8+string.len(text)-1
	for i=start,stop do
		sourcePos=i-start+1
		event[i] = string.byte(text,sourcePos)
	end
	event[stop+1] = from_hex("f7")
	if port_no~=-1 then
		event.port=port_no
	end
	return event
end



function MakeAssignNPosDisplayMIDIMessage(pos,char,port_no)
	-- FL: 0x40 to 0x4b, right to left
	local index_byte=76-pos
	local char_byte=char
	if char_byte>=64 and char_byte<=95 then
		char_byte=char_byte-64
	elseif char_byte>=96 then
		-- FL: 0x1f=='_' is replacement char
		char_byte=31
	end
	if(pos == 5 or pos == 7 or pos == 9) then
		-- add a dot behind these positions by adding hex 40
		-- valid positions are 1 to 12 (1-2= assignment display, 3-12 = timecode display
		char_byte=char_byte+64
	end
--	local event=remote.make_midi("b0 xx yy", { x=index_byte, y=char_byte, port=port_no })
	local event={ 176, index_byte, char_byte }
	if port_no~=-1 then
		event.port=port_no
	end
	return event
end



function clear_peak_char(row,channel)
	-- FL: Change sent state to trigger resend of text.
	local old_text=g_sent_lcd_output_states[row][channel]
	local old_char=string.byte(old_text,k_lcd_channel_width)
	local new_char=old_char+1
	if new_char>127 then
		new_char=1
	end
	g_sent_lcd_output_states[row][channel]=string.sub(old_text,1,k_lcd_channel_width-1)..string.char(new_char)
end



local function make_split_events(value,enabled)
	local on_byte1=0
	local on_byte2=0
	local on_byte3=0
	if enabled and value==2 then
		on_byte1=127
	end
	if enabled and value==1 then
		on_byte2=127
	end
	if enabled and value==0 then
		on_byte3=127
	end

	local ret_events={
		{ 144, 0, on_byte1, port=1 },
		{ 144, 1, on_byte2, port=1 },
		{ 144, 2, on_byte3, port=1 },
	}
	return ret_events
end



function remote_deliver_midi(max_bytes,port)
	-- FL: Ignore max_bytes for now. Works fine even if we fill the buffer.
	assert(port>=1)
	assert(port<=2)

	local now_ms=remote.get_time_ms()
	local update_peak_values=false
	if now_ms-g_last_peak_update[port]>k_peak_meter_update_interval then
		g_last_peak_update[port]=now_ms
		update_peak_values=true
	end

	local start_channel,stop_channel=get_channels_for_port(port)
	local ret_events={}
	if update_peak_values then
		for peak_index=start_channel,stop_channel do
			local is_enabled=g_new_peak_enabled_states[peak_index]
			if g_sent_peak_enabled_states[peak_index]~=is_enabled then
				local port_no=get_port_for_channel(peak_index)
				assert(port_no==port)
				local channel_index=get_channel_index_for_channel(peak_index)
				local model_type=get_model_type_for_channel(peak_index)
				--[[
						FL: Changing tracks wont clear peak meter on C4.
						On MCU the meter is cleared, but not the signal LED.
						This code should work; it first sends peak level 0, then peak disable.
						Same with old binary codec. Bug in Mackie Firmware?
						FL: I never disable peak meters now. It seems to work. Only set their level to 0 when disabled.
					--local peak_enabled_event=MakePeakMeterEnabledMIDIMessage(channel_index,is_enabled,port,model_type)
				]]
				
				local peak_enabled_event=MakePeakMeterEnabledMIDIMessage(channel_index,true,port,model_type)
				table.insert(ret_events,peak_enabled_event)
				g_sent_peak_enabled_states[peak_index]=is_enabled
				if not is_enabled then
					--[[
						FL: If it becomes disabled we must clear chars under peak meters
							This works on Mackie Control, but not on C4.
						FL: Not needed now when peak level set to 0.
						clear_peak_char(1,peak_index)
						clear_peak_char(2,peak_index)
					]]
					-- FL: Clear signal, set level to 0
					local peak_level_event=MakePeakMeterLevelMIDIMessage(channel_index,0,port)
					table.insert(ret_events,peak_level_event)
					g_sent_peak_level_states[peak_index]=peak_level
				end
			end
			if is_enabled then
				local port_no=get_port_for_channel(peak_index)
				assert(port_no==port)
				local channel_index=get_channel_index_for_channel(peak_index)
				peak_level=g_new_peak_level_states[peak_index]
				-- FL: No need to update peaks if level and previous level == 0
				if peak_level~=0 or g_sent_peak_level_states[peak_index]~=0 then
					local peak_level_event=MakePeakMeterLevelMIDIMessage(channel_index,peak_level,port)
					table.insert(ret_events,peak_level_event)
					g_sent_peak_level_states[peak_index]=peak_level
				end
			end
		end
	end

	for row=1,2 do
		for lcd_index=start_channel,stop_channel do
			local new_text=g_new_lcd_output_states[row][lcd_index]
			if g_sent_lcd_output_states[row][lcd_index]~=new_text then
				local port_no=get_port_for_channel(lcd_index)
				assert(port_no==port)
				local channel_index=get_channel_index_for_channel(lcd_index)
				local model_type=get_model_type_for_channel(lcd_index)
				local pos=1+(channel_index-1)*k_lcd_channel_width
				local lcd_event=MakeOneLCDMIDIMessage(row,pos,new_text,port_no,model_type)
				table.insert(ret_events,lcd_event)
				g_sent_lcd_output_states[row][lcd_index]=new_text
			end
		end
	end

	if port==1 then
		for display_pos=1,12 do
			local new_char=g_new_display_output_state[display_pos]
			if g_sent_display_output_state[display_pos]~=new_char then
				local port_no=1
				local display_event=MakeAssignNPosDisplayMIDIMessage(display_pos,new_char)
				table.insert(ret_events,display_event)
				g_sent_display_output_state[display_pos]=new_char
			end
		end

		if g_sent_smpte_led_state~=g_new_smpte_led_state then
			-- "90 71 xx"
			local led_event={ 144, 113, g_new_smpte_led_state*127 }
			led_event.port=1
			table.insert(ret_events,led_event)
			g_sent_smpte_led_state=g_new_smpte_led_state
		end
		if g_sent_beats_led_state~=g_new_beats_led_state then
			-- "90 72 xx"
			local led_event={ 144, 114, g_new_beats_led_state*127 }
			led_event.port=1
			table.insert(ret_events,led_event)
			g_sent_beats_led_state=g_new_beats_led_state
		end
	end

	return ret_events
end



function remote_prepare_for_use()
	local function MakeTransportClickMessage(click_on,port_no)
		local click_byte=0
		if click_on then
			click_byte=1
		end
		event = remote.make_midi("f0 00 00 66 14 0a xx f7", { x=click_byte, port=port_no} );
		return event
	end
	local function MakePeakMeterModeMessage(model_type,set_vertical,port_no)
		local set_vertical_byte=0
		if set_vertical then
			set_vertical_byte=1
		end
		local model_byte=GetModelByte(model_type)
		event = remote.make_midi("f0 00 00 66 yy 21 xx f7", { x=set_vertical_byte, y=model_byte, port=port_no} );
		return event
	end

	local retEvents={
		MakeTransportClickMessage(false,1),
		MakeOneLCDMIDIMessage(1,1,"Welcome to Propellerhead Reason!         QConProG2 Codec",1,k_control_model),
		MakeOneLCDMIDIMessage(2,1,"                                           Version 1.0.0",1,k_control_model),
		-- If the peak meters are set before the text messages, they will not be displayed properly.
		-- Does change of peak meter mode slow down the Mackie so it loses some midi? Ask Mackie boys.
		MakePeakMeterModeMessage(k_control_model,true,1),
	}
	return retEvents
end



function remote_release_from_use()
	local retEvents={
		MakeOneLCDMIDIMessage(1,1,"Propellerhead Reason Disconnected                       ",1,k_control_model),
		MakeOneLCDMIDIMessage(2,1,"Elvis has left the building!                            ",1,k_control_model),
	}
	return retEvents
end


-- Note: probing seems unsupported by the qcon pro g2, so this is useless
function remote_probe(manufacturer,model,prober)
	assert(model=="QConProG2")
	local controlRequest="f0 00 00 66 14 00 f7"
	local controlResponse="f0 00 00 66 14 01 ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? f7"
	if model=="QConProG2" then
		return {
			request=controlRequest,
			response=controlResponse
		}
	end
	return nil
end
