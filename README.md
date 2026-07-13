# FPGA-ITCH-Parser

# AXI4-Stream NASDAQ ITCH 5.0 Parser 

A hardware implementation of a low-latency NASDAQ ITCH 5.0 market data parser designed in SystemVerilog. The module ingests a unaligned binary stream over a 32-bit AXI4-Stream slave interface and decodes message blocks into normalized structural layouts (`normalized_msg_t`).

## Repository Structure

* `itch_parser.sv`: Core structural RTL containing the barrel shifter aligner and the tracking FSM logic.
* `itch_parser_tb.sv`: Self-contained Vivado-compatible simulation wrapper using safe non-blocking (`<=`) driver tasks to feed sequential unaligned back-to-back testing frames.

## How to Reproduce

1. Clone this repository.
2. Create a new project in **AMD Vivado** targeting any 7-series or UltraScale FPGA device.
3. Add both source files to the simulation set.
4. Launch **Behavioral Simulation (XSim)** and run for `1000ns`.

---
