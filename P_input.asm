.model small
.stack 100h

; Definicion de la constante que define la cantidad de valores a ordenar
N EQU 30

.data
    ; --- Variables para archivo LOG ---
    filename    db 'log.txt', 0     ; Nombre del archivo ASCIIZ
    fhandle     dw ?                ; ID del archivo devuelto por DOS
    temp_char   db ?                ; Variable temporal para imprimir caracteres

    ; Arreglo de N palabras (16 bits) inicializadas en 0
    arreglo     dw N dup(0)
    
    ; --- Estructura del Arbol ---
    arbol_val   dw N dup(0)
    arbol_izq   dw N dup(0FFFFh)
    arbol_der   dw N dup(0FFFFh)
    nodos_act   dw 0
    
    ; --- Cadenas de Texto ---
    msg_in      db 13, 10, 'Ingrese un numero: $'
    msg_err     db 13, 10, '-> Error. Intente de nuevo.$'
    msg_out     db 13, 10, 13, 10, 'Numeros almacenados: $'
    separador   db ', $'
    
    msg_pausa   db 13, 10, 13, 10, '--- Presione cualquier tecla para generar el Arbol ---', 13, 10, '$'
    
    ; Cabecera de la tabla (usando espacios y tabs visuales)
    msg_tabla   db 13, 10, 13, 10, 'DIR', 9, 'VALOR', 9, 'HIJO_IZQ', 9, 'HIJO_DER', 13, 10
                db '------------------------------------------------', 13, 10, '$'
    str_null    db 'NULL$'
    newline     db 13, 10, '$'

    ; --- Variables y Cadenas para Postorden ---
    suma_total      dw 0
    msg_pausa_tabla db 13, 10, 13, 10, '--- Tabla generada. Presione cualquier tecla para iniciar suma Postorden ---', 13, 10, '$'
    msg_inicio_post db 13, 10, 'Iniciando sumatoria en Postorden...', 13, 10, '$'
    msg_prefijo     db 'suma_total: $'
    msg_mas         db ' + $'
    msg_igual       db ' = $'
    msg_fin         db 13, 10, '--- Programa finalizado. Presione una tecla para salir ---', 13, 10, '$'

.code
main:
    mov ax, @data
    mov ds, ax

    ; ==========================================
    ; CREACION DEL ARCHIVO DE LOG
    ; ==========================================
    mov ah, 3Ch
    mov cx, 0           ; Atributo normal
    lea dx, filename
    int 21h
    mov fhandle, ax     ; Guardamos el identificador

    ; ==========================================
    ; FASE 1: INGRESO DE DATOS
    ; ==========================================
    mov cx, N           ; Inicializar contador de ciclo con la constante N
    mov di, 0           ; Indice para recorrer el arreglo

ingreso_datos:
    ; Mostrar mensaje solicitando entrada
    lea dx, msg_in
    mov ah, 09h
    int 21h

    ; Llamar a la subrutina que lee y valida el numero
    call leer_numero
    
    ; Si la subrutina detecta un error, enciende la bandera Carry (CF = 1)
    jc  manejo_error

    ; Si no hubo error, el numero valido esta en AX. Lo guardamos en memoria.
    mov arreglo[di], ax
    
    add di, 2           ; Avanzamos 2 bytes (por DW - 16 bits)
    loop ingreso_datos  ; Decrementa CX y repite si no es 0
    jmp mostrar_datos   ; Si ya termino, saltamos a la impresion

manejo_error:
    ; Mostrar mensaje de error
    lea dx, msg_err
    mov ah, 09h
    int 21h
    
    ; Saltamos de regreso a pedir el dato. 
    ; CX no se decrementa por no pasar por la instruccion "loop"
    jmp ingreso_datos

    ; ==========================================
    ; FASE 2: IMPRESION DE VALORES REGISTRADOS
    ; ==========================================
mostrar_datos:
    ; Mostrar mensaje de salida
    lea dx, msg_out
    mov ah, 09h
    int 21h
    call log_cadena     ; Guardar en archivo

    mov cx, N           ; Reiniciamos el contador a N
    mov di, 0           ; Reiniciamos el indice a 0

