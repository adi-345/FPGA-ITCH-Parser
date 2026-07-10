# FPGA-ITCH-Parser

# AXI4-Stream NASDAQ ITCH 5.0 Parser — Alignment Bug Demo

A hardware implementation of a low-latency NASDAQ ITCH 5.0 market data parser designed in SystemVerilog. The module ingests a unaligned binary stream over a 32-bit AXI4-Stream slave interface and decodes message blocks into normalized structural layouts (`normalized_msg_t`).

## The Problem (Framing & Lookahead Stall)

The architecture splits parsing into two layers: an explicit 4-byte barrel shifter/aligner (`aligned_data`) and an FSM lookahead/accumulation block. 

* **What Works:** Perfectly aligned streams or packets landing on an exact 4-byte word layer boundary (Offset 0) resolve cleanly. The testbench successfully runs through **System Event ('S')** and **Stock Directory ('R')** packets without issue.
* **Where It Fails:** When moving between contiguous packets with an unaligned offset shift—specifically from **Stock Directory ('R')** to **Add Order ('A')**, which leaves a **3-byte fractional remainder**—the extraction window experiences corruption. 

### Simulation Trace Symptom
During the terminal cycle of Packet 'A', the state machine mistakenly evaluates a remaining payload byte (`78`) as a lookahead header type instead of dropping safely into the subsequent **Order Execute ('E')** message context. This errors out the state machine routing, skews the alignment, and prevents `m_axis_tvalid` from asserting on the final packet.
