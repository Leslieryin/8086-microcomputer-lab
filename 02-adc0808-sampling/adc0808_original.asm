; ==============================================================
; ADC0808 定时采样显示程序
; 说明：
;   8253 负责产生固定周期的中断请求；
;   8259 接收中断请求并转入中断服务程序；
;   在中断服务程序中启动 ADC0808 转换；
;   将转换结果的高 4 位送七段数码管显示。
; ==============================================================

; ------------------------------
; 中断向量表预留区
; ------------------------------
IVTSEG SEGMENT
    DB 1024 DUP(0)
IVTSEG ENDS

; ------------------------------
; 数据段
; ------------------------------
DSEG SEGMENT
    ; 共阴极七段数码管 0~F 段码
    TAB7SEG DB 3FH, 06H, 5BH, 4FH
            DB 66H, 6DH, 7DH, 07H
            DB 7FH, 6FH, 77H, 7CH
            DB 39H, 5EH, 79H, 71H
DSEG ENDS

; ------------------------------
; 堆栈段
; ------------------------------
SSEG SEGMENT STACK
    DB 256 DUP(0)
SSEG ENDS

; ------------------------------
; 代码段
; ------------------------------
CSEG SEGMENT
    ASSUME CS:CSEG, DS:DSEG, SS:SSEG

; ------------------------------
; 端口地址定义
; ------------------------------
PPI_B       EQU 0102H
PPI_CTRL    EQU 0106H

TIMER0      EQU 0200H
TIMER1      EQU 0202H
TIMER_CTRL  EQU 0206H

PIC_CMD     EQU 0300H
PIC_DATA    EQU 0302H

ADC_PORT    EQU 0400H

INT_NO      EQU 60H
EOI_CODE    EQU 20H

START:
    ; 设置数据段
    MOV AX, DSEG
    MOV DS, AX

    ; 设置堆栈段
    MOV AX, SSEG
    MOV SS, AX
    MOV SP, 0100H

    CLI

; ==============================================================
; 写入 60H 号中断向量
; ==============================================================
    XOR AX, AX
    MOV ES, AX

    MOV BX, 0180H              ; 60H * 4 = 0180H
    MOV AX, OFFSET INT_PROC
    MOV WORD PTR ES:[BX], AX

    MOV AX, CS
    MOV WORD PTR ES:[BX+2], AX

; ==============================================================
; 初始化 8255
; 方式 0，A/B/C 口均设置为输出
; ==============================================================
    MOV DX, PPI_CTRL
    MOV AL, 80H
    OUT DX, AL

; ==============================================================
; 初始化 8253
; 输入 1MHz，经两级分频后得到 10Hz
; 计数器 0：1MHz / 1000 = 1kHz
; 计数器 1：1kHz / 100 = 10Hz
; ==============================================================

    ; 计数器 0，方式 3，计数初值 03E8H
    MOV DX, TIMER_CTRL
    MOV AL, 36H
    OUT DX, AL

    MOV DX, TIMER0
    MOV AL, 0E8H
    OUT DX, AL
    MOV AL, 03H
    OUT DX, AL

    ; 计数器 1，方式 2，计数初值 0064H
    MOV DX, TIMER_CTRL
    MOV AL, 74H
    OUT DX, AL

    MOV DX, TIMER1
    MOV AL, 64H
    OUT DX, AL
    MOV AL, 00H
    OUT DX, AL

; ==============================================================
; 初始化 8259
; IR0 对应中断类型号 60H，只开放 IR0
; ==============================================================
    MOV DX, PIC_CMD
    MOV AL, 13H
    OUT DX, AL

    MOV DX, PIC_DATA
    MOV AL, INT_NO
    OUT DX, AL

    MOV AL, 01H
    OUT DX, AL

    MOV AL, 0FEH
    OUT DX, AL

    STI

MAIN_LOOP:
    HLT
    JMP MAIN_LOOP

; ==============================================================
; 中断服务程序
; ==============================================================
INT_PROC PROC FAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DS

    MOV AX, DSEG
    MOV DS, AX

; ------------------------------
; 启动 ADC0808 转换
; ------------------------------
    MOV DX, ADC_PORT
    XOR AL, AL
    OUT DX, AL

; ------------------------------
; 等待转换完成
; ------------------------------
    MOV CX, 00FFH

ADC_WAIT:
    LOOP ADC_WAIT

; ------------------------------
; 读取 ADC0808 数据
; ------------------------------
    IN AL, DX

; ------------------------------
; 只显示高 4 位
; ------------------------------
    SHR AL, 1
    SHR AL, 1
    SHR AL, 1
    SHR AL, 1

; ------------------------------
; 查表得到数码管段码
; ------------------------------
    MOV BX, OFFSET TAB7SEG
    XLAT

; ------------------------------
; 输出到 8255 B 口
; ------------------------------
    MOV DX, PPI_B
    OUT DX, AL

; ------------------------------
; 发送中断结束命令
; ------------------------------
    MOV DX, PIC_CMD
    MOV AL, EOI_CODE
    OUT DX, AL

    POP DS
    POP DX
    POP CX
    POP BX
    POP AX

    IRET

INT_PROC ENDP

CSEG ENDS
END START