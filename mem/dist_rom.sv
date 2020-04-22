//------------------------------------------------------------------------------
//
//    Project:     Any
//
//    Description: Inferred Distibuted ROM modules
//
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//    Distributed memory based ROM with output register
//
module dist_rom_oreg_m
                #(
                   parameter int ADDR_WIDTH,
                   parameter int WORD_WIDTH,
                   parameter int ROM_SIZE = 2**ADDR_WIDTH,
                   parameter logic [WORD_WIDTH-1:0] INIT_DATA [ROM_SIZE]    
                 )
(
    input  logic                  clk,
    
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [WORD_WIDTH-1:0] data
);

//------------------------------------------------------------------------------
//
//    Objects
//

(* rom_style="distributed" *)
logic [WORD_WIDTH-1:0] rom[ROM_SIZE];

//------------------------------------------------------------------------------
//
//    Logic
//

//------------------------------------------------------------------------------
initial begin
    for(int i = 0; i < ROM_SIZE; i++) begin
        rom[i] = INIT_DATA[i];
    end
end

//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    data <= rom[addr];
end

endmodule : dist_rom_oreg_m
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//    Distributed memory based ROM 
//
module dist_rom_m
                #(
                   parameter int ADDR_WIDTH,
                   parameter int WORD_WIDTH,
                   parameter int ROM_SIZE = 2**ADDR_WIDTH,
                   parameter     INIT_FILE = ""  
                 )
(
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [WORD_WIDTH-1:0] data
);

//------------------------------------------------------------------------------
//
//    Objects
//
(* rom_style="distributed" *)
logic [WORD_WIDTH-1:0] rom[ROM_SIZE];

//------------------------------------------------------------------------------
//
//     Logic
initial begin
    if(INIT_FILE != "") begin
        $readmemh(INIT_FILE, rom, 0);
    end
end

//------------------------------------------------------------------------------
assign data = rom[addr];

endmodule : dist_rom_m
//------------------------------------------------------------------------------

