//******************************************************************************
//*
//*      Project:     Any
//*
//*      Description: AXI Bus Interfaces
//*
//*      Version 1.0
//*
//*      Copyright (c) 2018-2019, Harry E. Zhurov
//*
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//    AXI4-Lite
//
interface axi4_lite_if
    #(
        parameter ADDR_W  = 32,
        parameter DATA_W  = 32
    )
(
    // global
    input logic ACLK,
    input logic ARESETn
);

// write address channel
logic                AWVALID;
logic                AWREADY;
logic [  ADDR_W-1:0] AWADDR;
logic [         2:0] AWPROT;

// write data channel
logic                WVALID;
logic                WREADY;
logic [  DATA_W-1:0] WDATA;
logic [DATA_W/8-1:0] WSTRB;

// write response channel
logic                BVALID;
logic                BREADY;
logic                BRESP;

// read address channel
logic                ARVALID;
logic                ARREADY;
logic [  ADDR_W-1:0] ARADDR;
logic [         2:0] ARPROT;

// read data channel
logic                RVALID;
logic                RREADY;
logic [  DATA_W-1:0] RDATA;
logic                RRESP;

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
//    AXI4
//
interface axi4_wr_if
    #(
        parameter   ID_W  = 1,
        parameter ADDR_W  = 32,
        parameter DATA_W  = 32
    )
(
    // global
    input logic ACLK,
    input logic ARESETn
);

// write address channel
logic [          ID_W-1:0] AWID;
logic                      AWVALID;
logic                      AWREADY;
logic [        ADDR_W-1:0] AWADDR;
logic [               7:0] AWLEN;
logic [               2:0] AWSIZE;
logic [               1:0] AWBURST;
logic                      AWLOCK;
logic [               3:0] AWCACHE;
logic [               2:0] AWPROT;
logic [               3:0] AWQOS;
logic [               3:0] AWREGION;

// write data channel
logic                      WVALID;
logic                      WREADY;
logic [        DATA_W-1:0] WDATA;
logic [      DATA_W/8-1:0] WSTRB;
logic                      WLAST;

// write response channel
logic [          ID_W-1:0] BID;
logic                      BVALID;
logic                      BREADY;
logic [               1:0] BRESP;

modport master
(
    output AWID,
    output AWVALID,
    input  AWREADY,
    output AWADDR,
    output AWLEN,
    output AWSIZE,
    output AWBURST,
    output AWLOCK,
    output AWCACHE,
    output AWPROT,
    output AWQOS,
    output AWREGION,

    output WVALID,
    input  WREADY,
    output WDATA,
    output WSTRB,
    output WLAST,

    input  BID,
    input  BVALID,
    output BREADY,
    input  BRESP
);

modport slave
(
    input   AWID,
    input   AWVALID,
    output  AWREADY,
    input   AWADDR,
    input   AWLEN,
    input   AWSIZE,
    input   AWBURST,
    input   AWLOCK,
    input   AWCACHE,
    input   AWPROT,
    input   AWQOS,
    input   AWREGION,

    input   WVALID,
    output  WREADY,
    input   WDATA,
    input   WSTRB,
    input   WLAST,

    output  BID,
    output  BVALID,
    input   BREADY,
    output  BRESP

);

endinterface
//------------------------------------------------------------------------------
interface axi4_rd_if
    #(
        parameter   ID_W  = 1,
        parameter ADDR_W  = 32,
        parameter DATA_W  = 32
    )
(
    // global
    input logic ACLK,
    input logic ARESETn
);

// read address channel
logic                      ARVALID;
logic                      ARREADY;
logic [        ADDR_W-1:0] ARADDR;
logic [               7:0] ARLEN;
logic [               2:0] ARSIZE;
logic [               1:0] ARBURST;
logic                      ARLOCK;
logic [               3:0] ARCACHE;
logic [               2:0] ARPROT;
logic [               3:0] ARQOS;
logic [               3:0] ARREGION;

// read data channel
logic [          ID_W-1:0] RID;
logic                      RVALID;
logic                      RREADY;
logic [        DATA_W-1:0] RDATA;
logic [               1:0] RRESP;
logic                      RLAST;

modport master
(
    output ARVALID,
    input  ARREADY,
    output ARADDR,
    output ARLEN,
    output ARSIZE,
    output ARBURST,
    output ARLOCK,
    output ARCACHE,
    output ARPROT,
    output ARQOS,
    output ARREGION,

    input  RID,
    input  RVALID,
    output RREADY,
    input  RDATA,
    input  RRESP,
    input  RLAST
);

modport slave
(
    input   ARVALID,
    output  ARREADY,
    input   ARADDR,
    input   ARLEN,
    input   ARSIZE,
    input   ARBURST,
    input   ARLOCK,
    input   ARCACHE,
    input   ARPROT,
    input   ARQOS,
    input   ARREGION,

    output  RID,
    output  RVALID,
    input   RREADY,
    output  RDATA,
    output  RRESP,
    output  RLAST
);

endinterface
//------------------------------------------------------------------------------
interface axis_if
    #(
        parameter   DATA_W    = 64,
        localparam  KEEP_W    = DATA_W/8
    )
(
);

logic              TVALID;
logic              TREADY;
logic [DATA_W-1:0] TDATA;
logic [KEEP_W-1:0] TKEEP;
logic              TLAST;

modport master    
(
    output TVALID,
    input  TREADY,
    output TDATA,
    output TKEEP,  
    output TLAST
);

modport slave
(
    input  TVALID,
    output TREADY,
    input  TDATA,
    input  TKEEP,
    input  TLAST
);

endinterface
//------------------------------------------------------------------------------
interface axis_reg_if
    #(
        parameter   DATA_W    = 64,
        localparam  KEEP_W    = DATA_W/8
    )
(
    input logic ACLK,
    input logic ARESETn
);

//  objects
logic              TVALID;
logic              TREADY;
logic [DATA_W-1:0] TDATA;
logic [KEEP_W-1:0] TKEEP;
logic              TLAST;

logic [DATA_W-1:0] tdata;    
logic [KEEP_W-1:0] tkeep;
logic              tlast;
logic              ready;  // ready to get data from input
logic              valid;  // valid data for output
logic              full = 0;
logic              wr_en;
logic              rd_en;

//  logic 
assign ready = !full || rd_en;
assign valid = full;

always_ff @(posedge ACLK) begin
    if(!full) begin
        if(wr_en) begin
            full <= 1;
        end
    end
    else begin
        if(!wr_en && rd_en) begin
            full <= 0;
        end
    end
end

always_ff @(posedge ACLK) begin
    if(wr_en && ready) begin  // input handshake
        tdata <= TDATA;
        tkeep <= TKEEP;
        tlast <= TLAST;
    end
end

//  modports
modport master    
(
    output .TVALID  ( wr_en ),
    input  .TREADY  ( ready ),
    output TDATA,
    output TKEEP,  
    output TLAST
);

modport slave
(
    input  .TVALID ( valid ),
    output .TREADY ( rd_en ),
    input  .TDATA  ( tdata ),
    input  .TKEEP  ( tkeep ),
    input  .TLAST  ( tlast )
);

endinterface
//------------------------------------------------------------------------------


