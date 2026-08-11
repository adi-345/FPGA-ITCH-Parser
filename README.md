# FPGA NASDAQ ITCH 5.0 Market Data Parser and Trading Engine

## Overview
This repository contains a SystemVerilog implementation of a hardware parser and basic trading engine designed for NASDAQ ITCH 5.0 market data feeds. The design accepts incoming binary market data over a 32-bit AXI4-Stream interface, handles byte alignment issues caused by variable-length messages, extracts key fields, and generates buy or sell signals when specific trading conditions are met.

The project is structured to be straightforward and easy to follow for anyone looking to learn SystemVerilog, AXI-Stream data processing, and basic digital design for high-frequency trading applications. This was also my beginner project over a three month summer, and is how I taught myself Systemverilog. I started by going through the Yedida Systemverilog guide cover to cover, and trying to complete all the excercises inside myself: https://zyedidia.github.io/notes/sv_guide.pdf. I'd highly recommend it for anyone just starting out. If you're reading this and also interested in building cool stuff in this space, email me at choksi3@illinois.edu.

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

Full Order Book Tracking: Expand message support to handle cancellation, order replacement, and depth tracking across multi-level bid/ask stacks. This repo is already underway and available on this account, although currently separate.