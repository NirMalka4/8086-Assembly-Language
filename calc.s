%macro call_func 0
    pushad
    pushfd
%endmacro

%macro ret_func 0
    popfd
    popad
%endmacro

%macro Allocate_Link 0
    call_func 
	push dword Link_Size
	call malloc
    mov dword [Malloc_Ptr], eax
    add esp, 4                  ; cleanup
    ret_func 
%endmacro

%macro LoggerText 1 ; documant every input and every result pushed into the stack
    call_func
        cmp byte [Debug_Flag], 1
	jne %%end
	push dword %1
	push dword [stderr]
	call fprintf
	add esp, 8; cleanup
%%end:
    ret_func
%endmacro

%macro LoggerInt 1 ; documant every input and every result pushed into the stack
    call_func
	cmp byte [Debug_Flag], 1
	jne %%end
	push dword %1
	push format_string_decimal
	push dword [stderr]
	call fprintf
	add esp, 12; cleanup
%%end:
    ret_func
%endmacro

%macro LoggerResult 0 ; documant every input and every result pushed into the stack
    call_func
        cmp byte [Debug_Flag], 1
	jne %%end
	peek_And_Print stderr
%%end:
    ret_func
%endmacro

%macro Printt 2
    call_func 
	push dword %2
    	push dword format_string
        push dword [%1]
	call fprintf
	add esp, 12             ; cleanup
    ret_func 
%endmacro

%macro Read 0
    call_func 
	push dword [stdin]
	push dword Input_Max_Size
	push dword Input_buffer
	call fgets
	add esp, dword 12   ; cleanup
	LoggerText user_entered
	LoggerText eax
    ret_func 
%endmacro

%macro isEmpty 0
    mov eax, [Stack_Pointer]
    cmp eax, dword Stack
    jne %%not_empty
    Printt stdout, Insufficient_Args
    jmp Get_Input
    %%not_empty:
%endmacro

%macro isFull 0
    mov al, [Stack_Capacity]
    cmp al,[Stack_Size]
	jl %%not_full
    Printt stdout, Stack_Overflow
    jmp Get_Input
    %%not_full:
%endmacro

%macro containsTwoOperands 0
    mov eax, dword Stack + 8
    mov ebx, dword [Stack_Pointer]
    cmp eax, ebx
    jle %%contains2
    Printt stdout, Insufficient_Args
    jmp Get_Input
    %%contains2:
%endmacro

%macro removeFirstOperand 0 
    mov eax, [Stack_Pointer]
    sub eax, dword Stack_Element_Size
    mov [Stack_Pointer], eax
    call_func
    push dword [eax]
    call f_free
    add esp, 4
    ret_func 
%endmacro

%macro close_program 0
    mov eax, 1
    int 0x80
    nop
%endmacro

%macro peek_And_Print 1
call_func
%%set_print:
    ; put nullchar and new line in the returned string
    mov eax, Print_Stack
    mov [eax], byte 0
    dec eax
    mov [eax], byte New_Line
    dec eax
    ; peek first operand. load it address to ebx.
    mov ebx, [Stack_Pointer]
    sub ebx, dword Stack_Element_Size
    mov ebx, [ebx]
%%get_numbers:		;append to the returned string, the ascii values of the first operand links 
    cmp ebx, dword 0
    je %%remove_2
    mov cl, [ebx + Data]
    add cl, byte 48
    mov [eax], cl
    dec eax
    mov ebx, [ebx + Next]
    jmp %%get_numbers 
%%remove_2:
    inc eax
    ; print first operand
    Printt %1, eax
    ret_func
%endmacro

