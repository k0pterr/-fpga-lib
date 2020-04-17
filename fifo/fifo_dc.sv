//------------------------------------------------------------------------------
//
//    Project:     Any
//
//    Description: Instantiated Single-Clock FIFO module
//
//------------------------------------------------------------------------------

`include "common.svh"

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//   
//   
//   MEMTYPE options:
//
//       0. "auto"
//       1. "distributed"
//       2. "block"
//   
//
module fifo_dc_m
#(
    parameter type DATA_ITEM_TYPE = logic,
    parameter      DEPTH          = 32,
    parameter      MEMTYPE        = "auto",
    parameter      RELATED_CLOCKS = "no",
    parameter      SYNC_STAGES    = 2
)
(
    input  logic           wr_clk,
    input  logic           rd_clk,
    input  logic           rst,
                           
    input  DATA_ITEM_TYPE  tail,
    output DATA_ITEM_TYPE  head,
    input  logic           push,
    input  logic           pop,
    output logic           full,
    output logic           empty,
    output logic           wr_rst_busy,
    output logic           rd_rst_busy
);

//------------------------------------------------------------------------------
//    Settings
//
localparam logic RELCLK = RELATED_CLOCKS == "yes" ? 1 : 0;  
        
    
//------------------------------------------------------------------------------
//    Types
//------------------------------------------------------------------------------
//    Objects
//------------------------------------------------------------------------------
//    Functions and tasks
//------------------------------------------------------------------------------
//    Logic
//------------------------------------------------------------------------------
//
//    Instances
//
xpm_fifo_async 
#(
    .FIFO_MEMORY_TYPE    ( MEMTYPE               ),
    .CDC_SYNC_STAGES     ( SYNC_STAGES           ),
    .READ_MODE           ( "fwft"                ),
    .RELATED_CLOCKS      ( RELCLK                ),
    .FIFO_WRITE_DEPTH    ( DEPTH                 ),
    .WRITE_DATA_WIDTH    ( $bits(DATA_ITEM_TYPE) ),
    .READ_DATA_WIDTH     ( $bits(DATA_ITEM_TYPE) ),
    .USE_ADV_FEATURES    ( "0000"                ),  // all advanced features disabled
    .DOUT_RESET_VALUE    ( "0"                   ),
    .ECC_MODE            ( "no_ecc"              ),
    .FIFO_READ_LATENCY   ( 0                     ),
    .WAKEUP_TIME         ( 0                     )
                           
//  .WR_DATA_COUNT_WIDTH ( 1                     ),
//  .RD_DATA_COUNT_WIDTH ( 1                     ),
//  .PROG_FULL_THRESH    ( 10                    ),
//  .PROG_EMPTY_THRESH   ( 10                    ),
//  .FULL_RESET_VALUE    ( 0                     ),
                           
) 
fifo_instance
(
    .rst            ( rst         ),
    .wr_clk         ( wr_clk      ),
    .rd_clk         ( rd_clk      ),
    .din            ( tail        ),
    .dout           ( head        ),
    .wr_en          ( push        ),
    .rd_en          ( pop         ),
    .full           ( full        ),
    .empty          ( empty       ),
    .wr_rst_busy    ( wr_rst_busy ),
    .rd_rst_busy    ( rd_rst_busy ),

    .prog_full      (             ),
    .almost_full    (             ),
    .wr_data_count  (             ),
    .overflow       (             ),
    .prog_empty     (             ),
    .rd_data_count  (             ),
    .underflow      (             ),
    .almost_empty   (             ),
    .wr_ack         (             ),
    .data_valid     (             ),
    .sleep          ( 1'b0        ),
    .injectsbiterr  ( 1'b0        ),
    .injectdbiterr  ( 1'b0        ),
    .sbiterr        (             ),
    .dbiterr        (             )
);
//------------------------------------------------------------------------------

endmodule : fifo_dc_m
//------------------------------------------------------------------------------

