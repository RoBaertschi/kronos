package kronos_idt

import "base:intrinsics"
import "kernel:utils"

Interrupt_Type :: enum {
    Fault,
    Trap,
    Abort,
    Interrupt,
    Reserved,
}

Interrupt :: enum u8 {
    Divide_Error,                   // DIV and IDIV instructions
    Debug_Exception,                // Instruction, data, and I/O breakpoints; single-step; and others
    NMI_Interrupt,                  // Nonmaskable external interrupt
    Breakpoint,                     // INT3 instruction
    Overflow,                       // INTO instruction
    Bound_Range_Exeeded,            // BOUND instruction
    Invalid_Opcode,                 // UD instruction or reserved opcode
    Device_not_Available,           // (No Math Coprocessor) Floating-point or WAIT/FWAIT instruction
    Double_Fault,                   // Any instruction that can generate an exception, an NMI, or an INTR
    Coprocessor_Segment_Overrun,    // (reserved) Floating-point instructions
    Invalid_TSS,                    // Task switch or TSS access
    Segment_Not_Present,            // Loading segment registers or accessing system segments
    Stack_Segment_Fault,            // Stack operations and SS register loads
    General_Protection,             // Any memory reference and other protection checks
    Page_Fault,                     // Any memory reference
    _Intel_Reserved,                // Intel reserved. Do not use
    Math_Fault,                     // (x87 FPU Floating-Point Error) x87 FPU floating-point or WAIT/FWAIT instruction
    Alignment_Check,                // Any data reference in memory
    Machine_Check,                  // Error codes (if any) and source are model dependent
    SIMD_Floating_Point_Exception,  // SSE/SSE2/SSE3 floating-point instructions
    Virtualization_Exception,       // EPT violations
    Control_Protection_Exception,   // RET, IRET, RSTORSSP, and SETSSBSY instructions can generate this exception. When CET indirect branch tracking is enabled, this exception can be generated due to a missing ENDBRANCH instruction at target of an indirect call or jump.
    _Reserved_1,                    // Reserved for future use as CPU exception vectors
    _Reserved_2,                    // Reserved for future use as CPU exception vectors
    _Reserved_3,                    // Reserved for future use as CPU exception vectors
    _Reserved_4,                    // Reserved for future use as CPU exception vectors
    _Reserved_5,                    // Reserved for future use as CPU exception vectors
    _Reserved_6,                    // Reserved for future use as CPU exception vectors
    _Reserved_7,                    // Reserved for future use as CPU exception vectors
    _Reserved_8,                    // Reserved for future use as CPU exception vectors
    _Reserved_9,                    // Reserved for future use as CPU exception vectors
    _Reserved_10,                   // Reserved for future use as CPU exception vectors
    // The rest are external interrupts
}

#assert(intrinsics.type_enum_is_contiguous(Interrupt))

interrupt_mnemonics := [Interrupt]string{
    .Divide_Error                   = "#DE",
    .Debug_Exception                = "#DB",
    .NMI_Interrupt                  = "NMI",
    .Breakpoint                     = "#BP",
    .Overflow                       = "#OF",
    .Bound_Range_Exeeded            = "#BR",
    .Invalid_Opcode                 = "#UD",
    .Device_not_Available           = "#NM",
    .Double_Fault                   = "#DF",
    .Coprocessor_Segment_Overrun    = "N/A",
    .Invalid_TSS                    = "#TS",
    .Segment_Not_Present            = "#NP",
    .Stack_Segment_Fault            = "#SS",
    .General_Protection             = "#GP",
    .Page_Fault                     = "#PF",
    ._Intel_Reserved                = "N/A",
    .Math_Fault                     = "#MF",
    .Alignment_Check                = "#AC",
    .Machine_Check                  = "#MC",
    .SIMD_Floating_Point_Exception  = "#CM",
    .Virtualization_Exception       = "#VE",
    .Control_Protection_Exception   = "#CP",
    ._Reserved_1                    = "N/A",
    ._Reserved_2                    = "N/A",
    ._Reserved_3                    = "N/A",
    ._Reserved_4                    = "N/A",
    ._Reserved_5                    = "N/A",
    ._Reserved_6                    = "N/A",
    ._Reserved_7                    = "N/A",
    ._Reserved_8                    = "N/A",
    ._Reserved_9                    = "N/A",
    ._Reserved_10                   = "N/A",
}

