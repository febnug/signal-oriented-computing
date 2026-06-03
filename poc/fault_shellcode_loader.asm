; nasm -f elf64 fault_shellcode_loader.asm -o fault_shellcode_loader.o
; ld fault_shellcode_loader.o -o fault_shellcode_loader
; ./fault_shellcode_loader

BITS 64
GLOBAL _start

%define SYS_rt_sigaction 13
%define SYS_write        1
%define SYS_exit         60

%define SIGILL   4
%define SIGTRAP  5
%define SIGSEGV  11

%define SA_SIGINFO   4
%define SA_RESTORER  0x04000000

%define UC_RIP 168

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

    jmp fault_shellcode

; ------------------------------------------------------------
; Fault-oriented shellcode stream
;
; SIGILL  = ACC += 16
; SIGTRAP = ACC += 1
; SIGSEGV = emit ACC, reset ACC
;
; This stream prints:
;
;   FN\n
; ------------------------------------------------------------

fault_shellcode:
    ; 'F' = 70 = 4*16 + 6
    ud2
    ud2
    ud2
    ud2
    int3
    int3
    int3
    int3
    int3
    int3
    db 0xc6,0x04,0x25,0,0,0,0,0

    ; 'N' = 78 = 4*16 + 14
    ud2
    ud2
    ud2
    ud2
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    db 0xc6,0x04,0x25,0,0,0,0,0

    ; '\n' = 10
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    int3
    db 0xc6,0x04,0x25,0,0,0,0,0

    mov rax, SYS_exit
    xor rdi, rdi
    syscall

handler:
    cmp edi, SIGTRAP
    je .trap

    cmp edi, SIGILL
    je .ill

    cmp edi, SIGSEGV
    je .segv

    ret

.trap:
    inc byte [rel acc]
    ret

.ill:
    add byte [rel acc], 16
    add qword [rdx + UC_RIP], 2
    ret

.segv:
    add qword [rdx + UC_RIP], 8

    mov al, [rel acc]
    mov [rel outch], al
    mov byte [rel acc], 0

    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [rel outch]
    mov rdx, 1
    syscall

    ret

restorer:
    mov rax, 15
    syscall

SECTION .data

sa:
    dq handler
    dq SA_SIGINFO | SA_RESTORER
    dq restorer
    dq 0

acc:   db 0
outch: db 0
