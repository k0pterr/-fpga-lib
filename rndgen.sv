//------------------------------------------------------------------------------
//  project:       any
//
//  modules:       rnd_m
//
//  description:   parametrized synthesizable random generator pkg
//                 see Xilinx xapp 052, xapp 211
//------------------------------------------------------------------------------

`include "rndgen.pkg"    

//******************************************************************************
//******************************************************************************
module rnd_m import rndgen_pkg::*;
                #(
                    parameter RndGenParams_t PARAMS = RndGen31
                 )
(
    input  logic  clk,
    input  logic  rst,

    output logic  out     
);

//==============================================================================
//    Types
//==============================================================================

typedef logic [1:PARAMS.TapeNum] RndReg_t; 

//==============================================================================
//    Functions and Tasks
//==============================================================================

//------------------------------------------------------------------------------
function automatic RndReg_t rnd_gen(input RndReg_t in);
    RndReg_t out;
    logic res = 1'b1;
    int i = 0;
    while (PARAMS.FB[i]) begin
        res = res ~^ in[PARAMS.FB[i]];
        i++;
    end
    out = { res, in[1:PARAMS.TapeNum-1] };
    return out;
endfunction

//==============================================================================
//    Objects
//==============================================================================

RndReg_t rnd_reg = '0;

//==============================================================================
//     Logic
//==============================================================================

//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if(rst) begin
        rnd_reg <= '0;
    end
    else begin
        rnd_reg <= rnd_gen(rnd_reg);
    end
end

//------------------------------------------------------------------------------
assign out = rnd_reg[PARAMS.TapeNum];

endmodule : rnd_m
