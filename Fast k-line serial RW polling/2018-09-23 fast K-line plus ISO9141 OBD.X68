*-----------------------------------------------------------
* Title      : ISO-9141 + fast serial integration
* Written by : Lotus/mod by Obeisance
* Date       : 2018-09-23
* Description: This code replicates the Lotus code at 0x22ada
*              and adds in an additional mode initialization
*              that allows for fast serial data responses with
*              formatting different from OBD response routines
*-----------------------------------------------------------
    ORG    $31030
Serial_receive_buffer EQU $81168
Serial_send_buffer EQU $811e8
OBD_init_level EQU $807bc
Serial_received_byte_count EQU $807c8
Num_serial_bytes_left_to_read EQU $807ca
Serial_send_buffer_byte_count EQU $807cc
Serial_send_buffer_index EQU $807ce
Checksum_calc_buffer EQU $807d0
OBD_timeout_counter_5ms_multiple EQU $807d2
OBD_continue_response_counter EQU $807d8
DTC_sent_via_OBD_count EQU $80838
OBD_mode_0x9_msgs_sent EQU $80d4a
OBD_mode_0x9_resp_cont EQU $2e506
OBD_Mode_0x1_resp EQU $2351e
OBD_Mode_0x2_resp EQU $23f7a
OBD_Mode_0x3_resp EQU $25746
OBD_Mode_0x4_resp EQU $258ea
OBD_Mode_0x5_resp EQU $2621a
OBD_Mode_0x6_resp EQU $28016
OBD_Mode_0x7_resp EQU $28646
OBD_Mode_0x8_resp EQU $2e7c4
OBD_Mode_0x9_resp EQU $2dee0
OBD_Mode_not_supported EQU $27f90
OBD_Mode_0x22_resp EQU $24400
OBD_Mode_0x2F_resp EQU $269c2
OBD_Mode_0x3B_resp EQU $2eb30
SCCR0 EQU $fffc08
SCCR1 EQU $fffc0a
SCSR EQU $fffc0c
SCDR EQU $fffc0e
 
START:                  ; first instruction of program

* Put program code here

; Copy much of the OBD serial response subroutine at 0x022ada
; I made changes so that the code is more compact
    LINK A6,#-26
    MOVEM.L A5/A4/A3/A2/D2,($4,A7)
    LEA Serial_receive_buffer,A2    ; OBD incoming serial packet buffer
    LEA Checksum_calc_buffer,A3 ; Checksum calculation buffer
    LEA Serial_received_byte_count,A4   ; Number of serial bytes received
    LEA OBD_timeout_counter_5ms_multiple,A5   ; OBD timeout counter - 5 millisecond multiple
    JSR ($25880).L  ; update byte at ($80834).L depending on DTC count
    MOVE.B (OBD_init_level).L,D0    ; Load the OBD init level counter
    CMPI.B #9,D0
    BHI end_OBD_routine ; end routine if the init level is too high
    EXT.W D0
    ADD.W D0,D0
    MOVE.W (*+$2+$6,PC,D0.W),D0
jump_start
    JMP (*+$2+$2,PC,D0.W)   ; jump to end routine if OBD init level is not 9 
    DC.W end_OBD_routine-jump_start-$4
    DC.W end_OBD_routine-jump_start-$4
    DC.W end_OBD_routine-jump_start-$4
    DC.W end_OBD_routine-jump_start-$4
    DC.W end_OBD_routine-jump_start-$4
    DC.W end_OBD_routine-jump_start-$4
    DC.W end_OBD_routine-jump_start-$4
    DC.W end_OBD_routine-jump_start-$4
    DC.W end_OBD_routine-jump_start-$4
    DC.W check_OBD_mode-jump_start-$4  ;if OBD init mode is 9, then we continue in the routine
    BRA.W end_OBD_routine
check_OBD_mode
    CMPI.B #5,(A4)  ; we always have at least 5 bytes in an OBD query
    BCS.W check_error_states    ; branch if we don't have enough bytes
    CMPI.B #104,(A2)     ; check for correct packet structure [104 106 241 MODE PID checksum]
    BNE.W incorrect_structure_for_ISO_9141
    CMPI.B #106,($1,A2)
    BNE.W incorrect_structure_for_ISO_9141
    CMPI.B #241,($2,A2)
    BNE.W incorrect_structure_for_ISO_9141
    ;****Mode 0x1****
    CMPI.B #1,($3,A2)
    BNE.B Mode_0x2
    CMPI.B #6,(A4)
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L   ; this works without passing in variables because the number of bytes to read and buffer location are fixed in memory
    CMP.B #1,D0 ; If D0 = 0, we have a bad checksum
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,(A7)
    JSR (OBD_Mode_0x1_resp).L
    BRA.W end_OBD_Mode_response
