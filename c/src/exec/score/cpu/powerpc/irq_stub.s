/*  irq_stub.s	1.0 - 95/08/08
 *
 *  This file contains the interrupt handler assembly code for the PowerPC
 *  implementation of RTEMS.  It is #included from cpu_asm.s.
 *
 *  Author:	Andrew Bray <andy@i-cubed.demon.co.uk>
 *
 *  COPYRIGHT (c) 1995 by i-cubed ltd.
 *
 *  To anyone who acknowledges that this file is provided "AS IS"
 *  without any express or implied warranty:
 *      permission to use, copy, modify, and distribute this file
 *      for any purpose is hereby granted without fee, provided that
 *      the above copyright notice and this notice appears in all
 *      copies, and that the name of i-cubed limited not be used in
 *      advertising or publicity pertaining to distribution of the
 *      software without specific, written prior permission.
 *      i-cubed limited makes no representations about the suitability
 *      of this software for any purpose.
 *
 *  $Id$
 */

/*  void __ISR_Handler()
 *
 *  This routine provides the RTEMS interrupt management.
 *  The vector number is in r0. R0 has already been stacked.
 *
 */
	/* Finish off the interrupt frame */
	stw	r2, IP_2(r1)
	stw	r3, IP_3(r1)
	stw	r4, IP_4(r1)
	stw	r5, IP_5(r1)
	stw	r6, IP_6(r1)
	stw	r7, IP_7(r1)
	stw	r8, IP_8(r1)
	stw	r9, IP_9(r1)
	stw	r10, IP_10(r1)
	stw	r11, IP_11(r1)
	stw	r12, IP_12(r1)
	stw	r13, IP_13(r1)
	stmw	r28, IP_28(r1)
	mfcr	r5
	mfctr	r6
	mfxer	r7
	mflr	r8
	mfsrr0	r9
	mfsrr1	r10
	/* Establish addressing */
	mfsprg3	r11
	dcbt	r0, r11
	stw	r5, IP_CR(r1)
	stw	r6, IP_CTR(r1)
	stw	r7, IP_XER(r1)
	stw	r8, IP_LR(r1)
	stw	r9, IP_PC(r1)
	stw	r10, IP_MSR(r1)

	lwz	r30, Vector_table(r11)
	slwi	r4,r0,2
	lwz	r28, Nest_level(r11)
	add	r4, r4, r30
	
	lwz	r30, 0(r28)
	mr	r3, r0
	lwz	r31, Stack(r11)
  /*
   *  #if ( CPU_HAS_SOFTWARE_INTERRUPT_STACK == TRUE )
   *    if ( _ISR_Nest_level == 0 )
   *      switch to software interrupt stack
   *  #endif
   */
	/* Switch stacks, here we must prevent ALL interrupts */
	cmpwi	r30, 0
	lwz	r29, Disable_level(r11)
	subf	r31,r1,r31
	bne	LABEL (nested)
	stwux	r1,r1,r31
LABEL (nested):
  /*
   *  _ISR_Nest_level++;
   */
	lwz	r31, 0(r29)
	addi	r30,r30,1
	stw	r30,0(r28)
	/* From here on out, interrupts can be re-enabled. RTEMS
	 * convention says not.
	 */
	lwz	r4,0(r4)
  /*
   *  _Thread_Dispatch_disable_level++;
   */
	addi	r31,r31,1
	stw	r31, 0(r29)
  /*
   *  (*_ISR_Vector_table[ vector ])( vector );
   */
#if (PPC_ABI == PPC_ABI_POWEROPEN)
	lwz	r6,0(r4)
	lwz	r2,4(r4)
	mtlr	r6
	lwz	r11,8(r4)
#endif
#if (PPC_ABI == PPC_ABI_GCC27)
	lwz	r2, Default_r2(r11)
	mtlr	r4
	lwz	r2, 0(r2)
#endif
#if (PPC_ABI == PPC_ABI_SVR4 || PPC_ABI == PPC_ABI_EABI)
	mtlr	r4
	lwz	r2, Default_r2(r11)
	lwz	r13, Default_r13(r11)
	lwz	r2, 0(r2)
	lwz	r13, 0(r13)
#endif
	mr	r4,r1
	blrl
	/* NOP marker for debuggers */
	or	r6,r6,r6

	/*	We must re-disable the interrupts */
	mfsprg3	r11
	mfsprg2 r0
	mtmsr   r0

  /*
   *  if (--Thread_Dispatch_disable,--_ISR_Nest_level)
   *    goto easy_exit;
   */
	addi	r30, r30, -1
	cmpwi	r30, 0
	addi	r31, r31, -1
	stw	r30, 0(r28)
	stw	r31, 0(r29)
	bne	LABEL (easy_exit)

	lwz	r30, Switch_necessary(r11)

  /*
   *  #if ( CPU_HAS_SOFTWARE_INTERRUPT_STACK == TRUE )
   *    restore stack
   *  #endif
   */
	lwz	r1,0(r1)
	lwz	r30, 0(r30)
	lwz	r31, Signal(r11)
	
  /*  
   *  if ( _Context_Switch_necessary )
   *    goto switch
   */
	cmpwi	r30, 0
	lwz	r28, 0(r31)
	bne	LABEL (switch)
  /*  
   *  if ( !_ISR_Signals_to_thread_executing )
   *    goto easy_exit
   *  _ISR_Signals_to_thread_executing = 0;
   */
	cmpwi	r28, 0
	li	r6,0
	beq	LABEL (easy_exit)
	stw	r6, 0(r31)

  /*
   * switch:
   *  call _Thread_Dispatch() or prepare to return to _ISR_Dispatch
   */
LABEL (switch):
#if (PPC_ABI == PPC_ABI_POWEROPEN)
	lwz	r2, Dispatch_r2(r11)
#else
	/* R2 and R13 still hold their values from the last call */
#endif
	bl	PROC (_Thread_Dispatch)
	/* NOP marker for debuggers */
	or	r6,r6,r6
  /*
   *  prepare to get out of interrupt
   */
	/* Re-disable IRQs */
	mfsprg2 r0
	mtmsr   r0
  /*
   *  easy_exit:
   *  prepare to get out of interrupt
   *  return from interrupt
   */
LABEL (easy_exit):
	lwz	r5, IP_CR(r1)
	lwz	r6, IP_CTR(r1)
	lwz	r7, IP_XER(r1)
	lwz	r8, IP_LR(r1)
	lwz	r9, IP_PC(r1)
	lwz	r10, IP_MSR(r1)
	mtcrf	255,r5
	mtctr	r6
	mtxer	r7
	mtlr	r8
	mtsrr0	r9
	mtsrr1	r10
	lwz	r0, IP_0(r1)
	lwz	r2, IP_2(r1)
	lwz	r3, IP_3(r1)
	lwz	r4, IP_4(r1)
	lwz	r5, IP_5(r1)
	lwz	r6, IP_6(r1)
	lwz	r7, IP_7(r1)
	lwz	r8, IP_8(r1)
	lwz	r9, IP_9(r1)
	lwz	r10, IP_10(r1)
	lwz	r11, IP_11(r1)
	lwz	r12, IP_12(r1)
	lwz	r13, IP_13(r1)
	lmw	r28, IP_28(r1)
	lwz	r1, 0(r1)
