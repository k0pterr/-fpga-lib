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
//       1. "lutram", "LUTRAM", "distributed", "DISTRIBUTED"
//       2. "bram", "BRAM", "block", "BLOCK"
//       3. "uram", "URAM", "ultra", "ULTRA"
//       4. "builtin", "BUILTIN"
//   
//
module fifo_sc_rdc_m
#(
    parameter type DATA_ITEM_TYPE = logic,
    parameter      DEPTH          = 32,
    parameter      MEMTYPE        = "auto",
    localparam     DATA_COUNT_W   = bits(DEPTH)
)
(
    input  logic                    clk,
    input  logic                    rst,
                                    
    input  DATA_ITEM_TYPE           tail,
    output DATA_ITEM_TYPE           head,
    input  logic                    push,
    input  logic                    pop,
    output logic                    full,
    output logic                    empty,
    output logic [DATA_COUNT_W-1:0] data_count,
    output logic                    wr_rst_busy,
    output logic                    rd_rst_busy
);

//------------------------------------------------------------------------------
//    Settings
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
xpm_fifo_sync
#(
    .DOUT_RESET_VALUE    ( "0"                   ),
    .ECC_MODE            ( "no_ecc"              ),
    .FIFO_MEMORY_TYPE    ( MEMTYPE               ),
    .READ_MODE           ( "fwft"                ),
    .FIFO_READ_LATENCY   ( 0                     ),
    .FIFO_WRITE_DEPTH    ( DEPTH                 ),
    .WRITE_DATA_WIDTH    ( $bits(DATA_ITEM_TYPE) ),
    .READ_DATA_WIDTH     ( $bits(DATA_ITEM_TYPE) ),
    .USE_ADV_FEATURES    ( "0400"                ),  // read data count
    .RD_DATA_COUNT_WIDTH ( DATA_COUNT_W          ),
    .WR_DATA_COUNT_WIDTH ( DATA_COUNT_W          ) 

//  .FULL_RESET_VALUE        ( 0        ), // DECIMAL
//  .PROG_EMPTY_THRESH       ( 3        ), // DECIMAL
//  .PROG_FULL_THRESH        ( 3        ), // DECIMAL
//  .WAKEUP_TIME             ( 0        ), // DECIMAL
)
fifo_instance
(
    .wr_clk        ( clk         ),
    .rst           ( rst         ),
    .din           ( tail        ),
    .dout          ( head        ),
    .wr_en         ( push        ),
    .rd_en         ( pop         ),
    .full          ( full        ),
    .empty         ( empty       ),
    .rd_data_count ( data_count  ),
    .wr_rst_busy   ( wr_rst_busy ),
    .rd_rst_busy   ( rd_rst_busy ),

    .data_valid    (             ),
    .almost_empty  (             ),
    .underflow     (             ),
    .prog_empty    (             ),
    .wr_ack        (             ),
    .almost_full   (             ),
    .overflow      (             ),
    .wr_data_count (             ),
    .prog_full     (             ),
    .sleep         ( 1'b0        ),
    .injectdbiterr ( 1'b0        ),
    .injectsbiterr ( 1'b0        ),
    .dbiterr       (             ),
    .sbiterr       (             )
);

//------------------------------------------------------------------------------
//
//    SVA
//
property overflow_detect;
    @(posedge clk)
    disable iff (rst)
    !(push && full);
endproperty

property underflow_detect;
    @(posedge clk)
    disable iff (rst)
    !(pop && empty);
endproperty

assert property ( overflow_detect ) else begin
    $error($time, "ns FIFO overflow at %m");
    $stop(2);
end
assert property ( underflow_detect ) else begin
    $error($time, "ns FIFO underflow at %m");
    $stop(2);
end
//------------------------------------------------------------------------------

endmodule : fifo_sc_rdc_m
//------------------------------------------------------------------------------

