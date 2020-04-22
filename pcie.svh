//******************************************************************************
//*
//*      Project:     Any
//*
//*      Description: PCIe stuff definitions file
//*
//*      Version 1.0
//*
//*      Copyright (c) 2018, Harry E. Zhurov
//*
//------------------------------------------------------------------------------

`ifndef PCIE_DEFS_H
`define PCIE_DEFS_H

package pcie_defs;

localparam WORD_W  = 16;
localparam DWORD_W = 32;
    
typedef logic[ WORD_W-1:0] word_t; 
typedef logic[DWORD_W-1:0] dword_t; 
    
//------------------------------------------------------------------------------
typedef enum logic [2:0]    // Device Capabilities register (0x64)
{
    MPS_128  = 3'b000,
    MPS_256  = 3'b001,
    MPS_512  = 3'b010,
    MPS_1024 = 3'b011,
    MPS_2048 = 3'b100,
    MPS_4096 = 3'b101
}
mps_t;

typedef enum logic [3:0]    // Link Status register (0x74) [3:0]
{
    LINK_SPEED_2_5 = 4'b0001,
    LINK_SPEED_5_0 = 4'b0010
}
link_speed_t;

typedef enum logic [5:0]    // Link Status register (0x74) [9:4]
{
    LINK_WIDTH_x1  = 6'b00_0001,
    LINK_WIDTH_x2  = 6'b00_0010,
    LINK_WIDTH_x4  = 6'b00_0100,
    LINK_WIDTH_x8  = 6'b00_1000,
    LINK_WIDTH_x12 = 6'b00_1100,
    LINK_WIDTH_x16 = 6'b01_0000,
    LINK_WIDTH_x32 = 6'b10_0000
}
link_width_t;

//------------------------------------------------------------------------------
//
//    Types
//
//---------------------------------------------------------------------------
//  TLP                                  |  FMT[2:0]          |  TYPE [4:0]
//  -------------------------------------------------------------------------
//  Memory Read Request (MRd)            | 000 = 3DW, no data | 0 0000
//                                       | 001 = 4DW, no data |
//  -------------------------------------------------------------------------
//  Memory Read Lock Request (MRdLk)     | 000 = 3DW, no data | 0 0001
//                                       | 001 = 4DW, no data |
//  -------------------------------------------------------------------------
//  Memory Write Request (MWr)           | 010 = 3DW, w/ data | 0 0000
//                                       | 011 = 4DW, w/ data |
//  -------------------------------------------------------------------------
//  IO Read Request (IORd)               | 000 = 3DW, no data | 0 0010
//  -------------------------------------------------------------------------
//  IO Write Request (IOWr)              | 010 = 3DW, w/ data | 0 0010
//  -------------------------------------------------------------------------
//  Config Type 0 Read Request (CfgRd0)  | 000 = 3DW, no data | 0 0100
//  -------------------------------------------------------------------------
//  Config Type 0 Write Request (CfgWr0) | 010 = 3DW, w/ data | 0 0100
//  -------------------------------------------------------------------------
//  Config Type 1 Read Request (CfgRd1)  | 000 = 3DW, no data | 0 0101
//  -------------------------------------------------------------------------
//  Config Type 1 Write Request (CfgWr1) | 010 = 3DW, w/ data | 0 0101
//  -------------------------------------------------------------------------
//  Message Request (Msg)                | 001 = 4DW, no data | 1 0 rrr* (see routing field) - |   rrr
//  -------------------------------------------------------------------------                  |
//  Message Request W/Data (MsgD)        | 011 = 4DW, w/ data | 1 0rrr* (see routing field ) - |   000b      = Implicit - Route to the Root Complex
//  -------------------------------------------------------------------------                  |   001b      = Route by Address (bytes 8-15 of header contain address)
//  Completion (Cpl)                     | 000 = 3DW, no data | 0 1010                         |   010b      = Route by ID (bytes 8-9 of header contain ID)
//  -------------------------------------------------------------------------                  |   011b      = Implicit - Broadcast downstream
//  Completion W/Data (CplD)             | 010 = 3DW, w/ data | 0 1010                         |   100b      = Implicit - Local: terminate at receiver
//  -------------------------------------------------------------------------                  |   101b      = Implicit - Gather & route to the Root Complex
//  Completion‐Locked (CplLk)            | 000 = 3DW, no data | 0 1011                         |   110b-111b = Reserved: terminate at receiver
//  -------------------------------------------------------------------------
//  Completion W/Data (CplDLk)           | 010 = 3DW, w/ data | 0 1011
//  -------------------------------------------------------------------------
//  Fetch and Add AtomicOp Request       | 010 = 3DW, w/ data | 0 1100
//                                       | 011 = 4DW, w/ data |
//  -------------------------------------------------------------------------
//  Unconditional Swap AtomicOp          | 010 = 3DW, w/ data | 0 1101
//  Request                              | 011 = 4DW, w/ data |
//  -------------------------------------------------------------------------
//  Compare and Swap AtomicOp            | 010 = 3DW, w/ data | 0 1110
//  Request                              | 011 = 4DW, w/ data |
//  -------------------------------------------------------------------------
//  Local TLP Prefix                     | 100 = TLP Prefix   | 0L3L2L1L0
//  -------------------------------------------------------------------------
//  End-to-End TLP Prefix                | 100 = TLP Prefix   | 1E3E2E1E0
//  -------------------------------------------------------------------------