section .rodata
    Ascii_Offset:	    equ 48
    New_Line:	        equ 10
    Data:	            equ 0
    Next:	            equ 1
    Base:               equ 8
    Stack_Element_Size: equ 4   ; size of a pointer
    Link_Size: 	        equ 5   ; Link consist of 1 byte contains data and 4 bytes contains pointer to next link
    Input_Max_Size: 	equ 80
    format_string:      db '%s', 0
    format_string_decimal:      db '%d',New_Line, 0
    user_entered: db 'user entered - ', 0
    pushed_value: db 'pushed value - ', 0
    quit_msg: db 'quitting', New_Line, 0
    add_msg: db 'ADDING function is being called...', New_Line, 0
    dup_msg: db 'DUPLICATING function is being called...', New_Line, 0
    num_of_bytes_msg: db 'NUM_OF_BYTES function is being called...', New_Line, 0
    bitwise_and_msg: db 'BITWISE_AND function is being called...', New_Line, 0
    pop_msg: db 'POP_AND_PRINT function is being called...', New_Line, 0
    pushed_received_num_msg: db 'the number is being pushed to the stack...', New_Line, 0

    prompt: 		    db 'calc: ', 0
    Stack_Overflow: 	db 'Error: Operand Stack Overflow', New_Line, 0
    Insufficient_Args: 	db 'Error: Insufficient Number of Arguments on Stack', New_Line, 0

section .bss
    Stack:          RESB 252 ; reserve space for max stack size: 63 pointers
    Input_buffer: 	RESB 80
    Print_Stack:    RESB 85 ; buffer used to print popped elements at run-time


section .data
    Debug_Flag: db 0
    Stack_Pointer:  dd Stack  ; contains address of next avaliable cell at the operands stack.
    Carry: db 0
    Counter: dd 0
    Stack_Size: db 5  ; contains stack size. set by default to 5.
    Stack_Capacity: db 0
    Malloc_Ptr: dd 0 ; contains return address from malloc call

section .text
     align 16
     global main
     
     extern printf
     extern fprintf
     extern fgets
     
     extern malloc
     extern free
     
     extern stderr
     extern stdin
     extern stdout

main:
	mov dword [Stack_Pointer], Stack    ;Set Stack_Pointer to the beginning of operands stack
    mov byte [Stack_Size], 5  ;Default stack size
    mov byte [Stack_Capacity], 0
    mov ecx, [esp + 8]    ;argv
    mov ebx, 4  ;argv index
    mov edi, [esp + 4] ; argc
    ;mov byte [Debug_Flag], 0
get_args:
    cmp edi, 1
    je Get_Input
    mov eax, [ecx + ebx] ; eax = argv[i][0]
    cmp word [eax], "-d"  ; debug?
    je set_debug_mode
set_stack_size:
    ;get stack size out of octal number string. 
    ;assume max size is 77 (63 in decimal).
    mov dl, [eax]
    sub dl, '0'
    mov [Stack_Size], dl
    cmp byte [eax + 1], 0 ; stack size argument is out of single digit
    je single_digit_size
    shl dl, 3   
    mov [Stack_Size], dl
    mov dl,[eax + 1]
    sub dl, '0'
    add [Stack_Size], dl
single_digit_size:
    add ebx, 4
    dec edi
    jmp get_args

set_debug_mode:
    mov byte [Debug_Flag], 1
    add ebx, 4
    dec edi
    jmp get_args
Get_Input:
    Printt stdout, prompt
	; read input to eax
    Read
    ; bl contains first char of the input string
	mov bl, byte [Input_buffer] 

Quit:
	cmp bl, 'q'
	je f_Quit	

	inc dword [Counter] ; count operation in advance
Add:
	cmp bl, '+'
	je f_Add
Pop_And_Print:
	cmp bl, 'p'
	je f_Pop_And_Print
Duplicate:
	cmp bl, 'd'
	je f_Duplicate
Bitwise_And:
	cmp bl, '&'
	je f_Bitwise_And
Num_Of_Bytes:
	cmp bl, 'n'
	je f_Num_Of_Bytes
NOP:; recieved octal number
	; Decrease operations counter as the input is an argument
	dec dword [Counter]
	LoggerText pushed_received_num_msg
    isFull
Build_Link: ; *****Assume Legal Input: octal number******
    mov esi, Input_buffer  ; esi point to ith char of input at ith iteration
    xor edi, edi           ; address of the head of the list which represent the argument
Loop:
    mov bl, byte [esi]
    cmp bl, byte New_Line
    je End_Loop
    sub bl, '0' ; get decimal of ith char at the input
    Allocate_Link
    mov eax, [Malloc_Ptr]
    mov [eax + Data], byte bl
    mov [eax + Next], dword edi
    mov edi, eax
    inc esi
    jmp Loop
