.intel_syntax noprefix

sockaddr_in:
    .word 2              # AF_INET
    .word 0x5000         # port 80 in network byte order (0x0050 -> store 0x5000 so memory is 00 50)
    .long 0              # INADDR_ANY (0.0.0.0)
    .quad 0              # padding (8 zero bytes)

.global _start

_start:
    # socket(AF_INET, SOCK_STREAM, 0)
    mov rax, 41          # __NR_socket
    mov rdi, 2           # AF_INET
    mov rsi, 1           # SOCK_STREAM
    xor rdx, rdx         # protocol = 0
    syscall              # rax = sockfd

    # bind(sockfd, &sockaddr_in, 16)
    mov rdi, rax                # rdi = sockfd
    lea rsi, [rip+sockaddr_in]  # rsi = &sockaddr_in
    mov rdx, 16                 # rdx = sizeof(sockaddr_in)
    mov rax, 49                 # __NR_bind
    syscall

    # exit(0)
    xor rdi, rdi
    mov rax, 60
    syscall
