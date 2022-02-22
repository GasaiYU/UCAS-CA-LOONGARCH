# 5-Level Pilelined CPU (LoongArch ISA)

#### **Environment:**  

Vivado 2019.2.1

#### **File Structure: **

##### Pipeline:

`mycpu/if_stage.v`: Instruction Fectch Stage

`mycpu/id_state.v`: Instruction Decode Stage 

`mycpu/exe_stage.v`: Instruction Execute Stage

`mycpu/mem_stage.v`: Memory Visiting Stage

`mycpu/wb_stage.v`: Write Back Stage

##### Others:

`mycpu/alu.v`:  Arithmetic and Logic Units

`mycpu/regfile.v`: General Registers (32)

`mycpu/csrr.v`: Priviledged Registers

`mycpu/tlb.v`: TLB module

`mycpu/transfer_bridge.v`: Translate AXI Request to SRAM Request

`mycpu/tools.v`:  Some tools.

`mycpu_top.v`: Instantiation (all modules above)

##### Header Files:

`mycpu/mycpu.h`: Define data width.

#### Note:

These files are just design Files. Simulation Files and Constraint Files need adding. 

This CPU can support 56 instrutions, including Arithmetic instructions, Logic instructions, Branch, Jump, Load, Store and other priviledged instructions.

**There are no skeleton frames. Every lines was written by me and my partner!**

For more details about Loonarch: https://github.com/loongson/LoongArch-Documentation