imprimir_arreglo:
    mov ax, arreglo[di]
    call imprimir_numero
    call log_numero     ; Guardar en archivo
    
    cmp cx, 1
    je  fin_imprimir_arr
    lea dx, separador
    mov ah, 09h
    int 21h
    call log_cadena     ; Guardar en archivo
    
fin_imprimir_arr:
    add di, 2
    loop imprimir_arreglo

    ; Log de un salto de linea extra para limpieza visual en el archivo
    lea dx, newline
    call log_cadena

    ; ==========================================
    ; FASE 3: PAUSA
    ; ==========================================
    lea dx, msg_pausa
    mov ah, 09h
    int 21h

    mov ah, 08h         ; Interrupcion 21h, Funcion 08h: Leer tecla sin eco
    int 21h

    ; ==========================================
    ; CONSTRUCCION DEL ARBOL
    ; ==========================================
    mov cx, N
    mov si, 0

insertar_loop:
    mov ax, arreglo[si]
    cmp nodos_act, 0
    jne buscar_posicion
    
    mov di, 0
    mov arbol_val[di], ax
    inc nodos_act
    jmp siguiente_numero

buscar_posicion:
    mov bx, 0           ; Iniciar en la raiz
comparar_nodo:
    cmp ax, arbol_val[bx]
    jl  ir_izquierda
    jmp ir_derecha

ir_izquierda:
    mov di, arbol_izq[bx]
    cmp di, 0FFFFh      ; Valor NULL sintetico
    je  insertar_izq
    mov bx, di
    jmp comparar_nodo

insertar_izq:
    mov di, nodos_act
    shl di, 1
    mov arbol_izq[bx], di
    mov arbol_val[di], ax
    inc nodos_act
    jmp siguiente_numero

ir_derecha:
    mov di, arbol_der[bx]
    cmp di, 0FFFFh      ; Valor NULL sintetico
    je  insertar_der
    mov bx, di
    jmp comparar_nodo

insertar_der:
    mov di, nodos_act
    shl di, 1
    mov arbol_der[bx], di
    mov arbol_val[di], ax
    inc nodos_act

siguiente_numero:
    add si, 2
    dec cx
    jnz insertar_loop

    ; ==========================================
    ; FASE 4: IMPRESION DE LA TABLA
    ; ==========================================
    lea dx, msg_tabla
    mov ah, 09h
    int 21h
    call log_cadena     ; Guardar en archivo

    mov cx, N
    mov di, 0           ; DI es nuestro indice relativo (direccion)

imprimir_filas:
    ; 1. Imprimir Direccion (Indice Relativo: 0, 2, 4...)
    mov ax, di
    call imprimir_numero
    call log_numero     ; LOG
    call imprimir_tab
    call log_tab        ; LOG

    ; 2. Imprimir Valor
    mov ax, arbol_val[di]
    call imprimir_numero
    call log_numero     ; LOG
    call imprimir_tab
    call log_tab        ; LOG

    ; 3. Imprimir Hijo Izquierdo
    mov ax, arbol_izq[di]
    cmp ax, 0FFFFh          ; Valor NULL sintetico
    je  izq_es_null
    call imprimir_numero    ; Si no es NULL, imprimir la direccion
    call log_numero         ; LOG
    jmp fin_izq
izq_es_null:
    call print_null         ; Si es NULL, imprimir la palabra "NULL"
    call log_print_null     ; LOG
fin_izq:
    call imprimir_tab
    call log_tab            ; LOG

    ; 4. Imprimir Hijo Derecho
    mov ax, arbol_der[di]
    cmp ax, 0FFFFh      ; Valor NULL sintetico
    je  der_es_null
    call imprimir_numero
    call log_numero         ; LOG
    jmp fin_der
der_es_null:
    call print_null
    call log_print_null     ; LOG