//----------------------------------------------------------
typedef enum logic [2:0]
{
    RD_3DW_HDR = 3'b000,
    RD_4DW_HDR = 3'b001,
    WR_3DW_HDR = 3'b010,
    WR_4DW_HDR = 3'b011,
    TLP_PREFIX = 3'b100
}
tlp_header_fmt_t;
//----------------------------------------------------------
typedef enum logic [4:0]
{
    MEM_RQ      = 5'b0_0000,
    MEM_RQ_LK   = 5'b0_0001,
    IO_RQ       = 5'b0_0010,
    CFG0_RQ     = 5'b0_0100,
    CFG1_RQ     = 5'b0_0101,
    CPL         = 5'b0_1010,
    CPL_LK      = 5'b0_1011,

    MSG_2RC     = 5'b1_0000,
    MSG_BY_ADDR = 5'b1_0001,
    MSG_BY_ID   = 5'b1_0010,
    MSG_BCAST   = 5'b1_0011,
    MSG_LOCAL   = 5'b1_0100,
    MSG_G2RC    = 5'b1_0101
}
tlp_header_type_t;
//----------------------------------------------------------
typedef struct packed
{
    logic [ 2:0] Fmt;
    logic [ 4:0] Type;
    logic        RESERVED_1_7;
    logic [ 2:0] TC;
    logic        RESERVED_1_3;
    logic        Attr2;            // ID based Ordering
    logic        RESERVED_1_1;
    logic        TH;               // Hints
    logic        TD;               // Digest
    logic        EP;               // Poison
    logic        Attr1;            // Relaxed Ordering
    logic        Attr0;            // No Snoop
    logic [ 1:0] AT;               // Address Type
    logic [ 9:0] Length;
}
tlp_header0_t;
//----------------------------------------------------------
typedef struct packed
{
    logic [15:0] RqID;
    logic [ 7:0] Tag;
    logic [ 3:0] LastBE;
    logic [ 3:0] FirstBE;

}
tlp_header1_t;
//----------------------------------------------------------
typedef enum logic [2:0]
{
    SUCCESSFULL_COMPLETION  = 3'b000,
    UNSUPPORTED_REQUEST     = 3'b001,
    CFG_RETRY_STATUS        = 3'b010,
    COMPLETER_ABORT         = 3'b100
}
compl_status_t;

