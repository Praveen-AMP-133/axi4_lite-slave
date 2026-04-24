# AXI4-Lite Slave (Verilog)

## 📌 Overview

This repository contains a **fully functional AXI4-Lite slave implementation** written in Verilog.
It supports **memory-mapped register access** with proper handling of AXI4-Lite protocol features such as:

* Independent address and data channels
* Out-of-order arrival of write address and data
* Backpressure handling
* Valid/Ready handshake mechanism
* Read and write transactions

---

## 🧠 Key Concepts

### AXI4-Lite Protocol

AXI4-Lite is a **lightweight memory-mapped interface** used for low-bandwidth control paths.
It consists of 5 independent channels:

| Channel            | Purpose               |
| ------------------ | --------------------- |
| Write Address (AW) | Carries write address |
| Write Data (W)     | Carries write data    |
| Write Response (B) | Response from slave   |
| Read Address (AR)  | Carries read address  |
| Read Data (R)      | Returns read data     |

---

## 🏗️ Design Architecture

### Internal Register File

```verilog
reg [DATA_WIDTH-1:0] regfile [0:3];
```

* 4 memory-mapped registers
* Each register is 32-bit wide
* Address decoding is **word-aligned using `[3:2]` bits**

---

### Address Mapping

| Address | Register   |
| ------- | ---------- |
| 0x0     | regfile[0] |
| 0x4     | regfile[1] |
| 0x8     | regfile[2] |
| 0xC     | regfile[3] |

---

## 🔄 Write Transaction Flow

1. **Address Phase**

   * `AWVALID && AWREADY`
   * Address is latched into `awaddr_reg`

2. **Data Phase**

   * `WVALID && WREADY`
   * Data is accepted

3. **Write Completion**

   * Both `aw_done` and `w_done` must be asserted
   * Data written to register file

4. **Response Phase**

   * `BVALID` asserted
   * Wait for `BREADY`

---

### Internal Control Signals

```verilog
reg aw_done;  // Address accepted
reg w_done;   // Data accepted
```

These ensure:

* Proper synchronization between AW and W channels
* Support for out-of-order transactions

---

## 📖 Read Transaction Flow

1. **Address Phase**

   * `ARVALID && ARREADY`
   * Address is latched into `araddr_reg`

2. **Data Phase**

   * Data is selected from register file
   * `RVALID` asserted

3. **Completion**

   * Wait for `RREADY`
   * Transaction completes

---

## ⚠️ Important Design Notes

### ✅ Address Alignment

* Only **word-aligned addresses** are supported
* Lower bits `[1:0]` are ignored

---

### ❗ Known Limitation / Improvement Area

⚠️ Current implementation uses:

```verilog
case (ARADDR[3:2])
```

👉 Recommended improvement:

```verilog
case (araddr_reg[3:2])
```

This ensures:

* Correct operation when address changes after handshake
* Full AXI compliance

---

### ⚠️ Byte Strobe (WSTRB)

* Currently not implemented in write logic
* Future enhancement: support partial writes

---

## 🧪 Verification

The design has been verified using a custom testbench covering:

### ✔ Functional Tests

* Basic read/write
* Multiple register access

### ✔ Protocol Scenarios

* AW before W
* W before AW
* Parallel transactions

### ✔ Backpressure

* Delayed READY signals
* Delayed BREADY / RREADY

### ✔ Edge Cases

* VALID held high
* Random stress testing

---

## 📊 Simulation

* Tool: EDA Playground / VCS
* Waveform: EPWave
* Dump file: `axi4-lite-slave.vcd`

---

## 🚀 How to Run

1. Compile:

```bash
vcs design.sv testbench.sv
```

2. Run:

```bash
./simv
```

3. View waveform:

```bash
gtkwave axi4-lite-slave.vcd
```

---

## 📂 File Structure

```
├── axi4_lite_slave.sv   # RTL Design
├── tb_axi4_lite_slave.sv # Testbench
├── README.md            # Documentation
```

---

## 🧠 Learning Outcomes

This project helps you understand:

* AXI4-Lite protocol fundamentals
* Valid/Ready handshake mechanism
* Register-mapped design
* RTL debugging using waveforms
* Handling asynchronous channel arrival

---

## 🔥 Future Enhancements

* Add WSTRB support (byte-level writes)
* Add error response (`SLVERR`)
* Support more registers
* Add assertions (SVA)
* Convert to UVM-based verification

---

## 👨‍💻 Author

Devarala Praveen Kumar

---