fin_der:

    ; Salto de linea para la siguiente fila
    lea dx, newline
    mov ah, 09h
    int 21h
    call log_cadena         ; LOG

    add di, 2               ; Avanzar al siguiente nodo
    loop imprimir_filas

    ; ==========================================
    ; FASE 5: PAUSA POST-TABLA
    ; ==========================================
    lea dx, msg_pausa_tabla
    mov ah, 09h
    int 21h

    mov ah, 08h
    int 21h

    ; ==========================================
    ; FASE 6: RECORRIDO POSTORDEN Y SUMAS PARCIALES
    ; ==========================================
    lea dx, msg_inicio_post
    mov ah, 09h
    int 21h
    call log_cadena         ; LOG

    mov suma_total, 0   ; Garantizar que la suma inicie en 0
    mov bx, 0           ; Iniciar el recorrido enviando la Raiz (Direccion 0) en BX
    call recorrido_postorden

    ; Pausa de finalizacion de programa
    lea dx, msg_fin
    mov ah, 09h
    int 21h
    
    mov ah, 08h
    int 21h

    ; ==========================================
    ; CIERRE DE ARCHIVO Y SALIDA
    ; ==========================================
    mov ah, 3Eh
    mov bx, fhandle
    int 21h

    ; Salir a DOS
    mov ah, 4Ch
    int 21h

; =========================================================
; SUBRUTINAS DE APOYO (Input/Output Originales)
; =========================================================

; --- Imprimir Tabulador ASCII ---
imprimir_tab proc
    push ax
    push dx
    mov dl, 09h         ; Codigo ASCII para TAB
    mov ah, 02h
    int 21h
    pop dx
    pop ax
    ret
imprimir_tab endp

; --- Imprimir cadena "NULL" ---
print_null proc
    push ax
    push dx
    lea dx, str_null
    mov ah, 09h
    int 21h
    pop dx
    pop ax
    ret
print_null endp

; =========================================================
; SUBRUTINA: leer_numero
; Lee caracteres hasta que se presiona Enter.
; Convierte la cadena ASCII a un valor numerico de 16 bits.
; Retorna:  AX = Numero convertido
;           CF = 0 (Exito) / CF = 1 (Error por no numerico)
; =========================================================
leer_numero proc
    push bx
    push cx
    push dx
    
    mov bx, 0           ; BX sera nuestro acumulador temporal

leer_caracter:
    mov ah, 01h         ; Leer caracter con eco
    int 21h

    cmp al, 0Dh         ; Es Enter (Carriage Return)?
    je  fin_lectura     ; Si es Enter, terminamos de leer el numero

    ; Validar que sea un numero (ASCII entre '0' y '9')
    cmp al, '0'
    jl  caracter_invalido
    cmp al, '9'
    jg  caracter_invalido

    ; Es un digito valido. Convertir de ASCII a valor numerico
    sub al, 30h         ; Convertir '3' (33h) a 3
    mov cl, al
    mov ch, 0           ; CX ahora tiene el digito aislado

    ; Logica para acumular: Acumulador = (Acumulador * 10) + NuevoDigito
    mov ax, bx
    mov dx, 10
    mul dx              ; AX = AX * 10
    add ax, cx          ; Sumar el nuevo digito
    mov bx, ax          ; Guardar de nuevo en el acumulador (BX)
    
    jmp leer_caracter   ; Volver a leer el siguiente caracter

caracter_invalido:
    stc                 ; STC (Set Carry Flag): Enciende la bandera de acarreo (Error)
    jmp salir_lectura

fin_lectura:
    mov ax, bx          ; Mover el total final a AX para retornarlo
    clc                 ; CLC (Clear Carry Flag): Apaga la bandera de acarreo (Exito)

salir_lectura:
    pop dx
    pop cx
    pop bx
    ret
leer_numero endp

; =========================================================
; SUBRUTINA: imprimir_numero
; Convierte el valor de 16 bits en AX a texto y lo imprime
; =========================================================
imprimir_numero proc
    push ax
    push bx
    push cx
    push dx

    mov bx, 10          ; Divisor base 10
    mov cx, 0           ; Contador de digitos
    
    cmp ax, 0
    jne dividir_loop
    ; Si el nuumero es 0, simplemente lo imprimimos y salimos
    mov dl, '0'
    mov ah, 02h
    int 21h
    jmp fin_imprimir

dividir_loop:
    mov dx, 0           ; Limpiar DX (DX:AX / BX)
    div bx              ; AX = Cociente, DX = Residuo
    push dx             ; Guardar digito en la pila
    inc cx              ; Incrementar contador
    cmp ax, 0           
    jne dividir_loop    

