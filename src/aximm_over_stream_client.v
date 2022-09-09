`timescale 1ns / 1ps
//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 08-Sep-22  DWW  1000  Initial creation
//===================================================================================================

`define M_AXI_ADDR_WIDTH 32
`define M_AXI_DATA_WIDTH 32

module aximm_over_stream_client #
(
    parameter VECTOR_COUNT = 16    
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




    //============================  An AXI-Lite Master Interface  ===================================

    // "Specify write address"        -- Master --    -- Slave --
    output[`M_AXI_ADDR_WIDTH-1:0]     M_AXI_AWADDR,   
    output                            M_AXI_AWVALID,  
    output[2:0]                       M_AXI_AWPROT,
    input                                             M_AXI_AWREADY,

    // "Write Data"                   -- Master --    -- Slave --
    output[`M_AXI_DATA_WIDTH-1:0]     M_AXI_WDATA,      
    output                            M_AXI_WVALID,
    output[(`M_AXI_DATA_WIDTH/8)-1:0] M_AXI_WSTRB,
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

    // Some convenience declarations
    localparam M_AXI_ADDR_WIDTH = `M_AXI_ADDR_WIDTH;
    localparam M_AXI_DATA_WIDTH = `M_AXI_DATA_WIDTH;


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

    // These describe the length of a packet
    localparam PACKET_LENGTH_WORDS = 8;
    localparam PACKET_LENGTH_BYTES = PACKET_LENGTH_WORDS * 4;

    // Packet types
    localparam PKT_TYPE_READ  = 1;
    localparam PKT_TYPE_WRITE = 2;

    // The fields in a packet
    localparam PF_TYPE = 0;  // Packet type
    localparam PF_ADRH = 1;  // High word of address
    localparam PF_ADRL = 2;  // Low word of address
    localparam PF_DATA = 3;  // Read or write data
    localparam PF_RESP = 4;  // AXI_RRESP or AXI_BRESP

    // We're going to store a 64-bit address for each vector we support
    reg[63:0] vector[0:VECTOR_COUNT-1];

    // These two packets hold a write request and a read request
    reg[31:0] write_req_packet[0:PACKET_LENGTH_WORDS-1];
    reg[31:0] read_req_packet [0:PACKET_LENGTH_WORDS-1];

    // These two packets hold a write response and a read response
    reg[31:0] write_rsp_packet[0:PACKET_LENGTH_WORDS-1];
    reg[31:0] read_rsp_packet [0:PACKET_LENGTH_WORDS-1];

    // The request to send a read or write packet will be signaled by one of these changing
    reg[1:0] send_write_req, send_read_req;

    // The notification of a received read or write response is signaled by one of these changing
    reg[1:0] rcvd_write_rsp, rcvd_read_rsp;


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
            slv_write_state <= 0;
            send_write_req  <= 0;

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
                    if (reg_windex & 1) 
                        vector[vector_windex][31:00] <= ashi_wdata;
                    else
                        vector[vector_windex][63:32] <= ashi_wdata;
                    slv_write_state <= 0;
                end

                // If we're writing to a valid data register, send the write-request packet
                else if (reg_windex >= 64 && reg_windex < (64 + VECTOR_COUNT)) begin
                    write_req_packet[PF_TYPE] <= PKT_TYPE_WRITE;
                    write_req_packet[PF_ADRH] <= vector[vector_windex][63:32];
                    write_req_packet[PF_ADRL] <= vector[vector_windex][31:00];
                    write_req_packet[PF_DATA] <= ashi_wdata;
                    prior_write_rsp           <= rcvd_write_rsp;
                    send_write_req            <= send_write_req + 1;
                    slv_write_state           <= 2;
                end 

                // All other cases return a slave-error and go back to idle mode
                else begin
                    ashi_wresp      <= SLVERR;
                    slv_write_state <= 0;
                end


                // When 'rcvd_write_rsp' changes, we've received our response
            2:  if (prior_write_rsp != rcvd_write_rsp) begin
                    ashi_wresp      <= write_rsp_packet[PF_RESP];
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
                    read_req_packet[PF_TYPE] <= PKT_TYPE_READ;
                    read_req_packet[PF_ADRH] <= vector[vector_rindex][63:32];
                    read_req_packet[PF_ADRL] <= vector[vector_rindex][31:00];
                    send_read_req            <= send_read_req + 1;
                    prior_read_rsp           <= rcvd_read_rsp;
                    slv_read_state           <= 2;
                end 

                // All other cases return a slave-error and go back to idle mode
                else begin
                    ashi_rresp     <= SLVERR;
                    slv_read_state <= 0;
                end

                // When 'rcvd_read_rsp' changes, we've received our response
            2:  if (rcvd_read_rsp != prior_read_rsp) begin
                    ashi_rdata     <= read_rsp_packet[PF_DATA];
                    ashi_rresp     <= read_rsp_packet[PF_RESP];
                    slv_read_state <= 0;
                end
        endcase
    end
    //===============================================================================================


    // Register names for the AXI-Stream FIFO
    localparam ASF_BASE  = 0;
    localparam ASF_ISR   = ASF_BASE + 8'h00;
    localparam ASF_TDATA = ASF_BASE + 8'h10;
    localparam ASF_TLR   = ASF_BASE + 8'h14;
    localparam ASF_RDFO  = ASF_BASE + 8'h1C;
    localparam ASF_RDATA = ASF_BASE + 8'h20;


    //===============================================================================================
    // This state machine manages the AXI-Stream FIFOs
    //===============================================================================================
    reg[7:0] fsm_state;
    reg[1:0] prior_read_req, prior_write_req;
    reg[3:0] packet_index;
    reg[1:0] fsm_packet_type;
    //===============================================================================================
    always @(posedge clk) begin

        // When these signals are raised, they should strobe high for exactly 1 cycle
        amci_write <= 0;
        amci_read  <= 0;

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            fsm_state       <= 0;
            prior_read_req  <= 0;
            prior_write_req <= 0;
            rcvd_read_rsp   <= 0;
            rcvd_write_rsp  <= 0;

        end else case(fsm_state)
            
            // Read the register that tells us if a packet has arrived
            0:  if (amci_ridle) begin
                    packet_index <= 0;
                    amci_raddr   <= ASF_RDFO;
                    amci_read    <= 1;
                    fsm_state    <= fsm_state + 1;
                end

            //-------------------------------------------------
            // In this section we wait for one of three events:
            //   (1) A signal to transmit a write-request
            //   (2) A signal to transmit a read-request
            //   (3) The notification that a packet has arrived
            //-------------------------------------------------

            1:  if (amci_ridle) begin             // If we have the RDFO register...
                    if (amci_rdata) begin         //   If it's non-zero (i.e., a packet has arrived)...
                        amci_raddr <= ASF_RDATA;  //   We're going to start reading FIFO data
                        amci_read  <= 1;          //   Start the AXI read...
                        fsm_state  <= 20;         //   And go fetch the packet from the FIFO
                    end
                    else fsm_state <= 0;          // No packet available?  Go back to idle
                end 
                
                // Otherwise, if we've been asked to send a write request...
                else if (send_write_req != prior_write_req) begin
                    prior_write_req <= send_write_req;
                    fsm_packet_type <= PKT_TYPE_WRITE;
                    fsm_state       <= 10;
                end

                // Otherwise, if we've been asked to send a read request...
                else if (send_read_req != prior_read_req) begin
                    prior_read_req  <= send_read_req;
                    fsm_packet_type <= PKT_TYPE_READ;
                    fsm_state       <= 10;
                end

            //-----------------------------------------------------------------
            // In this section, we send a read-request or write-request packet
            //-----------------------------------------------------------------
            
                // We sit in a loop sending the packet.  When we've sent all words
                // of the packet, we tell the FIFO's TLR register how many bytes
                // to transmit 
            10: if (amci_widle) begin
                    if (packet_index == PACKET_LENGTH_WORDS) begin
                        amci_waddr   <= ASF_TLR;
                        amci_wdata   <= PACKET_LENGTH_BYTES;
                        amci_write   <= 1;
                        fsm_state    <= fsm_state + 1;
                    end else begin
                        if (fsm_packet_type == PKT_TYPE_READ)
                            amci_wdata <= read_req_packet[packet_index];
                        else
                            amci_wdata <= write_req_packet[packet_index];
                        amci_waddr   <= ASF_TDATA;
                        amci_write   <= 1;
                        packet_index <= packet_index + 1;
                    end
                end 

                // Wait for that last AXI write to complete, then back to idle
            11: if (amci_widle) fsm_state <= 0;

            //-----------------------------------------------------------------
            // In this section, we're reading in a received packet
            //-----------------------------------------------------------------

            20: if (amci_ridle) begin
                    
                    // If this is the first index of the packet, save the packet type
                    if (packet_index == 0)
                        fsm_packet_type <= amci_rdata;
                    
                    // Otherwise if we're fetching a read packet, do so.
                    else if (fsm_packet_type == PKT_TYPE_READ)
                        read_rsp_packet[packet_index] <= amci_rdata;
                    
                    // Otherwise, we're fetching a write packet
                    else
                        write_rsp_packet[packet_index] <= amci_rdata;
                    
                    // If we just fetched the last word of the packet...
                    if (packet_index == PACKET_LENGTH_WORDS - 1) begin
                        
                        // Signal that we just received either a read response or a write-response
                        if (fsm_packet_type == PKT_TYPE_READ)
                            rcvd_read_rsp <= rcvd_read_rsp + 1;
                        else
                            rcvd_write_rsp <= rcvd_write_rsp + 1;

                        // And go back to idle
                        fsm_state <= 0;
                    end

                    // Otherwise, just read the next word from the FIFO
                    else begin
                        packet_index <= packet_index + 1;
                        amci_read    <= 1;
                    end
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


 
    //===============================================================================================
    // This connects us to an AXI4-Lite master core
    //===============================================================================================
    axi4_lite_master# 
    (
        .AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(M_AXI_DATA_WIDTH)        
    )
    axi_master
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (M_AXI_AWADDR),
        .AXI_AWVALID    (M_AXI_AWVALID),   
        .AXI_AWPROT     (M_AXI_AWPROT),
        .AXI_AWREADY    (M_AXI_AWREADY),
        
        // AXI W channel
        .AXI_WDATA      (M_AXI_WDATA),
        .AXI_WVALID     (M_AXI_WVALID),
        .AXI_WSTRB      (M_AXI_WSTRB),
        .AXI_WREADY     (M_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (M_AXI_BRESP),
        .AXI_BVALID     (M_AXI_BVALID),
        .AXI_BREADY     (M_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (M_AXI_ARADDR), 
        .AXI_ARVALID    (M_AXI_ARVALID),
        .AXI_ARPROT     (M_AXI_ARPROT),
        .AXI_ARREADY    (M_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (M_AXI_RDATA),
        .AXI_RVALID     (M_AXI_RVALID),
        .AXI_RRESP      (M_AXI_RRESP),
        .AXI_RREADY     (M_AXI_RREADY),

        // AMCI write-request registers
        .AMCI_WADDR     (amci_waddr),
        .AMCI_WDATA     (amci_wdata),
        .AMCI_WRITE     (amci_write),
        .AMCI_WRESP     (amci_wresp),
        .AMCI_WIDLE     (amci_widle),

        // ASHI-read-request registers
        .AMCI_RADDR     (amci_raddr),
        .AMCI_RDATA     (amci_rdata),
        .AMCI_READ      (amci_read ),
        .AMCI_RRESP     (amci_rresp),
        .AMCI_RIDLE     (amci_ridle)
    );
    //===============================================================================================



endmodule