End_Loop:
    mov esi, [Stack_Pointer]
    mov [esi], edi            ; set next avaliable cell at the stack as a pointer to the new link
    add esi, dword Stack_Element_Size
    mov [Stack_Pointer], esi  ; advance Stack_Pointer to point to next avalaible cell
    add byte [Stack_Capacity], 1
    jmp Get_Input

f_Add:; pop and sum the two first arguments. push the result. 
    ; Verify stack contains at least two operands
    LoggerText add_msg
    containsTwoOperands
set_pointers:
    ; esi contains first operand address. edi contains the second.
    mov edi, [Stack_Pointer]
    mov esi, dword [edi - 8]
    mov edi, dword [edi - 4]
    mov [Carry], byte 0 ; reset carry
proceed_add:        
    ; set al as the sum of two first digits
    mov al, byte [esi+Data]
    add al, byte [edi+Data]
    add al, byte [Carry]
    mov bl, al      ; backup al value
    shr al,4        ; verify if the sum exceed 8
    jc set_carry    ; 4 th bit is on. sum exceed octal base.
    mov [esi+Data], byte bl
    mov [Carry], byte 0
    jmp advance_pointers
set_carry:
    mov [Carry], byte 1
    and bl, byte 7  ; get reminder
    mov [esi + Data], byte bl
advance_pointers:
    mov ecx, [esi + Next]; ecx points to next link at first number list.
    mov edx, [edi + Next]; edx points to next link at second number list.
    or ecx, edx         ; verify whether both list has ended
    cmp ecx, byte 0
    je end_add         ; both list end.
    mov ecx, [esi + Next]
    cmp ecx, byte 0    ; first list end.
    je proceed_first_list_end
    cmp edx, byte 0    ; second list end.
    je proceed_second_list_end 
proceed_add_two_list:
    mov esi, [esi + Next]
    mov edi, [edi + Next]
    jmp proceed_add
end_add:
    ; verify carry exists
    mov cl, [Carry]
    cmp cl, byte 0
    je remove_1
    ; carry does exist, allocate another link contains carry value
    ; esi contain address of last link at the first list 
    Allocate_Link
    mov eax, [Malloc_Ptr]
    mov [eax + Data], byte 1
    mov [eax + Next], dword 0
    mov [esi + Next], eax
remove_1:
    ; free first element in the stack.
    removeFirstOperand
    sub byte [Stack_Capacity], 1
    LoggerText pushed_value
    LoggerResult
    jmp Get_Input
proceed_first_list_end:
    ; allocate new link. set it data to 0.
    Allocate_Link
    mov eax, [Malloc_Ptr]
    mov [eax + Data], byte 0
    mov [eax + Next], dword 0
    mov [esi + Next], eax
    mov esi, eax
    mov edi, [edi + Next]
    jmp proceed_add
proceed_second_list_end:
    ; advance esi to next link. set edi data to 0.
    mov esi, [esi + Next]
    mov [edi + Data], byte 0
    jmp proceed_add

f_Pop_And_Print: ; pop and print first operand
    LoggerText pop_msg
	; verify stack is not empty
    isEmpty
    peek_And_Print stdout
    ; free first operand in the operands stack
    removeFirstOperand
    sub byte [Stack_Capacity], 1
    jmp Get_Input

f_Duplicate:
    LoggerText dup_msg
	; verify stack is neither empty nor full
    isEmpty
    isFull
proceed_duplicate:
    ; allocate space for the duplicated number
    mov esi, [Stack_Pointer]
    add esi, 4
    mov [Stack_Pointer], esi
    sub esi, 4
    ; push new number (represented as linked list of octal base numbers)
    Allocate_Link
    mov edi, [Malloc_Ptr]
    mov [esi], edi
    ; esi contains the address of the origin list
    ; edi contains the address of the duplicated list
    sub esi, dword Stack_Element_Size
    mov esi, [esi]
duplicate_loop:
    ;iterate over first operand links. duplicate each one of them.
    mov eax, [esi + Data]
    mov [edi + Data], eax
    cmp [esi + Next], dword 0
    je duplicate_last_link ; no further allocation is required
    Allocate_Link
    mov eax, [Malloc_Ptr]
    mov [edi + Next], eax
    mov edi, eax
    mov esi, [esi + Next]
    jmp duplicate_loop
