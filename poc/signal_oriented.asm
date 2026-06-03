; signal_oriented.asm
; nasm -f elf64 signal_oriented.asm -o signal_oriented.o
; ld signal_oriented.o -o signal_oriented
; ./signal_oriented

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

; Linux x86_64 ucontext_t -> RIP offset
%define UC_RIP 168

%macro OP_ADD16 0
    ud2                         ; SIGILL
%endmacro

%macro OP_ADD1 0
    int3                        ; SIGTRAP
%endmacro

%macro OP_EMIT 0
    ; mov byte [0], 0
    ; deliberate SIGSEGV, length = 8 bytes
    db 0xc6,0x04,0x25,0,0,0,0,0
%endmacro

SECTION .text

_start:
    ; install SIGILL handler
    mov rax, SYS_rt_sigaction
    mov rdi, SIGILL
    lea rsi, [rel sa]
    xor rdx, rdx
    mov r10, 8
    syscall

    ; install SIGTRAP handler
    mov rax, SYS_rt_sigaction
    mov rdi, SIGTRAP
    lea rsi, [rel sa]
    xor rdx, rdx
    mov r10, 8
    syscall

    ; install SIGSEGV handler
    mov rax, SYS_rt_sigaction
    mov rdi, SIGSEGV
    lea rsi, [rel sa]
    xor rdx, rdx
    mov r10, 8
    syscall

    ; build 'F' = 70 = 4*16 + 6
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
    OP_EMIT

    ; build 'N' = 78 = 4*16 + 14
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
    OP_EMIT

    ; build newline = 10
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
    OP_EMIT

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
    add qword [rdx + UC_RIP], 2      ; skip ud2
    ret

.segv:
    add qword [rdx + UC_RIP], 8      ; skip fake memory write

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
    mov rax, 15                      ; rt_sigreturn
    syscall

SECTION .data

sa:
    dq handler
    dq SA_SIGINFO | SA_RESTORER
    dq restorer
    dq 0

acc:   db 0
outch: db 0