Mode_0x2
    CMPI.B #2,($3,A2)
    BNE.B Mode_0x3
    CMPI.B #7,(A4)
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.B ($5,A2),D0
    MOVE.L D0,(A7)
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,-(A7)
    JSR (OBD_Mode_0x2_resp).L
    ADDQ.L #4,A7    ; Adjust stack pointer back to original position
    BRA.W end_OBD_Mode_response
Mode_0x3
    CMPI.B #3,($3,A2)
    BNE.B Mode_0x4
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    JSR (OBD_Mode_0x3_resp).L
    MOVE.B #9,(OBD_continue_response_counter).L ; Allow this mode to have multiple response packets
    BRA.W end_OBD_Mode_response
Mode_0x4
    CMPI.B #4,($3,A2)
    BNE.B Mode_0x5
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    JSR (OBD_Mode_0x4_resp).L
    BRA.W end_OBD_Mode_response
Mode_0x5
    CMPI.B #5,($3,A2)
    BNE.B Mode_0x6
    CMPI.B #7,(A4)
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.B ($5,A2),D0
    MOVE.L D0,(A7)
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,-(A7)
    JSR (OBD_Mode_0x5_resp).L
    ADDQ.L #4,A7
    BRA.W end_OBD_Mode_response
Mode_0x6
    CMPI.B #6,($3,A2)
    BNE.B Mode_0x7
    CMPI.B #6,(A4)
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,(A7)
    JSR (OBD_Mode_0x6_resp).L
    BRA.W end_OBD_Mode_response
Mode_0x7
    CMPI.B #7,($3,A2)
    BNE.B Mode_0x8
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,(A7)
    JSR (OBD_Mode_0x7_resp).L
    BRA.W end_OBD_Mode_response
Mode_0x8
    CMPI.B #8,($3,A2)
    BNE.B Mode_0x9
    CMPI.B #11,(A4) ; must have 11 bytes in a mode 0x8 packet!
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,(A7)
    JSR (OBD_Mode_0x8_resp).L
    BRA.W end_OBD_Mode_response
Mode_0x9
    CMPI.B #9,($3,A2)
    BNE.B Mode_0xA
    CMPI.B #6,(A4)
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,(A7)
    JSR (OBD_Mode_0x9_resp).L
    MOVE.B #9,(OBD_continue_response_counter).L
    BRA.W end_OBD_Mode_response
Mode_0xA
    CMPI.B #10,($3,A2)
    BCS.B Mode_0x22
    CMPI.B #33,($3,A2)
    BHI.B Mode_0x22
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    JSR (OBD_Mode_not_supported).L
    BRA.W end_OBD_Mode_response
Mode_0x22
    CMPI.B #34,($3,A2)
    BNE.B Mode_0x23
    CMPI.B #7,(A4)
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0 ; Collect the two PID bytes from the packet, put them on D0
    MOVE.B ($4,A2),D0
    SWAP D0
    CLR.W D0
    SWAP D0
    ASL.L #8,D0
    MOVEQ #0,D1
    MOVE.B ($5,A2),D1
    SWAP D1
    CLR.W D1
    SWAP D1
    ADD.L D1,D0
    MOVE.L D0,(A7)
    JSR (OBD_Mode_0x22_resp).L
    BRA.W end_OBD_Mode_response
Mode_0x23
    CMPI.B #35,($3,A2)
    BCS.B Mode_0x2F
    CMPI.B #46,($3,A2)
    BHI.B Mode_0x2F
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    JSR (OBD_Mode_not_supported).L
    BRA.W end_OBD_Mode_response
Mode_0x2F
    CMPI.B #47,($3,A2)
    BNE.W Mode_0x3B
    CMPI.B #7,(A4)
    BCS.W end_OBD_routine
    CMPI.B #1,($4,A2)   ; check for a valid PID structure
    BNE.B long_Mode_0x2F_PID
    MOVE.B ($5,A2),D0
    ANDI.B #31,D0
    BNE.B long_Mode_0x2F_PID
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.L D0,(A7)
    MOVEQ #0,D0 ; Collect the two PID bytes from the packet, put them on D0
    MOVE.B ($4,A2),D0
    SWAP D0
    CLR.W D0
    SWAP D0
    ASL.L #8,D0
    MOVEQ #0,D1
    MOVE.B ($5,A2),D1
    SWAP D1
    CLR.W D1
    SWAP D1
    ADD.L D1,D0
    MOVE.L D0,-(A7)
    JSR (OBD_Mode_0x2F_resp).L
    ADDQ.L #4,A7
    BRA.W end_OBD_Mode_response
