.intel_syntax noprefix
.global _start

# ---------------- Data Section ----------------
.section .data
http_response:
    .ascii "HTTP/1.0 200 OK\r\n\r\n"
response_len = . - http_response

.content_length_header:
    .ascii "Content-Length: "
cl_len_len = . - .content_length_header

.section .bss
request:    .space 8192      # buffer for HTTP request
filepath:   .space 256       # buffer for file path
bodybuf:    .space 8192      # buffer for POST body

.section .text
_start:
    # --- socket(AF_INET, SOCK_STREAM, 0) ---
    mov rax, 41
    mov rdi, 2         # AF_INET
    mov rsi, 1         # SOCK_STREAM
    xor rdx, rdx       # protocol = 0
    syscall
    mov r12, rax       # server socket

    # --- bind ---
    sub rsp, 16
    mov word ptr [rsp], 2            # AF_INET
    mov word ptr [rsp+2], 0x5000     # htons(80)
    mov dword ptr [rsp+4], 0         # INADDR_ANY
    mov rax, 49
    mov rdi, r12
    lea rsi, [rsp]
    mov rdx, 16
    syscall
    add rsp, 16

    # --- listen(socket, 0) ---
    mov rax, 50
    mov rdi, r12
    xor rsi, rsi
    syscall

accept_loop:
    # --- accept ---
    mov rax, 43
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    syscall
    mov r13, rax   # client socket

    # --- fork ---
    mov rax, 57
    syscall
    cmp rax, 0
    je child_process
    # parent process
    mov rax, 3
    mov rdi, r13
    syscall
    jmp accept_loop

# =====================================================
#                  Child process
# =====================================================
child_process:
    # --- close listening socket ---
    mov rax, 3
    mov rdi, r12
    syscall

    # --- read request ---
    mov rax, 0
    mov rdi, r13
    lea rsi, [request]
    mov rdx, 8192
    syscall
    mov r14, rax       # bytes read

    # --- dispatch on method ---
    mov eax, dword ptr [request]   # first 4 bytes
    cmp eax, 0x20544547            # "GET " little-endian
    je handle_get
    cmp eax, 0x54534F50            # "POST" little-endian
    je handle_post
    jmp send_ok_and_exit           # fallback

# ==================== GET ====================
handle_get:
    # parse path after "GET "
    lea rsi, [request+4]
    lea rdi, [filepath]
.get_path_loop:
    mov al, byte ptr [rsi]
    cmp al, ' '
    je .get_path_done
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    jmp .get_path_loop
.get_path_done:
    mov byte ptr [rdi], 0

    # open file (O_RDONLY)
    mov rax, 2
    lea rdi, [filepath]
    xor rsi, rsi         # O_RDONLY
    xor rdx, rdx
    syscall
    mov r12, rax

    # write HTTP 200 OK header
    mov rax, 1
    mov rdi, r13
    lea rsi, [http_response]
    mov rdx, response_len
    syscall

    # stream file contents to client
.read_file_loop:
    mov rax, 0
    mov rdi, r12
    lea rsi, [bodybuf]
    mov rdx, 8192
    syscall
    test rax, rax
    jle .done_file
    mov rdx, rax
    mov rax, 1
    mov rdi, r13
    lea rsi, [bodybuf]
    syscall
    jmp .read_file_loop
.done_file:
    mov rax, 3
    mov rdi, r12
    syscall
    jmp close_and_exit

# ==================== POST ====================
handle_post:
    # --- parse path (after "POST ") ---
    lea rsi, [request+5]
    lea rdi, [filepath]
.parse_path:
    mov al, byte ptr [rsi]
    cmp al, ' '
    je .path_done
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    jmp .parse_path
.path_done:
    mov byte ptr [rdi], 0

    # --- find end of headers (\r\n\r\n) ---
    lea rsi, [request]
    xor rbx, rbx
.find_headers_end:
    cmp rbx, r14
    jge .no_headers
    mov al, byte ptr [rsi+rbx]
    cmp al, 13
    jne .next1
    mov al, byte ptr [rsi+rbx+1]
    cmp al, 10
    jne .next1
    mov al, byte ptr [rsi+rbx+2]
    cmp al, 13
    jne .next1
    mov al, byte ptr [rsi+rbx+3]
    cmp al, 10
    je .headers_done
.next1:
    inc rbx
    jmp .find_headers_end
.no_headers:
    mov rbx, r14
.headers_done:
    add rbx, 4   # body offset

    # --- find Content-Length header robustly ---
    lea r8, [request]   # base
    xor rcx, rcx
    mov r15, 0          # default length
.find_cl_line:
    cmp rcx, rbx
    jge .set_default_len
    lea r9, [r8+rcx]    # candidate line start

    # compare "content-length" case-insensitive
    xor r10, r10
.cl_cmp_loop:
    cmp r10, 14
    jge .cl_after_key
    mov al, byte ptr [r9+r10]
    cmp al, 'A'
    jb .cl_tolower_done
    cmp al, 'Z'
    ja .cl_tolower_done
    add al, 32
.cl_tolower_done:
    mov dl, byte ptr [.cl_key + r10]
    cmp al, dl
    jne .skip_line
    inc r10
    jmp .cl_cmp_loop

.cl_after_key:
    mov r10, 14
.skip_spaces_before_colon:
    mov al, byte ptr [r9+r10]
    cmp al, ' '
    jne .check_colon
    inc r10
    jmp .skip_spaces_before_colon
.check_colon:
    cmp byte ptr [r9+r10], ':'
    jne .skip_line
    inc r10
.skip_spaces_after_colon:
    mov al, byte ptr [r9+r10]
    cmp al, ' '
    jne .parse_digits
    inc r10
    jmp .skip_spaces_after_colon

.parse_digits:
    xor r15, r15
.digit_loop:
    mov al, byte ptr [r9+r10]
    cmp al, 13
    je .got_length
    cmp al, '0'
    jb .got_length
    cmp al, '9'
    ja .got_length
    sub al, '0'
    imul r15, r15, 10
    movzx edx, al
    add r15, rdx
    inc r10
    jmp .digit_loop

.got_length:
    jmp .length_capped

.skip_line:
    mov al, byte ptr [r8+rcx]
    inc rcx
    cmp al, 10
    jne .skip_line
    jmp .find_cl_line

.set_default_len:
    mov r15, r14
    sub r15, rbx

.length_capped:
    mov rax, r14
    sub rax, rbx
    cmp r15, rax
    cmova r15, rax
    mov rax, 8192
    cmp r15, rax
    cmova r15, rax

    # --- copy body to buffer ---
    lea rsi, [request+rbx]
    lea rdi, [bodybuf]
    mov rcx, r15
    rep movsb

    # --- open file (O_WRONLY|O_CREAT, 0777) ---
    mov rax, 2
    lea rdi, [filepath]
    mov rsi, 65          # O_WRONLY|O_CREAT
    mov rdx, 0777
    syscall
    mov r12, rax

    # --- write body ---
    mov rax, 1
    mov rdi, r12
    lea rsi, [bodybuf]
    mov rdx, r15
    syscall

    # --- close file ---
    mov rax, 3
    mov rdi, r12
    syscall

    # respond OK, then close
    jmp send_ok_and_exit

# ==================== Common ====================
send_ok_and_exit:
    mov rax, 1
    mov rdi, r13
    lea rsi, [http_response]
    mov rdx, response_len
    syscall

close_and_exit:
    mov rax, 3
    mov rdi, r13
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall

# --- data for case-insensitive key match ---
.cl_key:
    .ascii "content-length"