typedef struct packed
{
    logic [ 7:0]   BusNumber;
    logic [ 4:0]   Device;
    logic [ 2:0]   Function;
    compl_status_t ComplStatus;
    logic          BCM;
    logic [  11:0] ByteCount;
}
tlp_header1_cpl_t;
//----------------------------------------------------------
typedef struct packed
{
    logic [15:0] RqID;
    logic [ 7:0] Tag;
    logic [ 7:0] MessageCode;
}
tlp_header1_msg_t;
//----------------------------------------------------------
typedef struct packed
{
    logic [ 7:0] BusNumber;
    logic [ 4:0] Device;
    logic [ 2:0] Function;
    logic [ 3:0] RESERVED_2_74;
    logic [ 3:0] ExtRegisterNumber;
    logic [ 5:0] RegisterNumber;
    logic [ 1:0] RESERVED_3_10;
}
tlp_header2_cfg_t;
//----------------------------------------------------------
typedef struct packed
{
    logic [ 7:0] BusNumber;
    logic [ 4:0] Device;
    logic [ 2:0] Function;
    logic [ 7:0] Tag;
    logic        RESERVED_3_7;
    logic [ 6:0] LowerAddress;
}
tlp_header2_cpl_t;
//----------------------------------------------------------
typedef enum logic [5:0]
{
    ltssmDETECT_QUIET0                               = 6'h00,
    ltssmDETECT_QUIET1                               = 6'h01,
    ltssmDETECT_ACTIVE0                              = 6'h02,
    ltssmDETECT_ACTIVE1                              = 6'h03,
    ltssmPOLLING_ACTIVE                              = 6'h04,
    ltssmPOLLING_CONFIGURATION                       = 6'h05,
    ltssmPOLLING_COMPLIANCE_PRE_SEND_EIOS            = 6'h06,
    ltssmPOLLING_COMPLIANCE_PRE_TIMEOUT              = 6'h07,
    ltssmPOLLING_COMPLIANCE_SEND_PATTERN             = 6'h08,
    ltssmPOLLING_COMPLIANCE_POST_SEND_EIOS           = 6'h09,
    ltssmPOLLING_COMPLIANCE_POST_TIMEOUT             = 6'h0A,
    ltssmCONFIGURATION_LINKWIDTH_STATE_0             = 6'h0B,
    ltssmCONFIGURATION_LINKWIDTH_STATE_1             = 6'h0C,
    ltssmCONFIGURATION_LINKWIDTH_ACCEPT_0            = 6'h0D,
    ltssmCONFIGURATION_LINKWIDTH_ACCEPT_1            = 6'h0E,
    ltssmCONFIGURATION_LANENUM_WAIT                  = 6'h0F,
    ltssmCONFIGURATION_LANENUM_ACCEPT                = 6'h10,
    ltssmCONFIGURATION_COMPLETE_X1                   = 6'h11,
    ltssmCONFIGURATION_COMPLETE_X2                   = 6'h12,
    ltssmCONFIGURATION_COMPLETE_X4                   = 6'h13,
    ltssmCONFIGURATION_COMPLETE_X8                   = 6'h14,
    ltssmCONFIGURATION_IDLE                          = 6'h15,
    ltssmL0                                          = 6'h16,
    ltssmL1_ENTRY0                                   = 6'h17,
    ltssmL1_ENTRY1                                   = 6'h18,
    ltssmL1_ENTRY2                                   = 6'h19,  // also used for the L2/L3 ready pseudo state
    ltssmL1_IDLE                                     = 6'h1A,
    ltssmL1_EXIT                                     = 6'h1B,
    ltssmRECOVERY_RCVRLOCK                           = 6'h1C,
    ltssmRECOVERY_RCVRCFG                            = 6'h1D,
    ltssmRECOVERY_SPEED_0                            = 6'h1E,
    ltssmRECOVERY_SPEED_1                            = 6'h1F,
    ltssmRECOVERY_IDLE                               = 6'h20,
    ltssmHOT_RESET                                   = 6'h21,
    ltssmDISABLED_ENTRY_0                            = 6'h22,
    ltssmDISABLED_ENTRY_1                            = 6'h23,
    ltssmDISABLED_ENTRY_2                            = 6'h24,
    ltssmDISABLED_IDLE                               = 6'h25,
    ltssmROOT_PORT_CONFIGURATION_LINKWIDTH_STATE_0   = 6'h26,
    ltssmROOT_PORT_CONFIGURATION_LINKWIDTH_STATE_1   = 6'h27,
    ltssmROOT_PORT_CONFIGURATION_LINKWIDTH_STATE_2   = 6'h28,
    ltssmROOT_PORT_CONFIGURATION_LINK_WIDTH_ACCEPT_0 = 6'h29,
    ltssmROOT_PORT_CONFIGURATION_LINK_WIDTH_ACCEPT_1 = 6'h2A,
    ltssmROOT_PORT_CONFIGURATION_LANENUM_WAIT        = 6'h2B,
    ltssmROOT_PORT_CONFIGURATION_LANENUM_ACCEPT      = 6'h2C,
    ltssmTIMEOUT_TO_DETECT                           = 6'h2D,
    ltssmLOOPBACK_ENTRY0                             = 6'h2E,
    ltssmLOOPBACK_ENTRY1                             = 6'h2F,
    ltssmLOOPBACK_ACTIVE0                            = 6'h30,
    ltssmLOOPBACK_EXIT0                              = 6'h31,
    ltssmLOOPBACK_EXIT1                              = 6'h32,
    ltssmLOOPBACK_MASTER_ENTRY0                      = 6'h33
}
ltssm_t;
//----------------------------------------------------------
typedef enum logic
{
    PL_SEL_LNK_RATE_2_5 = 1'b0,
    PL_SEL_LNK_RATE_5_0 = 1'b1
}
pl_sel_lnk_rate_t;
//----------------------------------------------------------
typedef enum logic [1:0]
{
    PL_SEL_LNK_WIDTH_x1 = 2'b00,
    PL_SEL_LNK_WIDTH_x2 = 2'b01,
    PL_SEL_LNK_WIDTH_x4 = 2'b10,
    PL_SEL_LNK_WIDTH_x8 = 2'b11
}
pl_sel_lnk_width_t;
//----------------------------------------------------------
//
//    PCIe Link Control Register
//
typedef enum logic [3:0]
{
    LINK_SR_LINK_SPEED_2_5 = 4'b0001,
    LINK_SR_LINK_SPEED_5_0 = 4'b0010
}
link_sr_current_link_speed_t;
//--------------------------------------
typedef struct packed
{
    logic [3:0] RESERVED_15_12;
    logic       link_autonomous_bandwidth_interrupt_enable;
    logic       link_bandwidth_management_interrupt_enable;
    logic       hardware_autonomous_width_disable;
    logic       enable_clock_power_management;
    logic       extended_synch;
    logic       common_clock_configuration;
    logic       retrain_link;
    logic       link_disable;
    logic       read_completion_boundary;
    logic       RESERVED_2;
    logic [1:0] active_state_power_management_control;
}
pcie_link_control_reg_t;
//----------------------------------------------------------
//
//    PCIe Link Status  Register
//
typedef enum logic [5:0]
{
    LINK_SR_LINK_WIDTH_x1  = 6'b00_0001,
    LINK_SR_LINK_WIDTH_x2  = 6'b00_0010,
    LINK_SR_LINK_WIDTH_x4  = 6'b00_0100,
    LINK_SR_LINK_WIDTH_x8  = 6'b00_1000,
    LINK_SR_LINK_WIDTH_x12 = 6'b00_1100,
    LINK_SR_LINK_WIDTH_x16 = 6'b01_0000,
    LINK_SR_LINK_WIDTH_x32 = 6'b10_0000
}
link_sr_negotiated_link_width_t;
//--------------------------------------
typedef struct packed
{
    logic                           link_autonomous_bandwidth_status;
    logic                           link_bandwidth_management_status;
    logic                           data_link_layer_link_active;
    logic                           slot_clock_configuration;
    logic                           link_training;
    logic                           undefined;
    link_sr_negotiated_link_width_t link_width;
    link_sr_current_link_speed_t    link_speed;
}
pcie_link_status_reg_t;
//----------------------------------------------------------
//
//    PCIe Device Capabilities Register
//
typedef enum logic [2:0]
{
    DEVCAP_MPS_128  = 3'b000,
    DEVCAP_MPS_256  = 3'b001,
    DEVCAP_MPS_512  = 3'b010,
    DEVCAP_MPS_1014 = 3'b011,
    DEVCAP_MPS_2048 = 3'b100,
    DEVCAP_MPS_4096 = 3'b101
}
pcie_max_payload_size_t;
//--------------------------------------
typedef struct packed
{
    logic [2:0] RESERVED_31_29;
    logic       function_level_reset_cap;
    logic [1:0] captured_slot_power_limit_scale;
    logic [7:0] captured_slot_power_limit_value;
    logic [1:0] RESERVED_17_16;
    logic       role_based_error_reporting;
    logic [2:0] undefined;
    logic [2:0] endpoint_L1_acceptable_latency;
    logic [2:0] endpoint_L0s_acceptable_latency;
    logic       extended_tag_field_supported;
    logic [1:0] phantom_functions_supproted;
    pcie_max_payload_size_t  MPS;
}
pcie_device_capabilities_reg_t;
//----------------------------------------------------------
typedef struct packed
{
    logic       bridge_cfg_retry_en;
    logic [2:0] MRS;
    logic       enable_no_snoop;
    logic       aux_power_pm_en;
    logic       phantom_functions_en;
    logic       extended_tag_field_en;
    logic [2:0] MPS;
    logic       enable_relaxed_ordering;
    logic       unsupported_request_reporting_en;
    logic       fatal_error_reporting_en;
    logic       nonfatal_error_reporting_en;
    logic       correctable_error_reporting_en;
}
pcie_device_control_reg_t;
//------------------------------------------------------------------------------
function automatic dword_t reverse_bytes(input dword_t data);
    
    return { data[7:0], data[15:8], data[23:16], data[31:24] };
    
endfunction
//------------------------------------------------------------------------------

endpackage // pcie_defs

import pcie_defs::*;

`endif // PCIE_DEFS_H
//------------------------------------------------------------------------------

