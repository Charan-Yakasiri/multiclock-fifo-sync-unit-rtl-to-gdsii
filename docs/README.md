# Physical Design Report

## Multi-Clock FIFO Synchronization Unit ASIC Implementation

---

# Abstract

This project presents the complete RTL-to-GDSII implementation of a multi-clock FIFO-based synchronization subsystem using industry-standard ASIC design tools. The objective was to gain practical exposure to modern digital ASIC backend methodologies including synthesis, floorplanning, power planning, placement, clock tree preparation, routing, timing analysis, physical verification, and GDSII generation.

The design was implemented using Cadence Genus and Innovus on the GPDK090 technology node. The project demonstrates the transformation of a register-transfer level (RTL) hardware description into a manufacturable physical layout database while evaluating timing, area, routing, and design-rule constraints throughout the implementation flow.

---

# 1. Introduction

Modern digital integrated circuits require a structured implementation methodology to transform behavioral hardware descriptions into physical silicon layouts.

The RTL-to-GDSII flow consists of several stages:

1. RTL Design
2. Logic Synthesis
3. Floorplanning
4. Power Planning
5. Placement
6. Clock Tree Synthesis
7. Routing
8. Static Timing Analysis
9. Physical Verification
10. GDSII Generation

This project explores each of these stages using a multi-clock synchronization subsystem containing FIFO-based clock-domain crossing structures.

---

# 2. Design Objective

The primary goal of this project was to implement a multi-clock synchronization subsystem and gain practical understanding of:

* ASIC backend design flow
* Clock domain crossing architectures
* FIFO-based synchronization techniques
* Physical design constraints
* Timing closure methodology
* Design-rule verification
* Layout generation

The project emphasizes implementation methodology rather than functional optimization.

---

# 3. Design Architecture

The design consists of asynchronous and synchronous FIFO structures operating across independent clock domains.

## High-Level Architecture

```text
                  cam1_pclk
                      │
                      ▼
           +-------------------+
           |    Async FIFO     |
           +-------------------+
                      │
                      ▼
           +-------------------+
           | Synchronization   |
           |       Logic       |
           +-------------------+
                      │
                      ▼
           +-------------------+
           |    Sync FIFO      |
           +-------------------+
                      │
                      ▼
                    sys_clk
```

The asynchronous FIFO enables safe transfer of information between independent clock domains, while synchronization logic coordinates data movement and buffering.

---

# 4. RTL Design

The RTL implementation consists of the following modules:

## async_fifo.v

Provides:

* Dual-clock FIFO operation
* Gray-coded pointer synchronization
* Clock-domain crossing support
* Independent read/write clocks

## sync_fifo.v

Provides:

* Single-clock FIFO buffering
* Temporary data storage
* Controlled data transfer

## sync_unit.v

Top-level integration module containing:

* FIFO control logic
* Synchronization logic
* Multi-clock interfaces
* Data path management

---

# 5. Design Constraints

Timing constraints were specified using Synopsys Design Constraints (SDC).

Primary clocks include:

| Clock     | Period    |
| --------- | --------- |
| sys_clk   | 10 ns     |
| cam1_pclk | 13.333 ns |
| cam2_pclk | 10 ns     |

The design therefore contains multiple asynchronous timing domains requiring CDC-aware implementation.

---

# 6. Logic Synthesis

## Tool

Cadence Genus

## Objectives

* RTL elaboration
* Technology mapping
* Logic optimization
* Netlist generation

The synthesis stage transformed behavioral Verilog into a gate-level netlist targeting the GPDK090 standard-cell library.

Generated outputs included:

* Gate-level netlist
* Area report
* Timing report
* Power report

---

# 7. Floorplanning

## Objectives

* Define core dimensions
* Determine utilization targets
* Allocate placement area
* Establish routing resources

Floorplanning represents the first physical stage of implementation.

The floorplan establishes:

* Core boundary
* Standard-cell regions
* Routing resources
* Power distribution regions

### Floorplan Screenshot

Insert:

```text
docs/images/floorplan.png
```

---

# 8. Power Planning

## Objectives

* Power delivery network creation
* Power ring generation
* Power stripe insertion
* VDD/VSS distribution