long_Mode_0x2F_PID
    CMPI.B #8,(A4)
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0
    MOVE.B ($6,A2),D0
    MOVE.L D0,(A7)
    MOVEQ #0,D0 ; Collect the two PID bytes from the packet, put them on D0
    MOVE.B ($4,A2),D0
    SWAP D0
    CLR.W D0
    SWAP D0
    ASL.L #8,D0
    MOVEQ #0,D1
    MOVE.B ($5,A2),D1
    SWAP D1
    CLR.W D1
    SWAP D1
    ADD.L D1,D0
    MOVE.L D0,-(A7)
    JSR (OBD_Mode_0x2F_resp).L
    ADDQ.L #4,A7
    BRA.W end_OBD_Mode_response
Mode_0x3B
    CMPI.B #59,($3,A2)
    BNE.B Higher_Modes
    CMPI.B #11,(A4)
    BCS.W end_OBD_routine
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    MOVEQ #0,D0 ; now move 6 bytes onto the stack
    MOVE.B ($9,A2),D0
    MOVE.L D0,(A7)
    MOVEQ #0,D0
    MOVE.B ($8,A2),D0
    MOVE.L D0,-(A7)
    MOVEQ #0,D0
    MOVE.B ($7,A2),D0
    MOVE.L D0,-(A7)
    MOVEQ #0,D0
    MOVE.B ($6,A2),D0
    MOVE.L D0,-(A7)
    MOVEQ #0,D0
    MOVE.B ($5,A2),D0
    MOVE.L D0,-(A7)
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,-(A7)
    JSR (OBD_Mode_0x3B_resp).L
    LEA ($14,A7),A7
    BRA.W end_OBD_Mode_response
Higher_Modes
    CMPI.B #60,($3,A2)  ; Use mode 0x3C as a baud rate toggle, no PID needed
    BNE.B mode_not_present
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    JSR (OBD_Mode_0x3C_resp).L
    BRA.W end_OBD_Mode_response
mode_not_present
    JSR (OBD_Mode_not_supported).L
end_OBD_Mode_response
    CLR.B (A4)
    CLR.B (Num_serial_bytes_left_to_read).L
    MOVE.W #1000,(A5)
    BRA.W end_OBD_routine
incorrect_structure_for_ISO_9141
;************ This is the place to patch in custom code! ***************
    CMPI.B #85,(A2) ; look for the special packet header byte
    BNE.B no_correct_packet_structure
    CMPI.B #128,($1,A2) ; Make sure that the incoming packet is not too big
    BHI.B no_correct_packet_structure
    MOVEQ #0,D0
    MOVE.B ($1,A2),D0
    CMP.B (A4),D0
    BNE.W end_OBD_routine   ; do nothing more until we've read in the entire packet
    CMPI.B #17,($2,A2)
    BEQ.B process_special_cmd
    CMPI.B #136,($2,A2)
    BEQ.B process_special_cmd
    BRA.B no_correct_packet_structure
process_special_cmd
    JSR (Calc_checksum).L
    CMP.B #1,D0
    BNE.W end_OBD_Mode_response
    JSR (special_serial_resp).L
    BRA.W end_OBD_Mode_response
;************** End of new K-line response code ************************
no_correct_packet_structure
    CLR.B (A4)   ; reset the index to read received data in the buffer
    CLR.B (Num_serial_bytes_left_to_read).L
    MOVE.W #1000,(A5)   ; reset the 5 sec timeout            
check_error_states
    TST.B (Serial_send_buffer_byte_count).L
    BNE.B end_OBD_routine
    TST.B (Serial_send_buffer_index).L
    BNE.B end_OBD_routine
    TST.B (OBD_continue_response_counter).L
    BNE.B end_OBD_routine
    TST.B (DTC_sent_via_OBD_count).L
    BEQ.B check_mode_0x9_response
    JSR (OBD_mode_0x3_resp).L
    MOVE.B #9,(OBD_continue_response_counter).L
    BRA.B end_OBD_routine
