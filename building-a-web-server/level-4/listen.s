.intel_syntax noprefix

sockaddr_in:
    .word 2              # AF_INET
    .word 0x5000         # port 80 (network byte order)
    .long 0              # INADDR_ANY
    .quad 0              # padding

.global _start

_start:
    # socket(AF_INET, SOCK_STREAM, 0)
    mov rax, 41
    mov rdi, 2           # AF_INET
    mov rsi, 1           # SOCK_STREAM
    xor rdx, rdx         # protocol = 0
    syscall              # rax = sockfd

    mov r12, rax         # save socket fd

    # bind(sockfd, &sockaddr_in, 16)
    mov rdi, r12
    lea rsi, [rip+sockaddr_in]
    mov rdx, 16
    mov rax, 49          # __NR_bind
    syscall

    # listen(sockfd, backlog=0)
    mov rdi, r12
    xor rsi, rsi         # backlog = 0
    mov rax, 50          # __NR_listen
    syscall

    # exit(0)
    xor rdi, rdi
    mov rax, 60
    syscall