duplicate_last_link:
    mov [edi + Next], dword 0
    add byte [Stack_Capacity], 1
    LoggerText pushed_value
    LoggerResult
    jmp Get_Input

f_Bitwise_And:
    LoggerText bitwise_and_msg
	;verify stack contains two operands
    containsTwoOperands
    ; retrieve two first operands
    mov esi, [Stack_Pointer]
    mov edi, [esi - 4] ; second opernad address (top element in the stack)
    mov esi, [esi - 8] ; first opernad address
    xor ebx, ebx       ; ebx points to before last link at first opernad 
    ; while both list did not end, bitwise compatibale link values
bitwise_and_loop:
    mov ecx, esi    ; backup esi
    mov edx, edi    ; backup edi
    and ecx, edx    ;both list did not end?    
    cmp ecx, 0
    je end_bitwise_and_loop
    mov al, [edi + Data]
    and byte [esi + Data], al
    mov ebx, esi
    mov esi, [esi + Next]
    mov edi, [edi + Next]
    jmp bitwise_and_loop
end_bitwise_and_loop:
    ; pop first operand. free it heap allocation.
    removeFirstOperand
    sub byte [Stack_Capacity], 1
    LoggerText pushed_value
    LoggerResult
    ; if first operand list is longer than the second, remove it surplus links.
    cmp esi, 0
    je Get_Input    ; first operand list is at most of the length of second operand list
    call_func
    push dword esi
    call f_free
    add esp, dword 4
    ret_func
    mov [ebx + Next], dword 0
    jmp Get_Input

f_Num_Of_Bytes: 
    LoggerText num_of_bytes_msg
    isEmpty
    ; peek first operand. load it address to esi.
    mov esi, [Stack_Pointer]
    sub esi, 4
    mov esi, [esi]
    xor cl, cl  ; count num of bits first operand required
num_of_bits_loop:
    cmp esi, 0
    je end_num_of_bits_loop
    add cl, byte 3  ; each data field requires 3 bit
    mov esi, dword [esi + Next]
    jmp num_of_bits_loop
end_num_of_bits_loop:
    mov bl, cl ; backup
    shr cl, 3  ; divide num of bits by octal base(8)
    and bl, 7  ; get reminder to verify if round up is required
    cmp bl, 0
    jne round_up
    jmp remove_3
round_up:
    inc cl
remove_3:
    ;pop first operand from the operand stack.
    ;push new link whose value is the number of bytes it(popped element) required.
    removeFirstOperand
    mov dl, 1
loop_set_num_of_bytes:
    ;insert new operand represent cl value in octal base
    cmp cl, 0
    je end_loop_set_num_of_bytes
    Allocate_Link
    mov eax, [Malloc_Ptr]
    mov bl, cl
    and bl, 7
    mov [eax + Data], bl
    cmp dl, 1
    jne not_head_link
    dec dl
    mov esi, eax    ; backup for the head of the cl list
    jmp cont_loop
not_head_link:
    mov [edi + Next], eax
cont_loop:
    mov edi, eax
    shr cl, 3
    jmp loop_set_num_of_bytes
end_loop_set_num_of_bytes:
    mov dword [edi + Next], 0
    mov edi, [Stack_Pointer]
    mov [edi], esi 
    add edi, dword Stack_Element_Size
    mov dword [Stack_Pointer], edi
    LoggerText pushed_value
    LoggerResult    
    jmp Get_Input

f_free: ; remove list whose head it's the function argument
    push ebp                
    mov ebp, esp
    mov eax, [ebp + 8]    ; head
free_loop:
    cmp eax, 0
    je end_free_loop
    mov ebx, eax            ; save head
    mov eax, [eax + Next]   ; proceed to next
    call_func               ; save state
    push ebx
    call free
    add esp, dword 4        ; cleanup
    ret_func 
    jmp free_loop      
end_free_loop:
    mov esp, ebp
    pop ebp
    ret

f_Quit:
    LoggerText quit_msg
	;iterate over operands. delete each of them.
    mov eax, [Stack_Pointer] 
    sub eax, 4
f_quit_loop:
    cmp eax, Stack
    jl end_main
    call_func
    push dword [eax]
    call f_free
    add esp, 4
    ret_func
    sub eax, 4
    jmp f_quit_loop
end_main:
    mov eax, [Counter]
    int 0x80
    nop