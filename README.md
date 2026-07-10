# FPGA-ITCH-Parser

# AXI4-Stream NASDAQ ITCH 5.0 Parser — Alignment Bug Demo

A hardware implementation of a low-latency NASDAQ ITCH 5.0 market data parser designed in SystemVerilog. The module ingests a unaligned binary stream over a 32-bit AXI4-Stream slave interface and decodes message blocks into normalized structural layouts (`normalized_msg_t`).

## The Problem (Framing & Lookahead Stall)

The architecture splits parsing into two layers: an explicit 4-byte barrel shifter/aligner (`aligned_data`) and an FSM lookahead/accumulation block. 

* **What Works:** Perfectly aligned streams or packets landing on an exact 4-byte word layer boundary (Offset 0) resolve cleanly. The testbench successfully runs through **System Event ('S')** and **Stock Directory ('R')** packets without issue.
* **Where It Fails:** When moving between contiguous packets with an unaligned offset shift—specifically from **Stock Directory ('R')** to **Add Order ('A')**, which leaves a **3-byte fractional remainder**—the extraction window experiences corruption. 

### Simulation Trace Symptom
During the terminal cycle of Packet 'A', the state machine mistakenly evaluates a remaining payload byte (`78`) as a lookahead header type instead of dropping safely into the subsequent **Order Execute ('E')** message context. This errors out the state machine routing, skews the alignment, and prevents `m_axis_tvalid` from asserting on the final packet.

==================================================
TIME: 95000 ps | PARSER OUTPUT CAPTURED!
Message Type: S
TIME: 195000 ps | PARSER OUTPUT CAPTURED!
Message Type: R
TIME: 285000 ps | PARSER OUTPUT CAPTURED!
Message Type: A
Ref Number:   1311768467284833366
Buy/Sell:     S
Shares:       305419896
Price:        305419896  <-- [BUG]: Overlapping/corrupted field indices
Simulation drops or freezes on Packet E

---

## Repository Structure

* `itch_parser.sv`: Core structural RTL containing the barrel shifter aligner and the tracking FSM logic.
* `itch_parser_tb.sv`: Self-contained Vivado-compatible simulation wrapper using safe non-blocking (`<=`) driver tasks to feed sequential unaligned back-to-back testing frames.

## How to Reproduce

1. Clone this repository.
2. Create a new project in **AMD Vivado** targeting any 7-series or UltraScale FPGA device.
3. Add both source files to the simulation set.
4. Launch **Behavioral Simulation (XSim)** and run for `1000ns`.
5. Observe the state transition variables, `aligned_data` slices, and tracking registers on the wave viewer right as simulation time crosses `280 ns`.

---