imprimir_digitos:
    pop dx              ; Sacar digito
    add dl, 30h         ; Convertir a ASCII
    mov ah, 02h         
    int 21h
    loop imprimir_digitos

fin_imprimir:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
imprimir_numero endp

; =========================================================
; SUBRUTINA: recorrido_postorden
; Recorre el arbol e imprime la sumatoria en vivo
; Recibe: BX = Direccion actual
; =========================================================
recorrido_postorden proc
    cmp bx, 0FFFFh          ; Caso base: Llego a NULL?
    je  fin_postorden
    
    push bx                 ; Preservar el nodo actual

    ; --- 1. Ir a la Izquierda ---
    mov bx, arbol_izq[bx]
    call recorrido_postorden

    ; --- 2. Ir a la Derecha ---
    pop bx                  
    push bx                 
    mov bx, arbol_der[bx]
    call recorrido_postorden

    ; --- 3. Procesar Raiz ---
    pop bx                  
    
    ; "suma_total: "
    push bx
    lea dx, msg_prefijo
    mov ah, 09h
    int 21h
    call log_cadena         ; LOG
    
    ; Total previo
    mov ax, suma_total
    call imprimir_numero
    call log_numero         ; LOG
    
    ; " + "
    lea dx, msg_mas
    mov ah, 09h
    int 21h
    call log_cadena         ; LOG
    
    ; Valor actual
    pop bx
    push bx
    mov ax, arbol_val[bx]
    call imprimir_numero
    call log_numero         ; LOG
    
    ; " = "
    lea dx, msg_igual
    mov ah, 09h
    int 21h
    call log_cadena         ; LOG
    
    ; Sumatoria logica
    pop bx
    push bx
    mov ax, arbol_val[bx]   
    add suma_total, ax      
    
    ; Nuevo total
    mov ax, suma_total
    call imprimir_numero
    call log_numero         ; LOG
    
    ; Salto de linea
    lea dx, newline
    mov ah, 09h
    int 21h
    call log_cadena         ; LOG

    pop bx                  ; Restaurar BX para el nivel superior
fin_postorden:
    ret
recorrido_postorden endp

; =========================================================
; NUEVAS SUBRUTINAS DE APOYO PARA ARCHIVO LOG
; =========================================================

; --- Guarda cadena terminada en '$' en archivo ---
log_cadena proc
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, dx          
    mov cx, 0           
contar_loop:
    cmp byte ptr [si], '$'  
    je  escribir_log
    inc cx              
    inc si              
    jmp contar_loop

escribir_log:
    mov ah, 40h
    mov bx, fhandle
    ; DX mantiene el apuntador original
    int 21h

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
log_cadena endp

; --- Escribe el caracter en DL en el archivo ---
log_char proc
    push ax
    push bx
    push cx
    push dx

    mov temp_char, dl   

    mov ah, 40h
    mov bx, fhandle
    mov cx, 1           
    lea dx, temp_char   
    int 21h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
log_char endp

; --- Convierte valor AX a texto y lo guarda en archivo ---
log_numero proc
    push ax
    push bx
    push cx
    push dx

    mov bx, 10          
    mov cx, 0           
    
    cmp ax, 0
    jne log_dividir_loop
    mov dl, '0'
    call log_char
    jmp log_fin_imprimir

log_dividir_loop:
    mov dx, 0           
    div bx              
    push dx             
    inc cx              
    cmp ax, 0           
    jne log_dividir_loop    

log_imprimir_digitos:
    pop dx              
    add dl, 30h         
    call log_char
    loop log_imprimir_digitos

log_fin_imprimir:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
log_numero endp

; --- Imprimir Tabulador en Archivo ---
log_tab proc
    push ax
    push dx
    mov dl, 09h         
    call log_char
    pop dx
    pop ax
    ret
log_tab endp

; --- Imprimir "NULL" en Archivo ---
log_print_null proc
    push ax
    push dx
    lea dx, str_null
    call log_cadena
    pop dx
    pop ax
    ret
log_print_null endp

end main