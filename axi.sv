//******************************************************************************
//*
//*      Project:     Any
//*
//*      Description: AXI Bus Interfaces
//*
//*      Version 1.0
//*
//*      Copyright (c) 2018, Harry E. Zhurov
//*
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//    AXI4-Lite
//
interface axi4_lite_if
    #(
        parameter ADDR_W = 32,
        parameter DATA_W = 32
    )
(
    // global
    input logic ACLK,
    input logic ARESETn
);

    // write address channel
    logic              AWVALID;
    logic              AWREADY;
    logic [ADDR_W-1:0] AWADDR;
    logic [       2:0] AWPROT;

    // write data channel
    logic              WVALID;
    logic              WREADY;
    logic [DATA_W-1:0] WDATA;
    logic              WSTRB;

    // write response channel
    logic              BVALID;
    logic              BREADY;
    logic              BRESP;

    // read address channel
    logic              ARVALID;
    logic              ARREADY;
    logic [ADDR_W-1:0] ARADDR;
    logic [       2:0] ARPROT;

    // read data channel
    logic              RVALID;
    logic              RREADY;
    logic [DATA_W-1:0] RDATA;
    logic              RRESP;

modport master
(
    output AWVALID,
    input  AWREADY,
    output AWADDR,
    output AWPROT,

    output WVALID,
    input  WREADY,
    output WDATA,
    output WSTRB,

    input  BVALID,
    output BREADY,
    input  BRESP,
    
    output ARVALID,
    input  ARREADY,
    output ARADDR,
    output ARPROT,

    input  RVALID,
    output RREADY,
    input  RDATA,
    input  RRESP
);

modport slave
(
    input  AWVALID,
    output AWREADY,
    input  AWADDR,
    input  AWPROT,

    input  WVALID,
    output WREADY,
    input  WDATA,
    input  WSTRB,

    output BVALID,
    input  BREADY,
    output BRESP,

    input  ARVALID,
    output ARREADY,
    input  ARADDR,
    input  ARPROT,

    output RVALID,
    input  RREADY,
    output RDATA,
    output RRESP
);

endinterface
//------------------------------------------------------------------------------
//
//    AXI4-Lite
//
interface axi4_if;
    
endinterface
//------------------------------------------------------------------------------


