.intel_syntax noprefix

sockaddr_in:
    .word 2              # AF_INET
    .word 0x5000         # port 80
    .long 0              # INADDR_ANY
    .quad 0              # padding

.global _start

_start:
    # socket()
    mov rax, 41
    mov rdi, 2
    mov rsi, 1
    xor rdx, rdx
    syscall
    mov r12, rax         # save listening socket fd

    # bind()
    mov rdi, r12
    lea rsi, [rip+sockaddr_in]
    mov rdx, 16
    mov rax, 49
    syscall

    # listen()
    mov rdi, r12
    xor rsi, rsi         # backlog = 0
    mov rax, 50
    syscall

    # accept()
    mov rdi, r12
    xor rsi, rsi         # addr = NULL
    xor rdx, rdx         # addrlen = NULL
    mov rax, 43
    syscall              # returns client fd in rax

    # exit(0)
    xor rdi, rdi
    mov rax, 60
    syscall
