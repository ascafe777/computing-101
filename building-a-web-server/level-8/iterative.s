.intel_syntax noprefix
.global _start

.section .data
http_header:
    .ascii "HTTP/1.0 200 OK\r\n\r\n"
header_len = 19      # correct header length

.section .bss
request:    .space 1024
filepath:   .space 256
filebuf:    .space 4096

.section .text
_start:
    # socket(AF_INET, SOCK_STREAM, 0)
    mov rax, 41
    mov rdi, 2
    mov rsi, 1
    xor rdx, rdx
    syscall
    mov r12, rax      # server socket

    # bind(socket, sockaddr_in, 16)
    sub rsp, 16
    mov word ptr [rsp], 2
    mov word ptr [rsp+2], 0x5000
    mov dword ptr [rsp+4], 0
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
    mov r13, rax     # client socket

    # read(client, request, 1024)
    mov rax, 0
    mov rdi, r13
    lea rsi, [request]
    mov rdx, 1024
    syscall

    # parse path
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

    # open file
    mov rax, 2
    lea rdi, [filepath]
    xor rsi, rsi
    syscall
    mov r15, rax

    # read file
    mov rax, 0
    mov rdi, r15
    lea rsi, [filebuf]
    mov rdx, 4096
    syscall
    mov rbx, rax

    # close file
    mov rax, 3
    mov rdi, r15
    syscall

    # write HTTP header
    mov rax, 1
    mov rdi, r13
    lea rsi, [http_header]
    mov rdx, header_len
    syscall

    # write file contents
    mov rax, 1
    mov rdi, r13
    lea rsi, [filebuf]
    mov rdx, rbx
    syscall

    # close client
    mov rax, 3
    mov rdi, r13
    syscall

    jmp accept_loop      # wait for next client
