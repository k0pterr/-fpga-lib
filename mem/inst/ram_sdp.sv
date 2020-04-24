//------------------------------------------------------------------------------
//
//    Project:     Any
//
//    Description: Instantiated Simple Dual-Port RAM module based 
//                 on XPM_MEMORY_SDPRAM
//
//
//    Parameters:
//
//        ------------------------+--------------------------------------------
//        MEM_SIZE                | in bits
//        ------------------------+--------------------------------------------
//        MEM_TYPE                | "auto", "block", "distributed", "ultra"
//        ------------------------+--------------------------------------------
//        CLOCKING_MODE           | "common_clock", "independent_clock"
//        ------------------------+--------------------------------------------
//        BYTE_WRITE_WIDTH_A      | To enable byte-wide writes on port A:
//                                | 
//                                |   * 8: 8-bit byte-wide writes,              
//                                |        legal when WRITE_DATA_WIDTH_A is an  
//                                |         integer multiple of 8               
//                                |                                             
//                                |   * 9: 9-bit byte-wide writes,              
//                                |        legal when WRITE_DATA_WIDTH_A is an  
//                                |        integer multiple of 9                
//                                |                                           
//                                | Else to enable word-wide writes on port A, 
//                                | specify the same value as                 
//                                | for WRITE_DATA_WIDTH_A.                   
//        ------------------------+--------------------------------------------
//        READ_LATENCY_B          | Specify the number of register stages in 
//                                | the port B read data pipeline. 
//                                |
//                                | Read data output to port doutb takes     
//                                | this number of clkb cycles (clka when    
//                                | CLOCKING_MODE is "common_clock").        
//                                |                                          
//                                | To target block memory, a value of 1     
//                                | or larger is required:                   
//                                |  * 1 causes use of memory latch only;    
//                                |  * 2 causes use of output register.      
//                                |                                          
//                                | To target distributed memory, a value    
//                                | of 0 or larger is required - 0 indicates 
//                                | combinatorial output. Values larger      
//                                | than 2 synthesize additional flip-flops  
//                                | that are not retimed into memory         
//                                | primitives.                              
//        ------------------------+--------------------------------------------
//        WRITE_MODE_B            | Write mode behavior for port B output data 
//                                | port, doutb. "no_change", "read_first", 
//                                | "write_first"
//        ------------------------+--------------------------------------------
//
//------------------------------------------------------------------------------

module automatic ram_sdp_m
#(
    parameter int  MEM_SIZE        = 2048,
    parameter      MEM_TYPE        = "block",
    parameter      CLOCKING_MODE   = "common_clock",
    parameter      WRITE_MODE_B    = "read_first",
    
    parameter int  WR_DATA_W       = 32,
    parameter int  BYTE_WRITE_W    = WR_DATA_W,
    parameter int  WR_ADDR_W       = $clog2(MEM_SIZE/WR_DATA_W),
                                   
    parameter int  RD_DATA_W       = WR_DATA_W,
    parameter int  RD_ADDR_W       = $clog2(MEM_SIZE/RD_DATA_W),
    parameter      RD_RESET_VALUE  = "0",
    parameter int  RD_LATENCY      = 2,

    parameter int  USE_MEM_INIT    = 1,
    parameter      MEM_INIT_FILE   = "none",
    parameter      MEM_INIT_PARAM  = "",
    parameter int  AUTO_SLEEP_TIME = 0,
    parameter      WAKEUP_TIME     = "disable_sleep",

    localparam int WEA_W           = WR_DATA_W/BYTE_WRITE_W,
    localparam type wr_addr_t      = logic [WR_ADDR_W-1:0],
    localparam type rd_addr_t      = logic [RD_ADDR_W-1:0],
    localparam type wr_data_t      = logic [WR_DATA_W-1:0],
    localparam type rd_data_t      = logic [RD_DATA_W-1:0],
    localparam type wea_t          = logic [    WEA_W-1:0] 
)
(

    input  logic        wr_clk,
    input  wea_t        wr_en,
    input  wr_addr_t    wr_addr,
    input  wr_data_t    wr_data,

    input  logic        rd_clk,
    input  logic        rd_en,
    input  rd_addr_t    rd_addr,
    output rd_data_t    rd_data
);

//------------------------------------------------------------------------------
//
//    Settings
//
localparam int USE_CDC_CONSTRAINT = MEM_TYPE == "distributed" && CLOCKING_MODE == "independent_clock";

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
xpm_memory_sdpram 
#(
    .MEMORY_SIZE             ( MEM_SIZE                   ),
    .MEMORY_PRIMITIVE        ( MEM_TYPE                   ),
    .CLOCKING_MODE           ( CLOCKING_MODE              ),
    .USE_EMBEDDED_CONSTRAINT ( USE_CDC_CONSTRAINT         ),
    .MEMORY_OPTIMIZATION     ( "true"                     ),
    .WRITE_DATA_WIDTH_A      ( WR_DATA_W                  ),
    .BYTE_WRITE_WIDTH_A      ( BYTE_WRITE_W               ),
    .ADDR_WIDTH_A            ( $clog2(MEM_SIZE/WR_DATA_W) ),
    .READ_DATA_WIDTH_B       ( RD_DATA_W                  ),
    .ADDR_WIDTH_B            ( $clog2(MEM_SIZE/RD_DATA_W) ),
    .READ_RESET_VALUE_B      ( "0"                        ),
    .READ_LATENCY_B          ( RD_LATENCY                 ),
    .WRITE_MODE_B            ( WRITE_MODE_B               ),
    .ECC_MODE                ( "no_ecc"                   ),
    .MESSAGE_CONTROL         ( 0                          ),
    .MEMORY_INIT_FILE        ( MEM_INIT_FILE              ),
    .MEMORY_INIT_PARAM       ( MEM_INIT_PARAM             ),
    .USE_MEM_INIT            ( USE_MEM_INIT               ),
    .AUTO_SLEEP_TIME         ( 0                          ),
    .WAKEUP_TIME             ( "disable_sleep"            )
)
xpm_sdpram_inst
(
  .clka           ( wr_clk  ),
  .ena            ( |wr_en  ),
  .wea            ( wr_en   ),
  .addra          ( wr_addr ),
  .dina           ( wr_data ),
  .clkb           ( rd_clk  ),
  .rstb           ( 1'b0    ),  // Reset signal for the final port B output register stage (1) 
  .enb            ( rd_en   ),
  .regceb         ( rd_en   ),  // Clock Enable for the last register stage on the output data path
  .addrb          ( rd_addr ),
  .doutb          ( rd_data ),
  .injectsbiterra ( 1'b0    ),
  .injectdbiterra ( 1'b0    ),
  .sbiterrb       (         ),
  .dbiterrb       (         ),
  .sleep          ( 1'b0    )
);

// (1) Synchronously resets output port doutb to the value specified by parameter READ_RESET_VALUE_B

endmodule
//------------------------------------------------------------------------------

