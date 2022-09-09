`timescale 1ns / 1ps
//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 08-Sep-22  DWW  1000  Initial creation
//===================================================================================================


`define M00_AXI_ADDR_WIDTH 32
`define M00_AXI_DATA_WIDTH 32
`define M00_AXI_DATA_BYTES (`M00_AXI_DATA_WIDTH/8)

`define M01_AXI_ADDR_WIDTH 64
`define M01_AXI_DATA_WIDTH 32
`define M01_AXI_DATA_BYTES (`M01_AXI_DATA_WIDTH/8)


module aximm_over_stream_server
(
    input clk, resetn,

    //============================  An AXI-Lite Master Interface  ===================================

    // "Specify write address"        -- Master --    -- Slave --
    output[`M00_AXI_ADDR_WIDTH-1:0]   M00_AXI_AWADDR,   
    output                            M00_AXI_AWVALID,  
    output[2:0]                       M00_AXI_AWPROT,
    input                                             M00_AXI_AWREADY,

    // "Write Data"                   -- Master --    -- Slave --
    output[`M00_AXI_DATA_WIDTH-1:0]   M00_AXI_WDATA,      
    output                            M00_AXI_WVALID,
    output[`M00_AXI_DATA_BYTES-1:0]   M00_AXI_WSTRB,
    input                                             M00_AXI_WREADY,

    // "Send Write Response"          -- Master --    -- Slave --
    input[1:0]                                        M00_AXI_BRESP,
    input                                             M00_AXI_BVALID,
    output                            M00_AXI_BREADY,

    // "Specify read address"         -- Master --    -- Slave --
    output[`M00_AXI_ADDR_WIDTH-1:0]   M00_AXI_ARADDR,     
    output                            M00_AXI_ARVALID,
    output[2:0]                       M00_AXI_ARPROT,     
    input                                             M00_AXI_ARREADY,

    // "Read data back to master"     -- Master --    -- Slave --
    input[`M00_AXI_DATA_WIDTH-1:0]                     M00_AXI_RDATA,
    input                                              M00_AXI_RVALID,
    input[1:0]                                         M00_AXI_RRESP,
    output                            M00_AXI_RREADY,
    //===============================================================================================


    //============================  An AXI-Lite Master Interface  ===================================

    // "Specify write address"        -- Master --    -- Slave --
    output[`M01_AXI_ADDR_WIDTH-1:0]   M01_AXI_AWADDR,   
    output                            M01_AXI_AWVALID,  
    output[2:0]                       M01_AXI_AWPROT,
    input                                             M01_AXI_AWREADY,

    // "Write Data"                   -- Master --    -- Slave --
    output[`M01_AXI_DATA_WIDTH-1:0]   M01_AXI_WDATA,      
    output                            M01_AXI_WVALID,
    output[`M01_AXI_DATA_BYTES-1:0]   M01_AXI_WSTRB,
    input                                             M01_AXI_WREADY,

    // "Send Write Response"          -- Master --    -- Slave --
    input[1:0]                                        M01_AXI_BRESP,
    input                                             M01_AXI_BVALID,
    output                            M01_AXI_BREADY,

    // "Specify read address"         -- Master --    -- Slave --
    output[`M01_AXI_ADDR_WIDTH-1:0]   M01_AXI_ARADDR,     
    output                            M01_AXI_ARVALID,
    output[2:0]                       M01_AXI_ARPROT,     
    input                                             M01_AXI_ARREADY,

    // "Read data back to master"     -- Master --    -- Slave --
    input[`M01_AXI_DATA_WIDTH-1:0]                     M01_AXI_RDATA,
    input                                              M01_AXI_RVALID,
    input[1:0]                                         M01_AXI_RRESP,
    output                            M01_AXI_RREADY
    //===============================================================================================
);

    // Some convenience parameters
    localparam M00_AXI_ADDR_WIDTH = `M00_AXI_ADDR_WIDTH;
    localparam M00_AXI_DATA_WIDTH = `M00_AXI_DATA_WIDTH;
    localparam M01_AXI_ADDR_WIDTH = `M01_AXI_ADDR_WIDTH;
    localparam M01_AXI_DATA_WIDTH = `M01_AXI_DATA_WIDTH;


    //===============================================================================================
    // We'll communicate with the AXI4-Lite Master core with these signals.
    //===============================================================================================

    // AXI Master Control Interface for AXI writes
    reg [M00_AXI_ADDR_WIDTH-1:0] amci00_waddr;
    reg [M00_AXI_DATA_WIDTH-1:0] amci00_wdata;
    reg                          amci00_write;
    wire[                   1:0] amci00_wresp;
    wire                         amci00_widle;
   
    // AXI Master Control Interface for AXI reads
    reg [M00_AXI_ADDR_WIDTH-1:0] amci00_raddr;
    reg                          amci00_read;
    wire[M00_AXI_DATA_WIDTH-1:0] amci00_rdata;
    wire[                   1:0] amci00_rresp;
    wire                         amci00_ridle;


    // AXI Master Control Interface for AXI writes
    reg [M01_AXI_ADDR_WIDTH-1:0] amci01_waddr;
    reg [M01_AXI_DATA_WIDTH-1:0] amci01_wdata;
    reg                          amci01_write;
    wire[                   1:0] amci01_wresp;
    wire                         amci01_widle;
   
    // AXI Master Control Interface for AXI reads
    reg [M01_AXI_ADDR_WIDTH-1:0] amci01_raddr;
    reg                          amci01_read;
    wire[M01_AXI_DATA_WIDTH-1:0] amci01_rdata;
    wire[                   1:0] amci01_rresp;
    wire                         amci01_ridle;
    //===============================================================================================


    // Changes in these signal the completion of an AXI transaction on the system
    reg[1:0] axi_write_done, axi_read_done;

    // The notification of a received read or write request is signaled by one of these changing
    reg[1:0] rcvd_write_req, rcvd_read_req;

    // These describe the length of a packet
    localparam PACKET_LENGTH_WORDS = 8;
    localparam PACKET_LENGTH_BYTES = PACKET_LENGTH_WORDS * 4;

    // Packet types
    localparam PKT_TYPE_READ  = 1;
    localparam PKT_TYPE_WRITE = 2;

    // The fields of a packet
    localparam PF_TYPE = 0;  // Packet type
    localparam PF_ADRH = 1;  // High word of address
    localparam PF_ADRL = 2;  // Low word of address
    localparam PF_DATA = 3;  // Read or write data
    localparam PF_RESP = 4;  // AXI_RRESP or AXI_BRESP

    // These two packets hold a write request and a read request
    reg[31:0] write_req_packet[0:PACKET_LENGTH_WORDS-1];
    reg[31:0]  read_req_packet[0:PACKET_LENGTH_WORDS-1];

    // This holds either a read-response or a write-response
    reg[31:0] response_packet[0:PACKET_LENGTH_WORDS-1];

    // These hold the AXI_BRESP and AXI_RRESP signals from the most recent AXI transactions
    reg[1:0] axi_write_resp, axi_read_resp;
    
    // This holds the data from the most recently completed AXI read transaction
    reg[31:0] axi_read_data;

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
    reg[1:0] prior_axi_read_done, prior_axi_write_done;
    reg[3:0] packet_index;
    reg[1:0] fsm_packet_type;
    //===============================================================================================
    always @(posedge clk) begin

        // When these signals are raised, they should strobe high for exactly 1 cycle
        amci00_write <= 0;
        amci00_read  <= 0;

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            fsm_state            <= 0;
            prior_axi_read_done  <= 0;
            prior_axi_write_done <= 0;
            rcvd_read_req        <= 0;
            rcvd_write_req       <= 0;

        end else case(fsm_state)
            
            // Read the register that tells us if a packet has arrived
            0:  if (amci00_ridle) begin
                    packet_index <= 0;
                    amci00_raddr <= ASF_RDFO;
                    amci00_read  <= 1;
                    fsm_state    <= fsm_state + 1;
                end

            //-----------------------------------------------------------
            // In this section we wait for one of three events:
            //   (1) A signal to transmit a write-response
            //   (2) A signal to transmit a read-response
            //   (3) The notification that a request packet has arrived
            //-----------------------------------------------------------

            1:  if (amci00_ridle) begin            // If we have the RDFO register...
                    if (amci00_rdata) begin        //   If it's non-zero (i.e., a packet has arrived)...
                        amci00_raddr <= ASF_RDATA; //   We're going to start reading FIFO data
                        amci00_read  <= 1;         //   Start the AXI read...
                        fsm_state    <= 20;        //   And go fetch the packet from the FIFO
                    end
                    else fsm_state <= 0;           // No packet available?  Go back to idle
                end 
                
                // Otherwise, if we've been asked to send a write response...
                else if (axi_write_done != prior_axi_write_done) begin
                    prior_axi_write_done     <= axi_write_done;
                    response_packet[PF_TYPE] <= PKT_TYPE_WRITE;
                    response_packet[PF_ADRH] <= write_req_packet[PF_ADRH];
                    response_packet[PF_ADRL] <= write_req_packet[PF_ADRL];
                    response_packet[PF_DATA] <= write_req_packet[PF_DATA];
                    response_packet[PF_RESP] <= axi_write_resp;
                    fsm_state                <= 10;
                end

                // Otherwise, if we've been asked to send a read response...
                else if (axi_read_done != prior_axi_read_done) begin
                    prior_axi_read_done      <= axi_read_done;
                    response_packet[PF_TYPE] <= PKT_TYPE_READ;
                    response_packet[PF_ADRH] <= read_req_packet[PF_ADRH];
                    response_packet[PF_ADRL] <= read_req_packet[PF_ADRL];
                    response_packet[PF_DATA] <= axi_read_data;
                    response_packet[PF_RESP] <= axi_read_resp;
                    fsm_state                <= 10;
                end



            //-------------------------------------------------------------------
            // In this section, we send a read-response or write-response packet
            //-------------------------------------------------------------------
            
                // We sit in a loop sending the packet.  When we've sent all words
                // of the packet, we tell the FIFO's TLR register how many bytes
                // to transmit 
            10: if (amci00_widle) begin
                    if (packet_index == PACKET_LENGTH_WORDS) begin
                        amci00_waddr <= ASF_TLR;
                        amci00_wdata <= PACKET_LENGTH_BYTES;
                        amci00_write <= 1;
                        fsm_state    <= fsm_state + 1;
                    end else begin
                        amci00_wdata <= response_packet[packet_index];
                        amci00_waddr <= ASF_TDATA;
                        amci00_write <= 1;
                        packet_index <= packet_index + 1;
                    end
                end 

                // Wait for that last AXI write to complete, then back to idle
            11: if (amci00_widle) fsm_state <= 0;

            //-----------------------------------------------------------------
            // In this section, we're reading in a received packet
            //-----------------------------------------------------------------

            20: if (amci00_ridle) begin
                    
                    // If this is the first index of the request-packet, save the type
                    if (packet_index == 0)
                        fsm_packet_type <= amci00_rdata;
                    
                    // Otherwise if we're fetching a read-request packet, do so.
                    else if (fsm_packet_type == PKT_TYPE_READ)
                        read_req_packet[packet_index] <= amci00_rdata;
                    
                    // Otherwise, we're fetching a write-request packet
                    else
                        write_req_packet[packet_index] <= amci00_rdata;
                    
                    // If we just fetched the last word of the packet...
                    if (packet_index == PACKET_LENGTH_WORDS - 1) begin
                        
                        // Signal that we just received either a read response or a write-response
                        if (fsm_packet_type == PKT_TYPE_READ) begin
                            prior_axi_read_done  <= axi_read_done;
                            rcvd_read_req        <= rcvd_read_req + 1;
                        end else begin
                            prior_axi_write_done <= axi_write_done;
                            rcvd_write_req       <= rcvd_write_req + 1;
                        end

                        // And go back to idle
                        fsm_state <= 0;
                    end

                    // Otherwise, just read the next word from the FIFO
                    else begin
                        packet_index <= packet_index + 1;
                        amci00_read  <= 1;
                    end
                end

        endcase
    end
    //===============================================================================================



    //===============================================================================================
    // This state machine manages AXI write transactions to the system interface
    //===============================================================================================
    reg      wsm_state;
    reg[1:0] prior_write_req;
    //===============================================================================================
    always @(posedge clk) begin

        // When these signals are raised, they should strobe high for exactly 1 cycle
        amci01_write <= 0;

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            wsm_state       <= 0;
            prior_write_req <= 0;

        // Otherwise, we're not in reset...
        end else case (wsm_state)
            
            // Wait for the signal that says we should perform an AXI write, then do so
            0:  if (rcvd_write_req != prior_write_req) begin
                    prior_write_req <= rcvd_write_req;
                    amci01_waddr    <= {write_req_packet[PF_ADRH], write_req_packet[PF_ADRL]};
                    amci01_wdata    <= write_req_packet[PF_DATA];
                    amci01_write    <= 1;
                    wsm_state       <= 1;
                end

            // Wait for the AXI write to complete
            1:  if (amci01_widle) begin
                    axi_write_resp <= amci01_wresp;
                    axi_write_done <= axi_write_done + 1;
                    wsm_state      <= 0;
                end

        endcase

    end
    //===============================================================================================






    //===============================================================================================
    // This state machine manages AXI read transactions to the system interface
    //===============================================================================================
    reg      rsm_state;
    reg[1:0] prior_read_req;
    //===============================================================================================
    always @(posedge clk) begin

        // When these signals are raised, they should strobe high for exactly 1 cycle
        amci01_read <= 0;

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            rsm_state      <= 0;
            prior_read_req <= 0;

        // Otherwise, we're not in reset...
        end else case (rsm_state)
            
            // Wait for the signal that says we should perform an AXI read, then do so
            0:  if (rcvd_read_req != prior_read_req) begin
                    prior_read_req <= rcvd_read_req;
                    amci01_raddr   <= {read_req_packet[PF_ADRH], read_req_packet[PF_ADRL]};
                    amci01_read    <= 1;
                    rsm_state      <= 1;
                end

            // Wait for the AXI read to complete
            1:  if (amci01_ridle) begin
                    axi_read_data <= amci01_rdata;
                    axi_read_resp <= amci01_rresp;
                    axi_read_done <= axi_read_done + 1;
                    rsm_state      <= 0;
                end

        endcase

    end
    //===============================================================================================







    //===============================================================================================
    // This connects us to an AXI4-Lite master core that drives the FIFO
    //===============================================================================================
    axi4_lite_master# 
    (
        .AXI_ADDR_WIDTH(M00_AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(M00_AXI_DATA_WIDTH)        
    )
    axi_master_to_fifo
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (M00_AXI_AWADDR),
        .AXI_AWVALID    (M00_AXI_AWVALID),   
        .AXI_AWPROT     (M00_AXI_AWPROT),
        .AXI_AWREADY    (M00_AXI_AWREADY),
        
        // AXI W channel
        .AXI_WDATA      (M00_AXI_WDATA),
        .AXI_WVALID     (M00_AXI_WVALID),
        .AXI_WSTRB      (M00_AXI_WSTRB),
        .AXI_WREADY     (M00_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (M00_AXI_BRESP),
        .AXI_BVALID     (M00_AXI_BVALID),
        .AXI_BREADY     (M00_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (M00_AXI_ARADDR), 
        .AXI_ARVALID    (M00_AXI_ARVALID),
        .AXI_ARPROT     (M00_AXI_ARPROT),
        .AXI_ARREADY    (M00_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (M00_AXI_RDATA),
        .AXI_RVALID     (M00_AXI_RVALID),
        .AXI_RRESP      (M00_AXI_RRESP),
        .AXI_RREADY     (M00_AXI_RREADY),

        // AMCI write registers
        .AMCI_WADDR     (amci00_waddr),
        .AMCI_WDATA     (amci00_wdata),
        .AMCI_WRITE     (amci00_write),
        .AMCI_WRESP     (amci00_wresp),
        .AMCI_WIDLE     (amci00_widle),

        // AMCI read registers
        .AMCI_RADDR     (amci00_raddr),
        .AMCI_RDATA     (amci00_rdata),
        .AMCI_READ      (amci00_read ),
        .AMCI_RRESP     (amci00_rresp),
        .AMCI_RIDLE     (amci00_ridle)
    );
    //===============================================================================================


    //===============================================================================================
    // This connects us to an AXI4-Lite master core that drives the system interconnect
    //===============================================================================================
    axi4_lite_master# 
    (
        .AXI_ADDR_WIDTH(M01_AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(M01_AXI_DATA_WIDTH)        
    )
    axi_master_to_system
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (M01_AXI_AWADDR),
        .AXI_AWVALID    (M01_AXI_AWVALID),   
        .AXI_AWPROT     (M01_AXI_AWPROT),
        .AXI_AWREADY    (M01_AXI_AWREADY),
        
        // AXI W channel
        .AXI_WDATA      (M01_AXI_WDATA),
        .AXI_WVALID     (M01_AXI_WVALID),
        .AXI_WSTRB      (M01_AXI_WSTRB),
        .AXI_WREADY     (M01_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (M01_AXI_BRESP),
        .AXI_BVALID     (M01_AXI_BVALID),
        .AXI_BREADY     (M01_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (M01_AXI_ARADDR), 
        .AXI_ARVALID    (M01_AXI_ARVALID),
        .AXI_ARPROT     (M01_AXI_ARPROT),
        .AXI_ARREADY    (M01_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (M01_AXI_RDATA),
        .AXI_RVALID     (M01_AXI_RVALID),
        .AXI_RRESP      (M01_AXI_RRESP),
        .AXI_RREADY     (M01_AXI_RREADY),

        // AMCI write registers
        .AMCI_WADDR     (amci01_waddr),
        .AMCI_WDATA     (amci01_wdata),
        .AMCI_WRITE     (amci01_write),
        .AMCI_WRESP     (amci01_wresp),
        .AMCI_WIDLE     (amci01_widle),

        // AMCI read registers
        .AMCI_RADDR     (amci01_raddr),
        .AMCI_RDATA     (amci01_rdata),
        .AMCI_READ      (amci01_read ),
        .AMCI_RRESP     (amci01_rresp),
        .AMCI_RIDLE     (amci01_ridle)
    );
    //===============================================================================================




endmodule