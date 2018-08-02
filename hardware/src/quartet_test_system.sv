/*
 * Test system for a quartet.
 */

// Derived parameters are necessary in this namespace because of the TIA_QUARTET macro used to
// pick a quartet architecture.
`ifdef ASIC_SYNTHESIS
    `include "quartet.svh"
`elsif FPGA_SYNTHESIS
    `include "quartet.svh"
`elsif SIMULATION
    `include "../quartet/quartet.svh"
`else
    `include "quartet.svh"
`endif

module quartet_test_system
    (input logic S_AXI_ACLK, // Positive-edge triggered.
     input logic S_AXI_ARESETN, // Active low.
     input logic [AXI4_LITE_ADDRESS_WIDTH - 1:0] S_AXI_AWADDR,
     input logic [2:0] S_AXI_AWPROT,
     input logic S_AXI_AWVALID,
     output logic S_AXI_AWREADY,
     input logic [AXI4_LITE_DATA_WIDTH - 1:0] S_AXI_WDATA,
     input logic [AXI4_LITE_DATA_WIDTH / 8 - 1:0] S_AXI_WSTRB,
     input logic S_AXI_WVALID,
     output logic S_AXI_WREADY,
     output logic [1:0] S_AXI_BRESP,
     output logic S_AXI_BVALID,
     input logic S_AXI_BREADY,
     input logic [AXI4_LITE_ADDRESS_WIDTH - 1:0] S_AXI_ARADDR,
     input logic [2:0] S_AXI_ARPROT,
     input logic S_AXI_ARVALID,
     output logic S_AXI_ARREADY,
     output logic [AXI4_LITE_DATA_WIDTH - 1:0] S_AXI_RDATA,
     output logic [1:0] S_AXI_RRESP,
     output logic S_AXI_RVALID,
     input logic S_AXI_RREADY);

    // --- AXI4-Lite to Generic MMIO Bridge ---

    // Top-level MMIO interface.
    mmio_if host_interface();

    // Protocol bridge.
    axi4_lite_to_mmio_bridge altmb(.S_AXI_ACLK(S_AXI_ACLK),
                                   .S_AXI_ARESETN(S_AXI_ARESETN),
                                   .S_AXI_AWADDR(S_AXI_AWADDR),
                                   .S_AXI_AWPROT(S_AXI_AWPROT),
                                   .S_AXI_AWVALID(S_AXI_AWVALID),
                                   .S_AXI_AWREADY(S_AXI_AWREADY),
                                   .S_AXI_WDATA(S_AXI_WDATA),
                                   .S_AXI_WSTRB(S_AXI_WSTRB),
                                   .S_AXI_WVALID(S_AXI_WVALID),
                                   .S_AXI_WREADY(S_AXI_WREADY),
                                   .S_AXI_BRESP(S_AXI_BRESP),
                                   .S_AXI_BVALID(S_AXI_BVALID),
                                   .S_AXI_BREADY(S_AXI_BREADY),
                                   .S_AXI_ARADDR(S_AXI_ARADDR),
                                   .S_AXI_ARPROT(S_AXI_ARPROT),
                                   .S_AXI_ARVALID(S_AXI_ARVALID),
                                   .S_AXI_ARREADY(S_AXI_ARREADY),
                                   .S_AXI_RDATA(S_AXI_RDATA),
                                   .S_AXI_RRESP(S_AXI_RRESP),
                                   .S_AXI_RVALID(S_AXI_RVALID),
                                   .S_AXI_RREADY(S_AXI_RREADY),
                                   .host_interface(host_interface));

    // --- System Logic ---

    logic clock, reset;
    assign clock = S_AXI_ACLK;
    assign reset = ~S_AXI_ARESETN;

    // --- System Memory Mapper ---

    // Mapped interfaces.
    mmio_if control_interface();
    mmio_if quartet_interface();
    mmio_if memory_interface();

    // Control and signal wires.
    logic system_reset, system_enable, system_execute, system_halted;

    // Buffered host MMIO interface.
    mmio_if buffered_host_interface();

    // Wiring the buffered host MMIO interface.
    mmio_buffer himb(.clock(clock),
                     .reset(reset),
                     .host_interface(host_interface),
                     .device_interface(buffered_host_interface));

    // Spitting the memory domains up by function.
    quartet_test_system_mapper qtsm(.host_interface(buffered_host_interface),
                                    .control_interface(control_interface),
                                    .quartet_interface(quartet_interface),
                                    .memory_interface(memory_interface));

    // Buffered system MMIO interfaces.
    mmio_if buffered_control_interface();
    mmio_if buffered_quartet_interface();
    mmio_if buffered_memory_interface();

    // Wiring the buffered system MMIO interfaces.
    mmio_buffer cimb(.clock(clock),
                     .reset(reset),
                     .host_interface(control_interface),
                     .device_interface(buffered_control_interface));
    mmio_buffer qimb(.clock(clock),
                     .reset(reset),
                     .host_interface(quartet_interface),
                     .device_interface(buffered_quartet_interface));
    mmio_buffer mimb(.clock(clock),
                     .reset(reset),
                     .host_interface(memory_interface),
                     .device_interface(buffered_memory_interface));

    // --- System Control Registers ---

    // System control registers.
    system_control_registers scr(.clock(clock),
                                 .reset(reset),
                                 .host_interface(buffered_control_interface),
                                 .system_reset(system_reset),
                                 .system_enable(system_enable),
                                 .system_execute(system_execute),
                                 .system_halted(system_halted));

    // --- Quartet ---

    // Quartet connections.
    logic quartet_halted, quartet_channels_quiescent, quartet_routers_quiescent, memory_quiescent;
    interconnect_link_if north_input_interconnect_links[1:0]();
    interconnect_link_if east_input_interconnect_links[1:0]();
    interconnect_link_if south_input_interconnect_links[1:0]();
    interconnect_link_if west_input_interconnect_links[1:0]();
    interconnect_link_if north_output_interconnect_links[1:0]();
    interconnect_link_if east_output_interconnect_links[1:0]();
    interconnect_link_if south_output_interconnect_links[1:0]();
    interconnect_link_if west_output_interconnect_links[1:0]();
    link_if north_input_links[1:0]();
    link_if east_input_links[1:0]();
    link_if south_input_links[1:0]();
    link_if west_input_links[1:0]();
    link_if north_output_links[1:0]();
    link_if east_output_links[1:0]();
    link_if south_output_links[1:0]();
    link_if west_output_links[1:0]();

    // Converters.
    genvar i;
    generate
        for (i = 0; i < 2; i++) begin: lc
            interconnect_link_splitter nils
                (.input_link(north_input_links[i]),
                 .output_interconnect_link(north_input_interconnect_links[i]));
            interconnect_link_splitter eils
                (.input_link(east_input_links[i]),
                 .output_interconnect_link(east_input_interconnect_links[i]));
            interconnect_link_splitter sils
                (.input_link(south_input_links[i]),
                 .output_interconnect_link(south_input_interconnect_links[i]));
            interconnect_link_splitter wils
                (.input_link(west_input_links[i]),
                 .output_interconnect_link(west_input_interconnect_links[i]));
            interconnect_link_combiner nilc
                (.input_interconnect_link(north_output_interconnect_links[i]),
                 .output_link(north_output_links[i]));
            interconnect_link_combiner eilc
                (.input_interconnect_link(east_output_interconnect_links[i]),
                 .output_link(east_output_links[i]));
            interconnect_link_combiner silc
                (.input_interconnect_link(south_output_interconnect_links[i]),
                 .output_link(south_output_links[i]));
            interconnect_link_combiner wilc
                (.input_interconnect_link(west_output_interconnect_links[i]),
                 .output_link(west_output_links[i]));
        end
    endgenerate

    // Quartet.
    quartet quartet(.clock(clock),
                    .reset(system_reset),
                    .enable(system_enable),
                    .execute(system_execute),
                    .halted(quartet_halted),
                    .channels_quiescent(quartet_channels_quiescent),
                    .routers_quiescent(quartet_routers_quiescent),
                    .host_interface(buffered_quartet_interface),
                    .north_input_interconnect_links(north_input_interconnect_links),
                    .south_input_interconnect_links(south_input_interconnect_links),
                    .east_input_interconnect_links(east_input_interconnect_links),
                    .west_input_interconnect_links(west_input_interconnect_links),
                    .north_output_interconnect_links(north_output_interconnect_links),
                    .south_output_interconnect_links(south_output_interconnect_links),
                    .east_output_interconnect_links(east_output_interconnect_links),
                    .west_output_interconnect_links(west_output_interconnect_links));

    // Determine the system halt condition.
    // TODO: Eventually set to quartet_halted && quartet_channels_quiescent && quartet_routers_quiescent && memory_quiescent instead of relying ton the driver.
    assign system_halted = quartet_halted;

    // Clean up unused input links.
    unused_link_sender uls0(south_input_links[0]);
    unused_link_sender uls1(south_input_links[1]);
    unused_link_sender uls2(east_input_links[0]);
    unused_link_sender uls3(east_input_links[1]);
    unused_link_sender uls4(west_input_links[0]);
    unused_link_sender uls5(west_input_links[1]);

    // Clean up unused output links.
    unused_link_receiver ulr0(east_output_links[0]);
    unused_link_receiver ulr1(east_output_links[1]);
    unused_link_receiver ulr2(west_output_links[0]);
    unused_link_receiver ulr3(west_output_links[1]);

    // --- Memory ---

    // One read, one write memory.
    memory_2r_1w #(.DEPTH(TIA_NUM_DATA_MEMORY_WORDS))
        memory(.clock(clock),
               .reset(system_reset),
               .enable(1'b1), // Always on, for now.
               .host_interface(buffered_memory_interface),
               .read_index_0_input_link(north_output_links[0]),
               .read_data_0_output_link(north_input_links[0]),
               .read_index_1_input_link(north_output_links[1]),
               .read_data_1_output_link(north_input_links[1]),
               .write_index_input_link(south_output_links[0]),
               .write_data_input_link(south_output_links[1]),
               .quiescent(memory_quiescent));
endmodule
