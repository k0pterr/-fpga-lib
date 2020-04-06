//------------------------------------------------------------------------------
//  project:       any
//
//  packages:      rndgen_pkg
//
//  description:   parametrized synthesizable random generator pkg
//                 see Xilinx xapp 052, xapp 211
//------------------------------------------------------------------------------

`ifndef RNDGEN_H
`define RNDGEN_H

//******************************************************************************
//******************************************************************************
package rndgen_pkg;

//------------------------------------------------------------------------------
typedef struct {
    shortint unsigned TapeNum;
    shortint unsigned FB[5];
} RndGenParams_t;

//==============================================================================
//    Settings
//==============================================================================

//------------------------------------------------------------------------------
localparam RndGenParams_t RndGen8  = '{  8, '{  8,  6,   5,   4,  0 } };
localparam RndGenParams_t RndGen9  = '{  9, '{  9,  5,   0,   0,  0 } };
localparam RndGenParams_t RndGen15 = '{ 15, '{ 15, 14,   0,   0,  0 } };
localparam RndGenParams_t RndGen27 = '{ 27, '{ 27, 26,  25,  22,  0 } };
localparam RndGenParams_t RndGen31 = '{ 31, '{ 31, 28,   0,   0,  0 } };
localparam RndGenParams_t RndGen37 = '{ 37, '{ 37, 12,  10,   2,  0 } };


endpackage : rndgen_pkg

`endif // RNDGEN_H
//------------------------------------------------------------------------------

