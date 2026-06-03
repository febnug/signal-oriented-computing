; fault_syscall_vm.asm
; nasm -f elf64 fault_syscall_vm.asm -o fault_syscall_vm.o
; ld fault_syscall_vm.o -o fault_syscall_vm
; ./fault_syscall_vm

BITS 64
GLOBAL _start

%define SYS_rt_sigaction 13
%define SYS_write        1
%define SYS_exit         60

%define SIGILL   4
%define SIGTRAP  5
%define SIGFPE   8
%define SIGSEGV  11

%define SA_SIGINFO   4
%define SA_RESTORER  0x04000000

%define UC_RIP 168

%macro OP_ADD16 0
    ud2
%endmacro

%macro OP_ADD1 0
    int3
%endmacro

%macro OP_STORE 0
    db 0xc6,0x04,0x25,0,0,0,0,0     ; mov byte [0],0 -> SIGSEGV
%endmacro

%macro OP_SYSCALL_WRITE 0
    xor ecx, ecx
    div ecx                         ; SIGFPE, fault at div, len = 2
%endmacro

SECTION .text

_start:
    mov rax, SYS_rt_sigaction
    mov rdi, SIGILL
    lea rsi, [rel sa]
    xor rdx, rdx
    mov r10, 8
    syscall

    mov rax, SYS_rt_sigaction
    mov rdi, SIGTRAP
    lea rsi, [rel sa]
    xor rdx, rdx
    mov r10, 8
    syscall

    mov rax, SYS_rt_sigaction
    mov rdi, SIGSEGV
    lea rsi, [rel sa]
    xor rdx, rdx
    mov r10, 8
    syscall

    mov rax, SYS_rt_sigaction
    mov rdi, SIGFPE
    lea rsi, [rel sa]
    xor rdx, rdx
    mov r10, 8
    syscall

    jmp fault_stream

; ------------------------------------------------------------
; Fault-oriented syscall VM stream
;
; SIGILL  = ACC += 16
; SIGTRAP = ACC += 1
; SIGSEGV = STORE ACC into buffer
; SIGFPE  = VM_SYSCALL_WRITE(buffer, len)
;
; The fault stream builds:
;
;   "FN\n"
;
; then asks the VM handler to perform write(1, buffer, len).
; ------------------------------------------------------------

fault_stream:
    ; 'F' = 70 = 4*16 + 6
    OP_ADD16
    OP_ADD16
    OP_ADD16
    OP_ADD16
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_STORE

    ; 'N' = 78 = 4*16 + 14
    OP_ADD16
    OP_ADD16
    OP_ADD16
    OP_ADD16
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_STORE

    ; '\n' = 10
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_ADD1
    OP_STORE

    ; VM syscall: write(1, buffer, len)
    OP_SYSCALL_WRITE

    mov rax, SYS_exit
    xor rdi, rdi
    syscall

handler:
    cmp edi, SIGTRAP
    je .trap

    cmp edi, SIGILL
    je .ill

    cmp edi, SIGSEGV
    je .store

    cmp edi, SIGFPE
    je .vm_write

    ret

.trap:
    inc byte [rel acc]
    ret

.ill:
    add byte [rel acc], 16
    add qword [rdx + UC_RIP], 2
    ret

.store:
    add qword [rdx + UC_RIP], 8

    movzx rax, byte [rel buf_len]
    lea rbx, [rel buf]

    mov cl, [rel acc]
    mov [rbx + rax], cl

    inc byte [rel buf_len]
    mov byte [rel acc], 0

    ret

.vm_write:
    add qword [rdx + UC_RIP], 2

    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [rel buf]
    movzx rdx, byte [rel buf_len]
    syscall

    ret

restorer:
    mov rax, 15                      ; rt_sigreturn
    syscall

SECTION .data

sa:
    dq handler
    dq SA_SIGINFO | SA_RESTORER
    dq restorer
    dq 0

acc:     db 0
buf_len: db 0
buf:     times 32 db 0
