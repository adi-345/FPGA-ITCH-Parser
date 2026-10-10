# FPGA NASDAQ ITCH 5.0 Market Data Parser and Trading Engine

## Overview
This repository contains a SystemVerilog implementation of a hardware parser and basic trading engine designed for NASDAQ ITCH 5.0 market data feeds. The design accepts incoming binary market data over a 32-bit AXI4-Stream interface, handles byte alignment issues caused by variable-length messages, extracts key fields, and generates buy or sell signals when specific trading conditions are met.

If you're reading this and also interested in building cool stuff in this space, email me at choksi3@illinois.edu.

## Results (Vivado, post-implementation, [part number])

| Metric           | Value                          |
|------------------|--------------------------------|
| LUTs             | 716 (755 post-synthesis)       |
| Flip-flops       | 716                            |
| Clock            | 11 ns (90 MHz), timing met     |
| Worst neg. slack | +0.477 ns                      |
| Estimated power  | 0.072 W                        |

The critical path runs through the 64-bit multiply-accumulate stage in `trade_math_core.sv`.

## Verification

- `generate_vectors.py` produces spec-conformant ITCH 5.0 byte streams, both directed cases and per-field randomized messages.
- `itch_parser_tb.sv` and `trading_engine_tb.sv` are self-checking: they compare trigger count and cycle-exact trigger timing against expected values.
- Known limitation: `tready` is held high, so backpressure is not exercised.

---

## Directory Structure

```text
FPGA-ITCH-Parser/
├── .gitignore
├── sources/
│   ├── itch_pkg.sv
│   ├── itch_parser.sv
│   ├── trade_filter.sv
│   ├── trade_math_core.sv
│   ├── trade_signal_trigger.sv
│   └── trade_engine.sv
└── testbenches/
    ├── itch_parser_tb.sv
    ├── trading_engine_tb.sv
    └── generate_vectors.py
```
---
## Future Work
C++ Software Interface: Build a C++ driver using DMA / PCIe or socket communication to feed live or PCAP market data into the FPGA model from software.

10GbE Network MAC Integration: Connect the AXI-Stream slave interface directly to a 10GbE MAC / PHY core (such as Xilinx 10GBASE-R) to process incoming Ethernet frames directly on physical FPGA hardware.

Full Order Book Tracking: Expand message support to handle cancellation, order replacement, and depth tracking across multi-level bid/ask stacks. 
