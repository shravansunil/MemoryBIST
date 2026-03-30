# Memory Built-In Self-Test (MBIST) on a Faulty SRAM Model

> **Overview**: This design specification outlines a parameterized, fault-injectable Static Random-Access Memory (SRAM) model alongside a corresponding Memory Built-In Self-Test (MBIST) controller. The controller utilizes the industry-standard **March C-** algorithm to autonomously test the memory arrays and identify structural defects like stuck-at faults.

---

## Architecture Overview

The design consists of two primary Verilog modules that operate in tandem to simulate memory testing in a digital system:

- **`sram_faulty`**: An 8x8 (8 locations, 8-bits wide) synchronous SRAM module with built-in mechanisms to deliberately inject hardware faults (Stuck-At-0 and Stuck-At-1) at specific addresses.
- **`mbist_controller`**: A finite state machine (FSM) based hardware test controller that systematically writes and reads test patterns to/from the SRAM to verify its integrity and flag any discrepancies.

---

## 1. Faulty SRAM Module (`sram_faulty`)

The `sram_faulty` module acts as the Device Under Test (DUT). Under normal operation, it behaves as a standard synchronous memory block. However, for validation purposes, it includes parameter-driven fault injection capabilities to simulate manufacturing defects.

### Module Parameters

The SRAM relies on Verilog parameters to configure fault injection statically at compile time.

| Parameter | Width | Default Value | Description |
| :--- | :--- | :--- | :--- |
| **FAULT_EN** | Integer | 0 | Acts as a global switch. Set to `1` to enable fault injection. |
| **FAULT_ADDR** | 3-bit | 3'd4 | Specifies the exact memory address (0-7) where the fault will manifest. |
| **STUCK_AT_0** | Integer | 0 | When set to `1`, forces reads from `FAULT_ADDR` to always return `8'h00`. |
| **STUCK_AT_1** | Integer | 0 | When set to `1`, forces reads from `FAULT_ADDR` to always return `8'hFF`. |

### Fault Injection Mechanism

Faults are evaluated during the **Read Operation**. If `FAULT_EN` is active and the read address matches `FAULT_ADDR`, the SRAM bypasses the actual memory array (`mem[addr]`) and outputs either all zeros (`8'h00`) or all ones (`8'hFF`) depending on which fault type parameter is asserted. If no fault parameters are true, it falls back to the actual stored data.

---

## 2. MBIST Controller (`mbist_controller`)

The MBIST controller is the core logic responsible for generating memory access sequences, tracking expected data, and asserting a `fail` signal if the SRAM outputs unexpected values. 

### Core Interface Signals

| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| **start** | Input | 1-bit | Triggers the MBIST testing sequence from the `IDLE` state. |
| **we** | Output | 1-bit | Write Enable control signal driving the SRAM. |
| **re** | Output | 1-bit | Read Enable control signal driving the SRAM. |
| **addr** | Output | 3-bit | Target memory address (0 to 7) being tested. |
| **done** | Output | 1-bit | Asserts high when the entire memory test algorithm concludes. |
| **fail** | Output | 1-bit | Asserts high immediately if a data mismatch is detected during a read. |

---

## Algorithm Implementation Details: March C-

The controller implements the **March C-** algorithm, a well-known test sequence boasting 100% coverage for stuck-at faults, address decoder faults, and transition faults. The algorithm runs with an $O(n)$ time complexity, specifically requiring **10 operations per memory word** (10n).

Standard March notation for March C- is: 
`{ ⇑(w0); ⇑(r0, w1); ⇑(r1, w0); ⇓(r0, w1); ⇓(r1, w0); ↕(r0) }`

### Algorithmic Steps and FSM Mapping

The MBIST controller breaks this algorithm down into distinct elements, executing them sequentially across a Finite State Machine (FSM):

- **Element 0: Initialization `⇑(w0)`**
  - **FSM State:** `UP_W0`
  - **Action:** Iterates upwards from address 0 to 7, writing `8'h00` to all memory locations to establish a known baseline.

- **Element 1: Upward Read 0, Write 1 `⇑(r0, w1)`**
  - **FSM States:** `UP_R0_READ` $
ightarrow$ `UP_R0_WAIT` $
ightarrow$ `UP_R0_CHECK` $
ightarrow$ `UP_R0_WRITE`
  - **Action:** Iterates upwards (0 to 7). For each address, it reads the data, expects `8'h00`, checks for a mismatch, and immediately overwrites the location with `8'hFF`.

- **Element 2: Upward Read 1, Write 0 `⇑(r1, w0)`**
  - **FSM States:** `UP_R1_READ` $
ightarrow$ `UP_R1_WAIT` $
ightarrow$ `UP_R1_CHECK` $
ightarrow$ `UP_R1_WRITE`
  - **Action:** Iterates upwards (0 to 7). For each address, reads the data, expects `8'hFF`, checks for a mismatch, and overwrites the location with `8'h00`.

- **Element 3: Downward Read 0, Write 1 `⇓(r0, w1)`**
  - **FSM States:** `DOWN_R0_READ` $
ightarrow$ `DOWN_R0_WAIT` $
ightarrow$ `DOWN_R0_CHECK` $
ightarrow$ `DOWN_R0_WRITE`
  - **Action:** Iterates **downwards** (7 to 0). For each address, reads the data, expects `8'h00`, checks for a mismatch, and overwrites the location with `8'hFF`. Reversing the addressing direction is critical for detecting address decoder faults and certain coupling faults.

- **Element 4: Downward Read 1, Write 0 `⇓(r1, w0)`**
  - **FSM States:** `DOWN_R1_READ` $
ightarrow$ `DOWN_R1_WAIT` $
ightarrow$ `DOWN_R1_CHECK` $
ightarrow$ `DOWN_R1_WRITE`
  - **Action:** Iterates **downwards** (7 to 0). For each address, reads the data, expects `8'hFF`, checks for a mismatch, and overwrites the location with `8'h00`.

- **Element 5: Final Read 0 `↕(r0)`**
  - **FSM States:** `UP_R0F_READ` $
ightarrow$ `UP_R0F_WAIT` $
ightarrow$ `UP_R0F_CHECK`
  - **Action:** Iterates upwards (0 to 7) one final time to ensure all addresses retain the `8'h00` state. If this passes, the algorithm transitions to the `FINISH` state, asserting the `done` signal.

### The FSM Execution Cycle

To accommodate realistic memory latencies, every Read-Check-Write operation in the algorithm executes through a micro-cycle of states:

1. **`*_READ`**: Asserts the Read Enable (`re`) signal to the SRAM.
2. **`*_WAIT`**: Allows one clock cycle for the SRAM to propagate the requested read data to `dout`.
3. **`*_CHECK`**: Compares `dout` against the `expected` register. If they do not match, the FSM flags the error via `$display` to the simulation console and drives the `fail` pin high. Asserts the Write Enable (`we`) signal.
4. **`*_WRITE`**: Drives the new test pattern `din` into the memory array and increments/decrements the address pointer depending on the current iteration direction.