interrupt_get_mnemonic :: proc "contextless" (interrupt: u8) -> string {
    if interrupt > u8(max(Interrupt)) {
        return "N/A" // External Interrupt
    }
    return interrupt_mnemonics[Interrupt(interrupt)]
}

interrupt_types := [Interrupt]Interrupt_Type{
    .Divide_Error                   = .Fault,
    .Debug_Exception                = .Trap,
    .NMI_Interrupt                  = .Interrupt,
    .Breakpoint                     = .Trap,
    .Overflow                       = .Trap,
    .Bound_Range_Exeeded            = .Fault,
    .Invalid_Opcode                 = .Fault,
    .Device_not_Available           = .Fault,
    .Double_Fault                   = .Fault,
    .Coprocessor_Segment_Overrun    = .Abort,
    .Invalid_TSS                    = .Fault,
    .Segment_Not_Present            = .Fault,
    .Stack_Segment_Fault            = .Fault,
    .General_Protection             = .Fault,
    .Page_Fault                     = .Fault,
    ._Intel_Reserved                = .Reserved,
    .Math_Fault                     = .Fault,
    .Alignment_Check                = .Fault,
    .Machine_Check                  = .Abort,
    .SIMD_Floating_Point_Exception  = .Fault,
    .Virtualization_Exception       = .Fault,
    .Control_Protection_Exception   = .Fault,
    ._Reserved_1                    = .Reserved,
    ._Reserved_2                    = .Reserved,
    ._Reserved_3                    = .Reserved,
    ._Reserved_4                    = .Reserved,
    ._Reserved_5                    = .Reserved,
    ._Reserved_6                    = .Reserved,
    ._Reserved_7                    = .Reserved,
    ._Reserved_8                    = .Reserved,
    ._Reserved_9                    = .Reserved,
    ._Reserved_10                   = .Reserved,
}

interrupt_get_type :: proc "contextless" (interrupt: u8) -> Interrupt_Type {
    if interrupt > u8(max(Interrupt)) {
        return .Interrupt // External Interrupt
    }
    return interrupt_types[Interrupt(interrupt)]
}

interrupts_have_error_code := [Interrupt]bool {
    .Divide_Error                   = false,
    .Debug_Exception                = false,
    .NMI_Interrupt                  = false,
    .Breakpoint                     = false,
    .Overflow                       = false,
    .Bound_Range_Exeeded            = false,
    .Invalid_Opcode                 = false,
    .Device_not_Available           = false,
    .Double_Fault                   = true,  // zero
    .Coprocessor_Segment_Overrun    = false,
    .Invalid_TSS                    = true,
    .Segment_Not_Present            = true,
    .Stack_Segment_Fault            = true,
    .General_Protection             = true,
    .Page_Fault                     = true,
    ._Intel_Reserved                = false,
    .Math_Fault                     = false,
    .Alignment_Check                = true, // zero
    .Machine_Check                  = false,
    .SIMD_Floating_Point_Exception  = false,
    .Virtualization_Exception       = false,
    .Control_Protection_Exception   = true,
    ._Reserved_1                    = false,
    ._Reserved_2                    = false,
    ._Reserved_3                    = false,
    ._Reserved_4                    = false,
    ._Reserved_5                    = false,
    ._Reserved_6                    = false,
    ._Reserved_7                    = false,
    ._Reserved_8                    = false,
    ._Reserved_9                    = false,
    ._Reserved_10                   = false,
}

interrupt_has_error_code :: proc "contextless" (interrupt: u8) -> bool {
    if interrupt > u8(max(Interrupt)) {
        return false // External Interrupt
    }
    return interrupts_have_error_code[Interrupt(interrupt)]
}

interrupt_is_external :: proc "contextless" (interrupt: u8) -> bool {
    return interrupt > u8(max(Interrupt))
}

interrupt_name :: proc "contextless" (interrupt: u8) -> string {
    interrupt := Interrupt(interrupt)
    if utils.reflect_enum_value_has_name(interrupt) {
        return utils.reflect_enum_string(interrupt)
    }

    return "External_Interrupt"
}
