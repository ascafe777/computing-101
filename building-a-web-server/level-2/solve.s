.intel_syntax noprefix
.global _start

_start:
    /* socket(AF_INET, SOCK_STREAM, IPPROTO_IP) */
    mov rax, 41        /* __NR_socket */
    mov rdi, 2         /* AF_INET */
    mov rsi, 1         /* SOCK_STREAM */
    xor rdx, rdx       /* protocol = 0 */
    syscall            /* result in rax (but we don't care about it for exit) */

    /* exit(0) */
    xor rdi, rdi       /* status = 0 */
    mov rax, 60        /* __NR_exit */
    syscall