check_mode_0x9_response
    TST.B (OBD_mode_0x9_msgs_sent).L
    BEQ.B end_OBD_routine
    MOVEQ #0,D0
    MOVE.B ($4,A2),D0
    MOVE.L D0,(A7)
    JSR (OBD_mode_0x9_resp_cont).L
    MOVE.B #9,(OBD_continue_response_counter).L
end_OBD_routine
    MOVEM.L ($4,A7),A5/A4/A3/A2/D2
    UNLK A6
    RTS


Calc_checksum
    CLR.B (A3)
    MOVEQ #0,D2
    MOVE.B (A4),D2  ; number of bytes in the receveived data buffer
    SUBI.B #1,D2  ; index of final checksum byte
    BRA.B checksum_loop_cond_check
checksum_loop_start
    SUBI.B #1,D2
    MOVE.B D2,D0
    MOVE.B ($0,A2,D0.L),D1  ; Load a byte from the packet
    ADD.B D1,(A3)   ; Add this to the checksum
checksum_loop_cond_check
    CMPI.B #0,D2
    BNE.B checksum_loop_start
    MOVEQ #0,D0
    MOVE.B (A4),D0
    SUBI.B #1,D0
    MOVE.B ($0,A2,D0.L),D1 
    CMP.B (A3),D1
    BNE.B bad_checksum
    MOVEQ #1,D0
    BRA.B end_checksum
bad_checksum
    MOVEQ #0,D0
end_checksum
    RTS
    
OBD_Mode_0x3C_resp
    MOVE.W (SCCR0).L,D0
    CMPI.W #60,D0
    BNE switch_to_10400
    MOVE.B #72,($811e8).L   ; Assemble a fixed packet
    MOVE.B #107,($811e9).L
    MOVE.B #16,($811ea).L
    MOVE.B #124,($811eb).L
    MOVE.B #$31,($811ec).L
    MOVE.B #$32,($811ed).L
    MOVE.B #$35,($811ee).L
    MOVE.B #$30,($811ef).L
    MOVE.B #$33,($811f0).L
    MOVE.B #$31,($811f1).L
    MOVE.B #107,($811f2).L
    MOVE.B #10,(Serial_send_buffer_byte_count).L
    CLR.B (Serial_send_buffer_index).L
    MOVEQ #0,D0
    MOVE.B (Serial_send_buffer).L,D0
    MOVE.W D0,(SCDR).L
check_serial_status
    MOVEQ #0,D0
    MOVE.B (Serial_send_buffer_byte_count).L,D0
    TST.B D0
    BNE.B check_serial_status   ; loop until we're done sending data
    MOVE.W #0,(SCCR1).L    ; Disable the serial comms
    MOVE.W #5,(SCCR0).L    ; Change the baud rate to 1: 625156.3; 2: 312578.1; 3: 208385.4; 4: 156289.1; 5: 125031.3; 6: 104192.7
    MOVE.W #44,(SCCR1).L    ; Enable the serial comms
    BRA end_chg_baud
switch_to_10400
    MOVE.B #72,($811e8).L   ; Assemble a fixed packet
    MOVE.B #107,($811e9).L
    MOVE.B #16,($811ea).L
    MOVE.B #124,($811eb).L
    MOVE.B #$31,($811ec).L
    MOVE.B #$30,($811ed).L
    MOVE.B #$34,($811ee).L
    MOVE.B #$31,($811ef).L
    MOVE.B #$39,($811f0).L
    MOVE.B #62,($811f1).L
    MOVE.B #9,(Serial_send_buffer_byte_count).L
    CLR.B (Serial_send_buffer_index).L
    MOVEQ #0,D0
    MOVE.B (Serial_send_buffer).L,D0
    MOVE.W D0,(SCDR).L
check_serial_status_2
    MOVEQ #0,D0
    MOVE.B (Serial_send_buffer_byte_count).L,D0
    TST.B D0
    BNE.B check_serial_status_2   ; loop until we're done sending data
    MOVE.W #0,(SCCR1).L    ; Disable the serial comms
    MOVE.W #60,(SCCR0).L    ; Change the baud rate to 10419.27
    MOVE.W #44,(SCCR1).L    ; Enable the serial comms
end_chg_baud
    RTS

