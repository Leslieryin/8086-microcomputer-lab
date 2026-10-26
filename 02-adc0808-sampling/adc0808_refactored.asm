
; ==================================================================
; 微机课设仿真实验 - 重构版本
; 功能描述：
;   利用8253定时器、8259中断控制器和ADC0808模数转换器
;   实现10Hz定时采样，并在七段数码管上显示结果
; ==================================================================

; ******************************************************************
; 向量表段
; ******************************************************************
VECTOR_TABLE SEGMENT
    DB 1024 DUP(0)
VECTOR_TABLE ENDS

; ******************************************************************
; 存储段
; ******************************************************************
STORAGE SEGMENT
    ; 七段数码管显示表（共阴极）
    SEG_DISPLAY DB 3FH, 06H, 5BH, 4FH
                DB 66H, 6DH, 7DH, 07H
                DB 7FH, 6FH, 77H, 7CH
                DB 39H, 5EH, 79H, 71H
STORAGE ENDS

; ******************************************************************
; 栈空间段
; ******************************************************************
STACK_SEG SEGMENT STACK
    DB 256 DUP(0)
STACK_SEG ENDS

; ******************************************************************
; 程序段
; ******************************************************************
CODE_SEG SEGMENT
    ASSUME CS:CODE_SEG, DS:STORAGE, SS:STACK_SEG

; ******************************************************************
; 硬件端口定义
; ******************************************************************
PPI_PORT_B   EQU 0102H
PPI_CTRL_REG EQU 0106H

CNT0_ADDR    EQU 0200H
CNT1_ADDR    EQU 0202H
TIMER_CTRL   EQU 0206H

PIC_CMD_PORT EQU 0300H
PIC_DAT_PORT EQU 0302H

ADC_IO_PORT  EQU 0400H

IRQ_TYPE     EQU 60H
PIC_EOI      EQU 20H

; ******************************************************************
; 程序入口点
; ******************************************************************
ENTRY_POINT:
    ; 配置数据段寄存器
    MOV AX, STORAGE
    MOV DS, AX

    ; 配置栈段寄存器
    MOV AX, STACK_SEG
    MOV SS, AX
    MOV SP, 0100H

    ; 关中断
    CLI

    ; 初始化各模块
    CALL SETUP_INTERRUPT
    CALL INIT_PARALLEL_PORT
    CALL INIT_TIMER_MODULE
    CALL INIT_INTERRUPT_CTRL

    ; 开中断
    STI

; ******************************************************************
; 主循环
; ******************************************************************
MAIN_CYCLE:
    HLT
    JMP MAIN_CYCLE

; ******************************************************************
; 子程序：设置中断向量
; ******************************************************************
SETUP_INTERRUPT PROC NEAR
    PUSH AX
    PUSH BX
    PUSH ES

    ; 指向中断向量表
    XOR AX, AX
    MOV ES, AX

    ; 计算中断向量位置
    MOV BX, IRQ_TYPE
    SHL BX, 1
    SHL BX, 1

    ; 设置偏移地址
    MOV AX, OFFSET IRQ_HANDLER
    MOV ES:[BX], AX

    ; 设置段地址
    MOV AX, CS
    MOV ES:[BX+2], AX

    POP ES
    POP BX
    POP AX
    RET
SETUP_INTERRUPT ENDP

; ******************************************************************
; 子程序：初始化8255并行接口
; ******************************************************************
INIT_PARALLEL_PORT PROC NEAR
    PUSH AX
    PUSH DX

    ; 方式0，全部端口输出
    MOV DX, PPI_CTRL_REG
    MOV AL, 80H
    OUT DX, AL

    POP DX
    POP AX
    RET
INIT_PARALLEL_PORT ENDP

; ******************************************************************
; 子程序：初始化8253定时器
; ******************************************************************
INIT_TIMER_MODULE PROC NEAR
    PUSH AX
    PUSH DX

    ; 配置计数器0：方式3，初值1000
    MOV DX, TIMER_CTRL
    MOV AL, 36H
    OUT DX, AL

    MOV DX, CNT0_ADDR
    MOV AL, 0E8H
    OUT DX, AL
    MOV AL, 03H
    OUT DX, AL

    ; 配置计数器1：方式2，初值100
    MOV DX, TIMER_CTRL
    MOV AL, 74H
    OUT DX, AL

    MOV DX, CNT1_ADDR
    MOV AL, 64H
    OUT DX, AL
    MOV AL, 00H
    OUT DX, AL

    POP DX
    POP AX
    RET
INIT_TIMER_MODULE ENDP

; ******************************************************************
; 子程序：初始化8259中断控制器
; ******************************************************************
INIT_INTERRUPT_CTRL PROC NEAR
    PUSH AX
    PUSH DX

    ; ICW1
    MOV DX, PIC_CMD_PORT
    MOV AL, 13H
    OUT DX, AL

    ; ICW2
    MOV DX, PIC_DAT_PORT
    MOV AL, IRQ_TYPE
    OUT DX, AL

    ; ICW4
    MOV AL, 01H
    OUT DX, AL

    ; 仅开放IR0
    MOV AL, 0FEH
    OUT DX, AL

    POP DX
    POP AX
    RET
INIT_INTERRUPT_CTRL ENDP

; ******************************************************************
; 中断处理程序
; ******************************************************************
IRQ_HANDLER PROC FAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DS

    ; 确保数据段正确
    MOV AX, STORAGE
    MOV DS, AX

    ; 启动ADC转换
    CALL TRIGGER_ADC

    ; 等待转换完成
    CALL WAIT_ADC_DONE

    ; 读取并处理ADC数据
    CALL PROCESS_ADC_DATA

    ; 发送EOI命令
    CALL SEND_EOI_TO_PIC

    ; 恢复现场
    POP DS
    POP DX
    POP CX
    POP BX
    POP AX

    IRET
IRQ_HANDLER ENDP

; ******************************************************************
; 子程序：触发ADC转换
; ******************************************************************
TRIGGER_ADC PROC NEAR
    PUSH AX
    PUSH DX

    MOV DX, ADC_IO_PORT
    XOR AL, AL
    OUT DX, AL

    POP DX
    POP AX
    RET
TRIGGER_ADC ENDP

; ******************************************************************
; 子程序：等待ADC转换
; ******************************************************************
WAIT_ADC_DONE PROC NEAR
    PUSH CX

    MOV CX, 00FFH
DELAY_LOOP:
    LOOP DELAY_LOOP

    POP CX
    RET
WAIT_ADC_DONE ENDP

; ******************************************************************
; 子程序：处理ADC数据并显示
; ******************************************************************
PROCESS_ADC_DATA PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; 读取ADC数据
    MOV DX, ADC_IO_PORT
    IN AL, DX

    ; 提取高4位
    MOV CL, 04H
    SHR AL, CL

    ; 查表获取段码
    MOV BX, OFFSET SEG_DISPLAY
    XLAT

    ; 输出到数码管
    MOV DX, PPI_PORT_B
    OUT DX, AL

    POP DX
    POP CX
    POP BX
    POP AX
    RET
PROCESS_ADC_DATA ENDP

; ******************************************************************
; 子程序：发送中断结束命令
; ******************************************************************
SEND_EOI_TO_PIC PROC NEAR
    PUSH AX
    PUSH DX

    MOV DX, PIC_CMD_PORT
    MOV AL, PIC_EOI
    OUT DX, AL

    POP DX
    POP AX
    RET
SEND_EOI_TO_PIC ENDP

CODE_SEG ENDS
END ENTRY_POINT

