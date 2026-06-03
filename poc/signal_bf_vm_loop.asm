; signal_bf_vm_loop.asm
; nasm -f elf64 signal_bf_vm_loop.asm -o signal_bf_vm_loop.o
; ld signal_bf_vm_loop.o -o signal_bf_vm_loop
; ./signal_bf_vm_loop

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

%macro BF_INC 0
    int3                            ; '+', SIGTRAP, len 1
%endmacro

%macro BF_DEC 0
    ud2                             ; '-', SIGILL, len 2
%endmacro

%macro BF_RIGHT 0
    xor ecx, ecx
    div ecx                         ; '>', SIGFPE, len 2
%endmacro

%macro BF_LEFT 0
    db 0x8a,0x04,0x25,0,0,0,0       ; '<', mov al,[0], len 7
%endmacro

%macro BF_EMIT 0
    db 0xc6,0x04,0x25,0,0,0,0,0     ; '.', mov byte [0],0, len 8
%endmacro

%macro BF_LOOP_START 1
    lea rax, [rel %1]
    mov [rel loop_fwd], rax
    db 0x8b,0x04,0x25,0,0,0,0       ; '[', mov eax,[0], len 7
%endmacro

%macro BF_LOOP_END 1
    lea rax, [rel %1]
    mov [rel loop_back], rax
    db 0x89,0x04,0x25,0,0,0,0       ; ']', mov [0],eax, len 7
%endmacro

%macro BF_ADD10 0
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
%endmacro

SECTION .text

_start:
    mov rax, SYS_rt_sigaction
    mov rdi, SIGTRAP
    lea rsi, [rel sa]
    xor rdx, rdx
    mov r10, 8
    syscall

    mov rax, SYS_rt_sigaction
    mov rdi, SIGILL
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

    ; BF-ish program:
    ;
    ; cell0 = 7
    ; while cell0 != 0:
    ;     cell1 += 10
    ;     cell0--
    ;
    ; result:
    ;     cell1 = 70 = 'F'

    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC

loop0_start:
    BF_LOOP_START loop0_end

    BF_RIGHT
    BF_ADD10
    BF_LEFT
    BF_DEC

    BF_LOOP_END loop0_start
loop0_end:

    ; ptr -> cell1
    BF_RIGHT

    ; emit 'F' = 70
    BF_EMIT

    ; cell1 += 8 -> 'N' = 78
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC
    BF_INC

    BF_EMIT

    ; move to cell2 and emit newline = 10
    BF_RIGHT
    BF_ADD10
    BF_EMIT

    mov rax, SYS_exit
    xor rdi, rdi
    syscall

handler:
    cmp edi, SIGTRAP
    je .inc_cell

    cmp edi, SIGILL
    je .dec_cell

    cmp edi, SIGFPE
    je .right

    cmp edi, SIGSEGV
    je .segv_decode

    ret

.inc_cell:
    movzx rax, byte [rel ptr]
    lea rbx, [rel tape]
    inc byte [rbx + rax]
    ret

.dec_cell:
    movzx rax, byte [rel ptr]
    lea rbx, [rel tape]
    dec byte [rbx + rax]
    add qword [rdx + UC_RIP], 2
    ret

.right:
    inc byte [rel ptr]
    add qword [rdx + UC_RIP], 2
    ret

.segv_decode:
    mov rax, [rdx + UC_RIP]
    mov al, [rax]

    cmp al, 0x8a                    ; '<'
    je .left

    cmp al, 0xc6                    ; '.'
    je .emit

    cmp al, 0x8b                    ; '['
    je .loop_start

    cmp al, 0x89                    ; ']'
    je .loop_end

    ret

.left:
    dec byte [rel ptr]
    add qword [rdx + UC_RIP], 7
    ret

.emit:
    add qword [rdx + UC_RIP], 8

    movzx rax, byte [rel ptr]
    lea rbx, [rel tape]
    mov al, [rbx + rax]
    mov [rel outch], al

    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [rel outch]
    mov rdx, 1
    syscall

    ret

.loop_start:
    movzx rax, byte [rel ptr]
    lea rbx, [rel tape]
    cmp byte [rbx + rax], 0
    jne .loop_start_continue

    mov rax, [rel loop_fwd]
    mov [rdx + UC_RIP], rax
    ret

.loop_start_continue:
    add qword [rdx + UC_RIP], 7
    ret

.loop_end:
    movzx rax, byte [rel ptr]
    lea rbx, [rel tape]
    cmp byte [rbx + rax], 0
    je .loop_end_continue

    mov rax, [rel loop_back]
    mov [rdx + UC_RIP], rax
    ret

.loop_end_continue:
    add qword [rdx + UC_RIP], 7
    ret

restorer:
    mov rax, 15                     ; rt_sigreturn
    syscall

SECTION .data

sa:
    dq handler
    dq SA_SIGINFO | SA_RESTORER
    dq restorer
    dq 0

ptr:       db 0
outch:     db 0
loop_fwd:  dq 0
loop_back: dq 0

SECTION .bss

tape:  resb 256
