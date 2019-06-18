//******************************************************************************
//*
//*    Project:     Any
//*    ~~~~~~~
//*    Purpose:     Register stage for handshake-based interfaces
//*    ~~~~~~~
//*    Description
//*    ~~~~~~~~~~~
//*    Parameter type 'DATA_T' must be any kind of packed array.
//*    For example:
//*                 
//*        typedef struct packed
//*        {
//*            logic [PCIE_AXIS_DATA_W-1:0] tdata;
//*            logic [PCIE_AXIS_KEEP_W-1:0] tkeep;
//*            logic                        tlast;
//*        }
//*        tx_data_t;
//*  
//*  The convenient way is to merge control signals and interface
//*  data to structure type, for instance:
//*  
//*        typedef struct
//*        {
//*            logic     valid;
//*            logic     ready;
//*            tx_data_t data;
//*        }
//*        axis_tx_t;
//*                 
//*  Declare corresponding objects:               
//*
//*      axis_tx_t tx_src;
//*      axis_tx_t tx_dst;
//*
//*  And finally, create the instance of register stage module:
//*
//*      reg_stage_m
//*          #(
//*              .DATA_T ( tx_data_t )
//*           )
//*      axis_tx_stage
//*      (
//*          .clk       ( clk ),
//*          .valid_src ( tx_src.valid ),
//*          .ready_src ( tx_src.ready ),
//*          .src       ( tx_src.data  ),
//*          .valid_dst ( tx_dst.valid ),
//*          .ready_dst ( tx_dst.ready ),
//*          .dst       ( tx_dst.data  )
//*      );
//*
//******************************************************************************

//------------------------------------------------------------------------------
module reg_stage_m
    #(
        parameter type DATA_T = logic
     )
(
    input  logic   clk,

    input  logic   valid_src,
    output logic   ready_src,
    input  DATA_T  src,

    output logic   valid_dst,
    input  logic   ready_dst,
    output DATA_T  dst
);

//  objects
logic  full = 0;

//  logic
assign ready_src = !full || ready_dst;
assign valid_dst = full;

always_ff @(posedge clk) begin
    if(!full) begin
        if(valid_src) begin
            full <= 1;
        end
    end
    else begin
        if(!valid_src && ready_dst) begin
            full <= 0;
        end
    end
end

always_ff @(posedge clk) begin
    if(valid_src && ready_src) begin  // input handshake
        dst <= src;
    end
end

endmodule : reg_stage_m
//------------------------------------------------------------------------------

