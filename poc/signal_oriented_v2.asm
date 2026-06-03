; signal_oriented_v2.asm
; nasm -f elf64 signal_oriented_v2.asm -o signal_oriented_v2.o
; ld signal_oriented_v2.o -o signal_oriented_v2
; ./signal_oriented_v2

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

%macro OP_EMIT 0
    db 0xc6,0x04,0x25,0,0,0,0,0     ; mov byte [0],0
%endmacro

%macro OP_JNZ 1
    lea rax, [rel %1]
    mov [rel jmp_target], rax
    xor ecx, ecx
    div ecx                         ; SIGFPE, length = 2 bytes
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
    mov rdi, SIGFPE
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

loop_body:
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

    ; branch while CNT != 0
    OP_JNZ loop_body

    ; newline = 10
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

    cmp edi, SIGFPE
    je .fpe

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

.fpe:
    cmp byte [rel cnt], 0
    je .no_jump

    dec byte [rel cnt]
    mov rax, [rel jmp_target]
    mov [rdx + UC_RIP], rax
    ret

.no_jump:
    add qword [rdx + UC_RIP], 2
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

acc:        db 0
cnt:        db 2                      ; loop extra times, total prints = 3
outch:      db 0
jmp_target: dq 0