Power planning ensures reliable voltage delivery across the entire design.

### Implemented Structures

* Core power rings
* Horizontal power stripes
* Vertical power stripes
* Standard-cell power connections

### Power Plan Screenshot

Insert:

```text
docs/images/powerplan.png
```

---

# 9. Placement

## Objectives

* Standard-cell placement
* Congestion reduction
* Timing-driven optimization
* Area utilization control

### Placement Statistics

| Metric             | Value     |
| ------------------ | --------- |
| Total Instances    | 1,298,235 |
| Fixed Instances    | 521,304   |
| Unplaced Instances | 0         |
| Placement Density  | 62.90%    |

Placement completed successfully with all instances legally placed.

### Placement Screenshot

Insert:

```text
docs/images/placement.png
```

---

# 10. Pre-CTS Timing Analysis

Pre-Clock Tree Synthesis timing analysis was performed after placement.

### Results

| Metric          | Value        |
| --------------- | ------------ |
| WNS             | -46.370 ns   |
| TNS             | -4.74e+06 ns |
| Violating Paths | 432,000+     |

The large number of timing violations reflects the complexity of the multi-clock architecture and the absence of a synthesized clock distribution network at this stage.

---

# 11. Clock Tree Synthesis Exploration

## Tool

Cadence Innovus CCOpt

The design entered the CTS preparation stage where:

* Clock trees were extracted
* Clock sinks were identified
* Skew groups were generated
* Clock balancing targets were computed

### Clock Statistics

| Clock     | Sinks   |
| --------- | ------- |
| sys_clk   | 332,016 |
| cam1_pclk | 110,643 |

Total clock sinks:

```text
442,659
```

CTS execution encountered technology constraint limitations related to maximum transition targets. Nevertheless, clock extraction and clock-tree analysis were successfully explored as part of the learning process.

---

# 12. Routing

Routing was performed after placement and clock-tree preparation.

## Objectives

* Global routing
* Detailed routing
* Connectivity completion
* Congestion minimization

### Routing Statistics

| Metric              | Value     |
| ------------------- | --------- |
| Routed Nets         | 777,001   |
| Horizontal Overflow | 0.00%     |
| Vertical Overflow   | 0.00%     |
| Total Wire Length   | 42.29 mm  |
| Total Vias          | 9,966,779 |

### Metal Usage

| Layer  | Wire Length |
| ------ | ----------- |
| Metal2 | 14.05 mm    |
| Metal3 | 18.02 mm    |
| Metal4 | 6.70 mm     |
| Metal5 | 3.26 mm     |

### Routing Screenshot

Insert:

```text
docs/images/routing.png
```

---

# 13. Post-Route Static Timing Analysis

Post-route STA was performed using extracted parasitic information.

Generated reports include:

* Setup timing reports
* Hold timing reports
* Path analysis reports
* Constraint reports

Outputs are available under:

```text
postRouteReports/
```

---

# 14. Physical Verification

## DRC Verification

Design Rule Checking was performed using Innovus verification utilities.

### Categories Checked

* Metal spacing
* Shorts
* Via spacing
* Cut spacing
* Geometry constraints

Generated output:

```text
final_drc.rpt
```

Additional geometry verification reports:

```text
sync_unit.geom.rpt
sync_unit.drc.rpt
```

---

# 15. GDSII Generation

The final layout database was exported as a GDSII file.

Generated output:

```text
sync_unit.gds
```

The GDSII file represents the final physical implementation database used for downstream manufacturing and signoff workflows.

---

# 16. Key Learning Outcomes

This project provided practical exposure to:

* RTL-to-GDSII implementation
* ASIC backend methodologies
* Physical design constraints
* Power planning strategies
* Standard-cell placement
* Routing algorithms
* Timing analysis workflows
* Physical verification techniques
* Cadence Genus
* Cadence Innovus

---

# 17. Conclusion

This project successfully explored the complete ASIC implementation methodology from RTL design through physical layout generation. The design progressed through synthesis, floorplanning, power planning, placement, timing analysis, routing, physical verification, and GDSII stream-out.

The project served as a practical introduction to industrial ASIC backend workflows and provided hands-on experience with modern physical design tools used in semiconductor development.

