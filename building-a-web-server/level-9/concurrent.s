.intel_syntax noprefix
.global _start

.section .data
http_header:
    .ascii "HTTP/1.0 200 OK\r\n\r\n"
header_len = . - http_header  # length of HTTP header

.section .bss
request:    .space 1024       # buffer for HTTP request
filepath:   .space 256        # buffer for file path
filebuf:    .space 4096       # buffer for file contents

.section .text
_start:
    # socket(AF_INET, SOCK_STREAM, 0)
    mov rax, 41
    mov rdi, 2            # AF_INET
    mov rsi, 1            # SOCK_STREAM
    xor rdx, rdx          # protocol = 0
    syscall
    mov r12, rax          # save server socket

    # bind(socket, sockaddr_in, 16)
    sub rsp, 16
    mov word ptr [rsp], 2            # AF_INET
    mov word ptr [rsp+2], 0x5000    # htons(80)
    mov dword ptr [rsp+4], 0        # INADDR_ANY
    mov rax, 49
    mov rdi, r12
    lea rsi, [rsp]
    mov rdx, 16
    syscall
    add rsp, 16

    # listen(socket, 0)
    mov rax, 50
    mov rdi, r12
    xor rsi, rsi
    syscall

accept_loop:
    # accept(socket, NULL, NULL)
    mov rax, 43
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    syscall
    mov r13, rax          # client socket

    # fork()
    mov rax, 57
    syscall
    cmp rax, 0
    je child_process       # child process branch
    # parent process
    mov r14, rax
    # close client socket in parent
    mov rax, 3
    mov rdi, r13
    syscall
    jmp accept_loop        # continue accepting

child_process:
    # close listening socket in child
    mov rax, 3
    mov rdi, r12
    syscall

    # read(client, request, 1024)
    mov rax, 0
    mov rdi, r13
    lea rsi, [request]
    mov rdx, 1024
    syscall
    mov r14, rax        # store read length

    # parse path (skip "GET " and copy until space)
    lea rsi, [request+4]
    lea rdi, [filepath]
parse_loop:
    mov al, byte ptr [rsi]
    cmp al, ' '
    je parse_done
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    jmp parse_loop
parse_done:
    mov byte ptr [rdi], 0

    # open(filepath, O_RDONLY)
    mov rax, 2
    lea rdi, [filepath]
    xor rsi, rsi
    syscall
    mov r15, rax        # file FD

    # read(file, filebuf, 4096)
    mov rax, 0
    mov rdi, r15
    lea rsi, [filebuf]
    mov rdx, 4096
    syscall
    mov rbx, rax        # file size

    # close(file)
    mov rax, 3
    mov rdi, r15
    syscall

    # write(client, http header)
    mov rax, 1
    mov rdi, r13
    lea rsi, [http_header]
    mov rdx, header_len
    syscall

    # write(client, file contents)
    mov rax, 1
    mov rdi, r13
    lea rsi, [filebuf]
    mov rdx, rbx
    syscall

    # close(client)
    mov rax, 3
    mov rdi, r13
    syscall

    # exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall
