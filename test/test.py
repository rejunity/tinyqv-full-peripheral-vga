# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 12

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaces with a
    # different version that uses Risc-V instructions instead of the SPI test
    # harness interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset
    await tqv.reset()

    dut._log.info("Test project behavior")

    # Test register write and read back
    # await tqv.write_word_reg(0,  0) #x82345678)
    await tqv.write_word_reg(0,  0)
    await tqv.write_word_reg(4,  0x01010101)
    await tqv.write_word_reg(8,  0x08080808)
    await tqv.write_word_reg(12, 0x0A0A0A0A) # 128
    await tqv.write_word_reg(16, 0x0F0F0F0F)
    await tqv.write_word_reg(20, 0x10101010)
    await tqv.write_word_reg(24, 0x80808080)
    await tqv.write_word_reg(28, 0xFFFFFFFF) # 256
    await tqv.write_word_reg(32, 0x1AAAAAAA)
    await tqv.write_word_reg(36, 0x2A1A1A1A)
    await tqv.write_word_reg(40, 0x3A8A8A8A)
    await tqv.write_word_reg(44, 0x4AFAFAFA) # 320
    # await ClockCycles(dut.clk, 1)

    # assert await tqv.read_word_reg(0x0) == (0,370) # 0
    # assert await tqv.read_byte_reg(0x10) == (0,0) # 0x78
    # assert await tqv.read_hword_reg(0x10) == (0,0) # 0x5678
    # assert await tqv.read_word_reg(0x10) == (0,0) # 0x82345678

    async def measure_hsync():
        cycles_pre = 0
        out_pre = dut.uo_out.value
        while (dut.uo_out.value & 0x80 == 0x80):
            await ClockCycles(dut.clk, 1)
            cycles_pre += 1
        cycles = 0
        out_mid = dut.uo_out.value
        while (dut.uo_out.value & 0x80 != 0x80):
            await ClockCycles(dut.clk, 1)
            cycles += 1
        print("pre-hsync out:", out_pre, "cycles:", cycles_pre, "hsync out:", out_mid, "cycles:", cycles)
        return cycles
    Y=2
    assert await tqv.read_word_reg(0x0) == (Y+0,0) # 0
    await measure_hsync()

    # assert await tqv.read_word_reg(0x0) == (0,370) # 0
    assert await tqv.read_word_reg(0x0)  == (Y+1,0) # 0
    assert await tqv.read_word_reg(0x10) == (Y+1,0) # 0
    await measure_hsync()
    # assert await tqv.read_word_reg(0x0) == (1,0) # 0
    # assert await tqv.read_word_reg(0x0) == (1,539) # 0
    # assert await tqv.read_byte_reg(0x10) == (1,0) # 0x78
    assert await tqv.read_word_reg(0x0) == (Y+2,0) # 1
    # assert await tqv.read_word_reg(0x0) == (2,0) # 1
    await measure_hsync()
    assert await tqv.read_word_reg(0x0) == (Y+3,0) # 2
    await measure_hsync()
    assert await tqv.read_word_reg(0x0) == (Y+4,0) # 3
    await measure_hsync()
    # assert await tqv.read_word_reg(0x0) == (Y+5,0) # 4
    # await measure_hsync()
    # assert await tqv.read_word_reg(0x0) == (Y+6,0) # 5
    # await measure_hsync()
    # assert await tqv.read_word_reg(0x0) == (Y+7,0) # 6
    # await measure_hsync()
    # assert await tqv.read_word_reg(0x0) == (Y+8,0) # 7


    # while ((await tqv.read_word_reg(0x0))[0] < 32):
    #     # pass
    #     await measure_hsync()

    # # Set an input value, in the example this will be added to the register value
    # dut.ui_in.value = 30

    # # Wait for two clock cycles to see the output values, because ui_in is synchronized over two clocks,
    # # and a further clock is required for the output to propagate.
    # await ClockCycles(dut.clk, 3)

    # # The following assersion is just an example of how to check the output values.
    # # Change it to match the actual expected output of your module:
    # assert dut.uo_out.value == 0x96

    # # Input value should be read back from register 1
    # assert await tqv.read_byte_reg(4) == 30

    # # Zero should be read back from register 2
    # assert await tqv.read_word_reg(8) == 0

    # # A second write should work
    # await tqv.write_word_reg(0, 40)
    # assert dut.uo_out.value == 70

    # # Test the interrupt, generated when ui_in[6] goes high
    # dut.ui_in[6].value = 1
    # await ClockCycles(dut.clk, 1)
    # dut.ui_in[6].value = 0

    # # Interrupt asserted
    # await ClockCycles(dut.clk, 3)
    # assert await tqv.is_interrupt_asserted()

    # # Interrupt doesn't clear
    # await ClockCycles(dut.clk, 10)
    # assert await tqv.is_interrupt_asserted()
    
    # # Write bottom bit of address 8 high to clear
    # await tqv.write_byte_reg(8, 1)
    # assert not await tqv.is_interrupt_asserted()
