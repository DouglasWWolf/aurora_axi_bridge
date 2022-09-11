`timescale 1ns / 1ps
//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 08-Sep-22  DWW  1000  Initial creation
//===================================================================================================

/*
    Overview:

    This module has up to 64 64-bit address vectors, and those addresses are mapped into 
    the first 128 words of address space like this:

        Vector #0 high-bits = BaseAddr + 0x00
        Vector #0 low-bits  = BaseAddr + 0x04
        Vector #1 high-bits = BaseAddr + 0x08
        Vector #1 low-bits  = BaseAddr + 0x0C
                 (etc)

    Data registers start at BaseAddress + 0x100, like this:
        Data Register #0 = BaseAddr + 0x100
        Data Register #1 = BaseAddr + 0x104
        Data Register #2 = BaseAddr + 0x108
                 (etc)
    
    Reading or writing a data register performs a read or write of the corresponding vector
    address on the remote system

*/


`define M_AXI_ADDR_WIDTH 32
`define M_AXI_DATA_WIDTH 32
`define AXIS_DATA_WIDTH 256


//===================================================================================================
// If you change the number of vectors (i.e., VECTOR_COUNT), don't forget to update the number of
// default parameters in the module parameter list, and to update the table of  'assign vector[nn]'
// statements !!!!
//===================================================================================================
`define VECTOR_COUNT 16
//===================================================================================================

module aximm_over_stream_client #
(
    parameter VECTOR_00 = 64'h4000,
    parameter VECTOR_01 = 64'h4008,
    parameter VECTOR_02 = 64'h0,
    parameter VECTOR_03 = 64'h0,
    parameter VECTOR_04 = 64'h0,
    parameter VECTOR_05 = 64'h0,
    parameter VECTOR_06 = 64'h0,
    parameter VECTOR_07 = 64'h0,
    parameter VECTOR_08 = 64'h0,
    parameter VECTOR_09 = 64'h0,
    parameter VECTOR_10 = 64'h0,
    parameter VECTOR_11 = 64'h0,
    parameter VECTOR_12 = 64'h0,
    parameter VECTOR_13 = 64'h0,
    parameter VECTOR_14 = 64'h0,
    parameter VECTOR_15 = 64'h0
)
(
    input clk, resetn,

    //============================ This is an AXI4-Lite slave interface =============================
        
    // "Specify write address"              -- Master --    -- Slave --
    input[31:0]                             S_AXI_AWADDR,   
    input                                   S_AXI_AWVALID,  
    output                                                  S_AXI_AWREADY,
    input[2:0]                              S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input[31:0]                             S_AXI_WDATA,      
    input                                   S_AXI_WVALID,
    input[3:0]                              S_AXI_WSTRB,
    output                                                  S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             S_AXI_BRESP,
    output                                                  S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[31:0]                             S_AXI_ARADDR,     
    input                                   S_AXI_ARVALID,
    input[2:0]                              S_AXI_ARPROT,     
    output                                                  S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output[31:0]                                            S_AXI_RDATA,
    output                                                  S_AXI_RVALID,
    output[1:0]                                             S_AXI_RRESP,
    input                                   S_AXI_RREADY,
    //===============================================================================================


    //========================  AXI Stream interface for sending requests  ==========================
    output reg [`AXIS_DATA_WIDTH-1:0] AXIS_TX_TDATA,
    output reg                        AXIS_TX_TVALID,
    output reg                        AXIS_TX_TLAST,
    input                             AXIS_TX_TREADY,
    //===============================================================================================


    //========================  AXI Stream interface for receiving responses  =======================
    input [`AXIS_DATA_WIDTH-1:0] AXIS_RX_TDATA,
    input                        AXIS_RX_TVALID,
    input                        AXIS_RX_TLAST,
    output reg                   AXIS_RX_TREADY
    //===============================================================================================

 );

    // Some convenience declarations
    localparam M_AXI_ADDR_WIDTH = `M_AXI_ADDR_WIDTH;
    localparam M_AXI_DATA_WIDTH = `M_AXI_DATA_WIDTH;
    localparam AXIS_DATA_WIDTH  = `AXIS_DATA_WIDTH;
    localparam VECTOR_COUNT     = `VECTOR_COUNT;

    //===============================================================================================
    // We'll communicate with the AXI4-Lite Slave core with these signals.
    //===============================================================================================

    // AXI Slave Handler Interface for write requests
    wire[31:0]  ashi_waddr;     // Input:  Write-address
    wire[31:0]  ashi_wdata;     // Input:  Write-data
    wire        ashi_write;     // Input:  1 = Handle a write request
    reg[1:0]    ashi_wresp;     // Output: Write-response (OKAY, DECERR, SLVERR)
    wire        ashi_widle;     // Output: 1 = Write state machine is idle

    // AXI Slave Handler Interface for read requests
    wire[31:0]  ashi_raddr;     // Input:  Read-address
    wire        ashi_read;      // Input:  1 = Handle a read request
    reg[31:0]   ashi_rdata;     // Output: Read data
    reg[1:0]    ashi_rresp;     // Output: Read-response (OKAY, DECERR, SLVERR);
    wire        ashi_ridle;     // Output: 1 = Read state machine is idle
    //===============================================================================================


    // The state of our two state machines
    reg[2:0] slv_read_state, slv_write_state;

    // The state machines are idle when they're in state 0 when their "start" signals are low
    assign ashi_widle = (ashi_write == 0) && (slv_write_state == 0);
    assign ashi_ridle = (ashi_read  == 0) && (slv_read_state  == 0);
    
    // These are the valid values for ashi_rresp and ashi_wresp
    localparam OKAY   = 0;
    localparam SLVERR = 2;
    localparam DECERR = 3;

    // Our slave's register set will occupy 9 bits of address space
    localparam ADDR_MASK = 9'h1FF;
    
    // Packet types
    localparam PKT_TYPE_READ  = 1;
    localparam PKT_TYPE_WRITE = 2;

    // The fields in a packet
    localparam PF_TYPE = 0;  // Packet type
    localparam PF_ADRL = 1;  // Low word of address
    localparam PF_ADRH = 2;  // High word of address
    localparam PF_DATA = 3;  // Read or write data
    localparam PF_RESP = 4;  // AXI_RRESP or AXI_BRESP

    // These fields get filled in when a response message is received
    reg[31:0] axi_rdata;
    reg[ 1:0] axi_rresp, axi_wresp;

    // Messages that are sent out the stream to request an AXI read or an AXI write
    reg[AXIS_DATA_WIDTH-1:0] read_req_msg, write_req_msg;

    // The request to send a read or write packet will be signaled by one of these changing
    reg[1:0] send_write_req, send_read_req;

    // The notification of a received read or write response is signaled by one of these changing
    reg[1:0] rcvd_write_rsp, rcvd_read_rsp;

    // We're going to store a 64-bit address for each vector we support
    reg[63:0] vector_reg[0:VECTOR_COUNT-1];

    // There will be a '1' in each bit for which a vector has been defined at runtime
    reg[VECTOR_COUNT-1:0] valid_vector_flags;

    // These are the address vectors that will be used for an remote AXI read or write
    wire[63:0] vector[0:VECTOR_COUNT-1];
    assign vector[00] = valid_vector_flags[00] ? vector_reg[00] : VECTOR_00;
    assign vector[01] = valid_vector_flags[01] ? vector_reg[01] : VECTOR_01;
    assign vector[02] = valid_vector_flags[02] ? vector_reg[02] : VECTOR_02;
    assign vector[03] = valid_vector_flags[03] ? vector_reg[03] : VECTOR_03;
    assign vector[04] = valid_vector_flags[04] ? vector_reg[04] : VECTOR_04;
    assign vector[05] = valid_vector_flags[05] ? vector_reg[05] : VECTOR_05;
    assign vector[06] = valid_vector_flags[06] ? vector_reg[06] : VECTOR_06;
    assign vector[07] = valid_vector_flags[07] ? vector_reg[07] : VECTOR_07;
    assign vector[08] = valid_vector_flags[08] ? vector_reg[08] : VECTOR_08;
    assign vector[09] = valid_vector_flags[09] ? vector_reg[09] : VECTOR_09;
    assign vector[10] = valid_vector_flags[10] ? vector_reg[10] : VECTOR_10;
    assign vector[11] = valid_vector_flags[11] ? vector_reg[11] : VECTOR_11;
    assign vector[12] = valid_vector_flags[12] ? vector_reg[12] : VECTOR_12;
    assign vector[13] = valid_vector_flags[13] ? vector_reg[13] : VECTOR_13;
    assign vector[14] = valid_vector_flags[14] ? vector_reg[14] : VECTOR_14;
    assign vector[15] = valid_vector_flags[15] ? vector_reg[15] : VECTOR_15;


    //===============================================================================================
    // State machine that transmits read or write requests across the stream interface
    //===============================================================================================
    reg      trsm_state;
    reg[1:0] prior_send_read_req;
    reg[1:0] prior_send_write_req;
    //===============================================================================================
    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            trsm_state           <= 0;
            prior_send_write_req <= 0;
            prior_send_read_req  <= 0;
            AXIS_TX_TVALID       <= 0;

        end else case (trsm_state)
        
                // If we've been asked to send a write-request, do so
            0:  if (send_write_req != prior_send_write_req) begin
                    prior_send_write_req <= send_write_req;
                    AXIS_TX_TDATA        <= write_req_msg;
                    AXIS_TX_TLAST        <= 1;
                    AXIS_TX_TVALID       <= 1;    
                    trsm_state           <= 1;
                end

                // Otherwise, if we've been asked to send a read-request, do so
                else if (send_read_req != prior_send_read_req) begin
                    prior_send_read_req  <= send_read_req;
                    AXIS_TX_TDATA        <= read_req_msg;
                    AXIS_TX_TLAST        <= 1;
                    AXIS_TX_TVALID       <= 1;    
                    trsm_state           <= 1;
                end
                
                // Wait for the SAXI handshake, then go back to idle
            1:  if (AXIS_TX_TVALID & AXIS_TX_TREADY) begin
                    AXIS_TX_TVALID <= 0;
                    trsm_state     <= 0;
                end

        endcase
    end
    //===============================================================================================


    //===============================================================================================
    // State machine that receives responses across the stream interface
    //===============================================================================================
    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            rcvd_read_rsp  <= 0;
            rcvd_write_rsp <= 0;
            AXIS_RX_TREADY <= 0;

        end else begin
        
            AXIS_RX_TREADY <= 1;
    
            if (AXIS_RX_TREADY && AXIS_RX_TVALID) begin
                            
                if (AXIS_RX_TDATA[PF_TYPE*32 +:32] == PKT_TYPE_READ) begin
                    axi_rdata     <= AXIS_RX_TDATA[PF_DATA*32 +:32];
                    axi_rresp     <= AXIS_RX_TDATA[PF_RESP*32 +:32];
                    rcvd_read_rsp <= rcvd_read_rsp + 1;
                end

                        
                else if (AXIS_RX_TDATA[PF_TYPE*32 +:32] == PKT_TYPE_WRITE) begin
                    axi_wresp      <= AXIS_RX_TDATA[PF_RESP*32 +:32];
                    rcvd_write_rsp <= rcvd_write_rsp + 1;
                end
            end
        end
    end
    //===============================================================================================


    //===============================================================================================
    // State machine that handles write requests to the slave
    //===============================================================================================
    
    // This is the index of the 32-bit register being written to
    wire[7:0] reg_windex = (ashi_waddr & ADDR_MASK) >> 2;

    // This is the index of active address vector
    reg[7:0] vector_windex;
    
    // Used for keeping track of when a write-response arrives
    reg[1:0] prior_write_rsp;

    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            slv_write_state    <= 0;
            send_write_req     <= 0;
            valid_vector_flags <= 0;

        // If we're not in reset, and a write-request has occured...        
        end else case (slv_write_state)


            //-------------------------------------------------------------------------
            // Here we are waiting for the AXI4 slave module to tell that we
            // need to satisfy an AXI write-request
            //-------------------------------------------------------------------------
            0:  if (ashi_write) begin
                    
                    // Assume for the moment that the result will be OKAY
                    ashi_wresp <= OKAY;              

                    // The index of the address vector we're dealing with is:
                    //   If we're writing to an address vector, it's the register index / 2
                    //   If we're writing to a data register, it's the index of the data register
                    if (reg_windex < 64)
                        vector_windex <= reg_windex >> 1;
                    else
                        vector_windex <= reg_windex - 64;

                    // And go to the next step
                    slv_write_state <= 1;

                end

            //-------------------------------------------------------------------------
            // We have the register index in 'reg_windex' and the vector index in
            // 'vector_windex'.  The user could be doing one of three things:
            //        (1) Writing to a valid address-vector register
            //        (2) Writing to a valid data register
            //        (3) Writing to some invalid address
            //-------------------------------------------------------------------------
            1:  // If we're writing to a valid vector register, make it so
                // and go back to idle mode
                if (reg_windex < VECTOR_COUNT * 2) begin
                    valid_vector_flags[vector_windex] = 1;
                    if (reg_windex & 1) 
                        vector_reg[vector_windex][31:00] <= ashi_wdata;
                    else
                        vector_reg[vector_windex][63:32] <= ashi_wdata;
                    slv_write_state <= 0;
                end
 
                // If we're writing to a valid data register, send the write-request packet
                else if (reg_windex >= 64 && reg_windex < (64 + VECTOR_COUNT)) begin
                    write_req_msg[PF_TYPE*32 +:32] <= PKT_TYPE_WRITE;
                    write_req_msg[PF_ADRL*32 +:64] <= vector[reg_windex];
                    write_req_msg[PF_DATA*32 +:32] <= ashi_wdata;
                    prior_write_rsp                <= rcvd_write_rsp;
                    send_write_req                 <= send_write_req + 1;
                    slv_write_state                <= 2;
                end 

                // All other cases return a slave-error and go back to idle mode
                else begin
                    ashi_wresp      <= SLVERR;
                    slv_write_state <= 0;
                end


                // When 'rcvd_write_rsp' changes, we've received our response
            2:  if (prior_write_rsp != rcvd_write_rsp) begin
                    ashi_wresp      <= axi_wresp;
                    slv_write_state <= 0;
                end

        endcase
    end
    //===============================================================================================



    //===============================================================================================
    // State machine that handles read requests to the slave
    //===============================================================================================
    
    // This is the index of the 32-bit register being read from
    wire[7:0] reg_rindex = (ashi_raddr & ADDR_MASK) >> 2;
    
    // This is the index of active address vector
    reg[7:0] vector_rindex;

    // Used for keeping track of when a read-response arrives
    reg[1:0] prior_read_rsp;

    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            slv_read_state <= 0;
            send_read_req  <= 0;

        // If we're not in reset, and a read-request has occured...        
        end else case (slv_read_state)


            //-------------------------------------------------------------------------
            // Here we are waiting for the AXI4 slave module to tell that we
            // need to satisfy an AXI read-request
            //-------------------------------------------------------------------------
            0:  if (ashi_read) begin
                    
                    // Assume for the moment that the result will be OKAY
                    ashi_rresp <= OKAY;              

                    // The index of the address vector we're dealing with is:
                    //   If we're writing to an address vector, it's the register index / 2
                    //   If we're writing to a data register, it's the index of the data register
                    if (reg_rindex < 64)
                        vector_rindex <= reg_rindex >> 1;
                    else
                        vector_rindex <= reg_rindex - 64;

                    // And go to the next step
                    slv_read_state <= 1;

                end

            //-------------------------------------------------------------------------
            // We have the register index in 'reg_rindex' and the vector index in
            // 'vector_rindex'.  The user could be doing one of three things:
            //        (1) Reading from a valid address-vector register
            //        (2) Reading from a valid data register
            //        (3) Reading from some invalid address
            //-------------------------------------------------------------------------
            1:  // If we're reading from a valid vector register, make it so
                // and go back to idle mode
                if (reg_rindex < VECTOR_COUNT*2) begin
                    if (reg_rindex & 1) 
                        ashi_rdata <= vector[vector_rindex][31:00];
                    else
                        ashi_rdata <= vector[vector_rindex][63:32];
                    slv_read_state <= 0;
                end

                // If we're reading from a valid data register, go do that
                else if (reg_rindex >= 64 && reg_rindex < (64 + VECTOR_COUNT)) begin
                    read_req_msg[PF_TYPE*32 +:32] <= PKT_TYPE_READ;
                    read_req_msg[PF_ADRL*32 +:64] <= vector[vector_rindex];
                    read_req_msg[PF_DATA*32 +:32] <= 0;
                    prior_read_rsp                <= rcvd_read_rsp;
                    send_read_req                 <= send_read_req + 1;
                    slv_read_state                <= 2;
                end 

                // All other cases return a slave-error and go back to idle mode
                else begin
                    ashi_rresp     <= SLVERR;
                    slv_read_state <= 0;
                end

                // When 'rcvd_read_rsp' changes, we've received our response
            2:  if (rcvd_read_rsp != prior_read_rsp) begin
                    ashi_rdata     <= axi_rdata;
                    ashi_rresp     <= axi_rresp;
                    slv_read_state <= 0;
                end
        endcase
    end
    //===============================================================================================


    //===============================================================================================
    // This connects us to an AXI4-Lite slave core
    //===============================================================================================
    axi4_lite_slave axi_slave
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (S_AXI_AWADDR),
        .AXI_AWVALID    (S_AXI_AWVALID),   
        .AXI_AWPROT     (S_AXI_AWPROT),
        .AXI_AWREADY    (S_AXI_AWREADY),
        
        // AXI W channel
        .AXI_WDATA      (S_AXI_WDATA),
        .AXI_WVALID     (S_AXI_WVALID),
        .AXI_WSTRB      (S_AXI_WSTRB),
        .AXI_WREADY     (S_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (S_AXI_BRESP),
        .AXI_BVALID     (S_AXI_BVALID),
        .AXI_BREADY     (S_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (S_AXI_ARADDR), 
        .AXI_ARVALID    (S_AXI_ARVALID),
        .AXI_ARPROT     (S_AXI_ARPROT),
        .AXI_ARREADY    (S_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (S_AXI_RDATA),
        .AXI_RVALID     (S_AXI_RVALID),
        .AXI_RRESP      (S_AXI_RRESP),
        .AXI_RREADY     (S_AXI_RREADY),

        // ASHI write-request registers
        .ASHI_WADDR     (ashi_waddr),
        .ASHI_WDATA     (ashi_wdata),
        .ASHI_WRITE     (ashi_write),
        .ASHI_WRESP     (ashi_wresp),
        .ASHI_WIDLE     (ashi_widle),

        // ASHI-read-request registers
        .ASHI_RADDR     (ashi_raddr),
        .ASHI_RDATA     (ashi_rdata),
        .ASHI_READ      (ashi_read ),
        .ASHI_RRESP     (ashi_rresp),
        .ASHI_RIDLE     (ashi_ridle)
    );
    //===============================================================================================
 

endmodule






