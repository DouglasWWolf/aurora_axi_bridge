`timescale 1ns / 1ps
//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 08-Sep-22  DWW  1000  Initial creation
//===================================================================================================


`define M_AXI_ADDR_WIDTH 64
`define M_AXI_DATA_WIDTH 32
`define M_AXI_DATA_BYTES (`M_AXI_DATA_WIDTH/8)

`define AXIS_DATA_WIDTH 256

module aximm_over_stream_server
(
    input clk, resetn,

    //========================  AXI Stream interface for receiving requests  ========================
    input [`AXIS_DATA_WIDTH-1:0] AXIS_RX_TDATA,
    input                        AXIS_RX_TVALID,
    input                        AXIS_RX_TLAST,
    output reg                   AXIS_RX_TREADY,
    //===============================================================================================


    //========================  AXI Stream interface for sending responses  =========================
    output reg [`AXIS_DATA_WIDTH-1:0] AXIS_TX_TDATA,
    output reg                        AXIS_TX_TVALID,
    output reg                        AXIS_TX_TLAST,
    input                             AXIS_TX_TREADY,
    //===============================================================================================



    //============================  An AXI-Lite Master Interface  ===================================

    // "Specify write address"        -- Master --    -- Slave --
    output[`M_AXI_ADDR_WIDTH-1:0]     M_AXI_AWADDR,   
    output                            M_AXI_AWVALID,  
    output[2:0]                       M_AXI_AWPROT,
    input                                             M_AXI_AWREADY,

    // "Write Data"                   -- Master --    -- Slave --
    output[`M_AXI_DATA_WIDTH-1:0]     M_AXI_WDATA,      
    output                            M_AXI_WVALID,
    output[`M_AXI_DATA_BYTES-1:0]     M_AXI_WSTRB,
    input                                             M_AXI_WREADY,

    // "Send Write Response"          -- Master --    -- Slave --
    input[1:0]                                        M_AXI_BRESP,
    input                                             M_AXI_BVALID,
    output                            M_AXI_BREADY,

    // "Specify read address"         -- Master --    -- Slave --
    output[`M_AXI_ADDR_WIDTH-1:0]     M_AXI_ARADDR,     
    output                            M_AXI_ARVALID,
    output[2:0]                       M_AXI_ARPROT,     
    input                                             M_AXI_ARREADY,

    // "Read data back to master"     -- Master --    -- Slave --
    input[`M_AXI_DATA_WIDTH-1:0]                       M_AXI_RDATA,
    input                                              M_AXI_RVALID,
    input[1:0]                                         M_AXI_RRESP,
    output                            M_AXI_RREADY
    //===============================================================================================
);

    // Some convenience parameters
    localparam M_AXI_ADDR_WIDTH = `M_AXI_ADDR_WIDTH;
    localparam M_AXI_DATA_WIDTH = `M_AXI_DATA_WIDTH;

    //===============================================================================================
    // We'll communicate with the AXI4-Lite Master core with these signals.
    //===============================================================================================


    // AXI Master Control Interface for AXI writes
    reg [M_AXI_ADDR_WIDTH-1:0] amci_waddr;
    reg [M_AXI_DATA_WIDTH-1:0] amci_wdata;
    reg                        amci_write;
    wire[                 1:0] amci_wresp;
    wire                       amci_widle;
   
    // AXI Master Control Interface for AXI reads
    reg [M_AXI_ADDR_WIDTH-1:0] amci_raddr;
    reg                        amci_read;
    wire[M_AXI_DATA_WIDTH-1:0] amci_rdata;
    wire[                 1:0] amci_rresp;
    wire                       amci_ridle;
    //===============================================================================================

   
    // Message types
    localparam MT_READ_REQ  = 1;
    localparam MT_WRITE_REQ = 2;
    localparam MT_READ_RSP  = 3;
    localparam MT_WRITE_RSP = 4;

    // The fields of a packet
    localparam PF_TYPE = 0;  // Packet type
    localparam PF_ADRL = 1;  // Low word of address
    localparam PF_ADRH = 2;  // High word of address
    localparam PF_DATA = 3;  // Read or write data
    localparam PF_RESP = 4;  // AXI_RRESP or AXI_BRESP

    
    //===============================================================================================
    // State machine that receives requests from the input stream and fulfills them
    //===============================================================================================
    reg[2:0] fsm_state;
    localparam FSM_INIT               = 0;
    localparam FSM_WAIT_FOR_REQUEST   = 1;
    localparam FSM_WAIT_FOR_READ      = 2;
    localparam FSM_WAIT_FOR_WRITE     = 3;
    localparam FSM_WAIT_FOR_HANDSHAKE = 4;
    //===============================================================================================

    always @(posedge clk) begin

        // When these are driven high, they should stay high for exactly 1 clock cycle
        amci_read  <= 0;
        amci_write <= 0;

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            fsm_state      <= FSM_INIT;
            AXIS_RX_TREADY <= 0;
            AXIS_TX_TVALID <= 0;

        end else case (fsm_state)
        

            FSM_INIT:
                begin
                    AXIS_RX_TREADY <= 1;
                    fsm_state      <= FSM_WAIT_FOR_REQUEST;
                end

            // Here, we're waiting for an incoming message
            FSM_WAIT_FOR_REQUEST:

                // If a messasge has arrived...
                if (AXIS_RX_TREADY && AXIS_RX_TVALID) begin
                    
                    // If it's a read-request, start an AXI read
                    if (AXIS_RX_TDATA[PF_TYPE*32 +:32] == MT_READ_REQ) begin
                        amci_raddr     <= AXIS_RX_TDATA[PF_ADRL*32 +:64];
                        amci_read      <= 1;
                        AXIS_RX_TREADY <= 0;
                        fsm_state      <= FSM_WAIT_FOR_READ;
                    end

                    // If it's a write-request, start an AXI write
                    else if (AXIS_RX_TDATA[PF_TYPE*32 +:32] == MT_WRITE_REQ) begin
                        amci_waddr     <= AXIS_RX_TDATA[PF_ADRL*32 +:64];
                        amci_wdata     <= AXIS_RX_TDATA[PF_DATA*32 +:32];
                        amci_write     <= 1;
                        AXIS_RX_TREADY <= 0;                            
                        fsm_state      <= FSM_WAIT_FOR_WRITE;
                    end
                end
 

            // Wait for the AXI-read to complete.  When it does, send a response
            FSM_WAIT_FOR_READ:
                if (amci_ridle) begin
                    AXIS_TX_TDATA[PF_TYPE*32 +:32] <= MT_READ_RSP;
                    AXIS_TX_TDATA[PF_ADRL*32 +:64] <= amci_raddr;
                    AXIS_TX_TDATA[PF_DATA*32 +:32] <= amci_rdata;
                    AXIS_TX_TDATA[PF_RESP*32 +:32] <= amci_rresp;
                    AXIS_TX_TLAST                  <= 1;
                    AXIS_TX_TVALID                 <= 1;
                    fsm_state                      <= FSM_WAIT_FOR_HANDSHAKE;                    
                end

            // Wait for the AXI-write to complete.  When it does, send a response
            FSM_WAIT_FOR_WRITE:
                if (amci_widle) begin
                    AXIS_TX_TDATA[PF_TYPE*32 +:32] <= MT_WRITE_RSP;
                    AXIS_TX_TDATA[PF_ADRL*32 +:64] <= amci_waddr;
                    AXIS_TX_TDATA[PF_DATA*32 +:32] <= amci_wdata;
                    AXIS_TX_TDATA[PF_RESP*32 +:32] <= amci_wresp;
                    AXIS_TX_TLAST                  <= 1;
                    AXIS_TX_TVALID                 <= 1;
                    fsm_state                      <= FSM_WAIT_FOR_HANDSHAKE;                    
                end

            // Wait for the other side to accept our response.  When it does, go wait for the 
            // next request to arrive.
            FSM_WAIT_FOR_HANDSHAKE:
                if (AXIS_TX_TVALID & AXIS_TX_TREADY) begin
                    AXIS_TX_TVALID <= 0;
                    AXIS_RX_TREADY <= 1;
                    fsm_state      <= FSM_WAIT_FOR_REQUEST;
                end

        endcase
    end
    //===============================================================================================





    //===============================================================================================
    // This connects us to an AXI4-Lite master core that drives the system interconnect
    //===============================================================================================
    axi4_lite_master# 
    (
        .AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(M_AXI_DATA_WIDTH)        
    )
    axi_master_to_system
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (M_AXI_AWADDR ),
        .AXI_AWVALID    (M_AXI_AWVALID),   
        .AXI_AWPROT     (M_AXI_AWPROT ),
        .AXI_AWREADY    (M_AXI_AWREADY),
        
        // AXI W channel
        .AXI_WDATA      (M_AXI_WDATA ),
        .AXI_WVALID     (M_AXI_WVALID),
        .AXI_WSTRB      (M_AXI_WSTRB ),
        .AXI_WREADY     (M_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (M_AXI_BRESP ),
        .AXI_BVALID     (M_AXI_BVALID),
        .AXI_BREADY     (M_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (M_AXI_ARADDR ), 
        .AXI_ARVALID    (M_AXI_ARVALID),
        .AXI_ARPROT     (M_AXI_ARPROT ),
        .AXI_ARREADY    (M_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (M_AXI_RDATA ),
        .AXI_RVALID     (M_AXI_RVALID),
        .AXI_RRESP      (M_AXI_RRESP ),
        .AXI_RREADY     (M_AXI_RREADY),

        // AMCI write registers
        .AMCI_WADDR     (amci_waddr),
        .AMCI_WDATA     (amci_wdata),
        .AMCI_WRITE     (amci_write),
        .AMCI_WRESP     (amci_wresp),
        .AMCI_WIDLE     (amci_widle),

        // AMCI read registers
        .AMCI_RADDR     (amci_raddr),
        .AMCI_RDATA     (amci_rdata),
        .AMCI_READ      (amci_read ),
        .AMCI_RRESP     (amci_rresp),
        .AMCI_RIDLE     (amci_ridle)
    );
    //===============================================================================================




endmodule