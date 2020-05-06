//------------------------------------------------------------------------------
//
//    Project:     Any
//
//    Description: Inferred Block Single-Port RAM module (read-first)
//
//    TODO: implement write-first mode
//------------------------------------------------------------------------------

module block_ram_sp_m
                #(
                   parameter int ADDR_WIDTH,
                   parameter int WORD_WIDTH,
                   parameter     INIT_FILE = ""  
                 )
(
    //---
    input  logic                  clk,
    
    //---
    input  logic                  en,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [WORD_WIDTH-1:0] data_in,
    output logic [WORD_WIDTH-1:0] data_out
);

//==============================================================================
//    Settings
//==============================================================================

localparam RAM_SIZE = 2**ADDR_WIDTH;

//==============================================================================
//    Objects
//==============================================================================

(* ram_style="block" *)
logic [WORD_WIDTH-1:0] ram[RAM_SIZE];

//==============================================================================
//     Logic
//==============================================================================

//------------------------------------------------------------------------------
initial begin
    if(INIT_FILE != "") begin
        $readmemh(INIT_FILE, ram, 0);
    end
end

//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if(en) begin
        if(we) begin
            ram[addr] <= data_in;
        end
        data_out <= ram[addr];
    end
end

endmodule : block_ram_sp_m