special_serial_resp ; This function can only work with the above serial routine due to reliance on address register population
    LINK A6,#-28
    MOVEM.L A1/A0/D4/D3/D2/D1,($4,A7)
    LEA Serial_send_buffer,A0
    CLR.B (A3)   ; let's count up the checksum on this RAM address
    MOVEQ #0,D1 ; An index into the send packet
    MOVEQ #170,D0 ; Start building the send packet
    MOVE.B D0,($0,A0,D1.L)
    ADD.B D0,(A3)
    ADDQ.B #2,D1    ; For now, skip over the 'number of bytes' byte
    CMPI.B #17,($2,A2)
    BNE.W special_write
    ; Read data from ROM
    MOVEQ #17,D0
    MOVE.B D0,($0,A0,D1.L)
    ADD.B D0,(A3)
    ADDQ.B #1,D1
    MOVEQ #3,D2 ; An index into the read packet
    BRA.B Read_data_cond_check
    ; Now process the read data commands in the message
Read_data_loop_start
    MOVE.L ($1,A2,D2.L),D0
    ASR.L #8,D0
    ANDI.L #16777215,D0 ; mask the address to three bytes
    MOVEA.L D0,A1   ; Now we have the address to read from
    MOVE.B ($0,A2,D2.L),D0  ; Now we also have the number of bytes to read
    BRA copy_data_cond_check
copy_data_loop_start
    MOVE.B (A1)+,D3 ; read the requested data
    MOVE.B D3,($0,A0,D1.L)  ; put the data in the serial send packet
    ADD.B D3,(A3)   ; update the checksum
    ADDQ.B #1,D1    ; increment our send packet index
    SUBQ.B #1,D0    ; decrement our 'bytes left to read' counter
copy_data_cond_check
    CMPI.B #127,D1  ; Make sure we are not trying to read too many bytes
    BGE.B send_packet
    CMPI.B #0,D0
    BNE.B copy_data_loop_start
    ADDI.B #4,D2    ; Increment our read index to the next command
Read_data_cond_check
    MOVE.B (A4),D3
    SUBQ.B #1,D3
    CMP.B D3,D2   ; compare our read index to the number of bytes read in the buffer
    BLO Read_data_loop_start
    BRA.B send_packet

special_write
    MOVEQ #136,D0
    MOVE.B D0,($0,A0,D1.L)
    ADD.B D0,(A3)
    ADDQ.B #1,D1
    MOVEQ #3,D2 ; An index into the read packet
    BRA.B Write_data_cond_check
    ; Now process the write data commands in the message
Write_data_loop_start
    MOVE.L ($1,A2,D2.L),D0
    ASR.L #8,D0
    ANDI.L #16777215,D0 ; mask the address to three bytes
    MOVEA.L D0,A1   ; Now we have the address to read from
    MOVE.B ($0,A2,D2.L),D0  ; Now we also have the number of bytes to read
    ADDQ.B #4,D2
    MOVE.B (A4),D3 
    SUB.B D2,D3    ; check to see that a sufficient number of bytes is in the packet
    SUBQ.B #1,D3    ; remove the checksum too
    CMP.B D3,D0
    BHI.B send_packet   ; send the response packet if too few bytes exist in the command packet
    BRA write_block_cond_check
write_block_loop_start
    MOVE.B ($0,A2,D2.L),D3
    MOVE.B D3,(A1)+
    SUBQ.B #1,D0
    ADDQ.B #1,D2
write_block_cond_check
    CMPI.B #0,D0
    BNE write_block_loop_start    
Write_data_cond_check
    MOVE.B (A4),D3
    SUBQ.B #1,D3
    CMP.B D3,D2
    BLO Write_data_loop_start    
send_packet
    MOVE.B D1,D3
    ADDQ.B #1,D3
    MOVE.B D3,($1,A0)   ; update the 'number of bytes in packet' byte in the packet
    ADD.B D3,(A3)   ; perform the final checksum update
    MOVE.B (A3),D3  ; then put the checksum into the packet
    MOVE.B D3,($0,A0,D1.L)
    MOVE.B D1,(Serial_send_buffer_byte_count).L ; Then set the counters to send the packet
    CLR.B (Serial_send_buffer_index).L
    MOVEQ #0,D0
    MOVE.B (Serial_send_buffer).L,D0
    MOVE.W D0,(SCDR).L  ; Then put the first byte from the packet into the buffer in order to send it     
end_special_ser_routine
    MOVEM.L ($4,A7),A1/A0/D4/D3/D2/D1
    UNLK A6
    RTS
    
    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source












*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
