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


# Tiny Tapeout 20x16
TINY_TAPEOUT_20x16 = int(
    "                    "
    "   OOOOO            "
    "     O              "
    "     O O            "
    "     O   OO O O     "
    "     O O O O OO     "
    "     O O O O  O     "
    "             O      "
    "OOOO              O "
    " O       OO     OOOO"
    " O O OO O   OO    O "
    " OO OO OOO O  OO OO "
    " OOOOO OO  O  OO OO "
    " OO OOO OOO OO OOO O"
    "     O              "
    "     O              ".replace(" ","0").replace("O","1"),
    2
)

def bit_slice(num: int, hi: int, lo: int) -> int:
    """
    Extract bits from a Python int like Verilog's x[hi:lo].
    Bit 0 is the least significant bit.
    """
    if hi < lo:
        raise ValueError("hi must be >= lo")
    width = hi - lo + 1
    mask = (1 << width) - 1
    return (num >> lo) & mask

# Tiny Tapeout 20x16 -> 32bit
# TINY_TAPEOUT_20x16 = [  0b00000000000000000000000111110000,
#                         0b00000000000001000000000000000000,
#                         0b01010000000000000000010001101010,
#                         0b00000000010101010110000000000101,
#                         0b01010010000000000000000001000000,
#                         0b11110000000000000010010000000110,
#                         0b00001111010101101000110000100110,
#                         0b11011101001101100111110110010011,
#                         0b01100110111011101101110100000100,
#                         0b00000000000000000100000000000000 ]


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
    # await tqv.write_word_reg(0,  0)
    # await tqv.write_word_reg(4,  0x01010101)
    # await tqv.write_word_reg(8,  0x08080808)
    # await tqv.write_word_reg(12, 0x0A0A0A0A) # 128
    # await tqv.write_word_reg(16, 0x0F0F0F0F)
    # await tqv.write_word_reg(20, 0x10101010)
    # await tqv.write_word_reg(24, 0x80808080)
    # await tqv.write_word_reg(28, 0xFFFFFFFF) # 256
    # await tqv.write_word_reg(32, 0x1AAAAAAA) # 288
    # await tqv.write_word_reg(36, 0x2A1A1A1A) # 320

    for reg32 in range(10):
        await tqv.write_word_reg(reg32*4, bit_slice(TINY_TAPEOUT_20x16, reg32*32 + 31, reg32*32))

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


    Y=3
    await measure_hsync()
    await ClockCycles(dut.clk, 1024-30)
    assert await tqv.read_word_reg(0x0) == Y+0  #0
    await measure_hsync()
    assert await tqv.read_word_reg(0x10) == Y+1 #0

    await ClockCycles(dut.clk, 1024-260-40)
    assert await tqv.read_word_reg(0x0)  == Y+1 #1
    await measure_hsync()
    assert await tqv.read_word_reg(0x10) == Y+2 #1

    await ClockCycles(dut.clk, 1024-260-60)
    assert await tqv.read_word_reg(0x0)  == Y+2
    await measure_hsync()
    assert await tqv.read_word_reg(0x10) == Y+3

    await ClockCycles(dut.clk, 1024-260-80)
    assert await tqv.read_word_reg(0x0)  == Y+3
    await measure_hsync()
    assert await tqv.read_word_reg(0x10) == Y+4

    return

    # await tqv.write_word_reg(60, 0b0100_0000) # color mode
    # await tqv.read_word_reg(0x0)
    # await measure_hsync()

    while (await tqv.read_word_reg(0x0) < 64):
        await measure_hsync()
        y = await tqv.read_word_reg(0x10)
        if (y % 16 == 0):
            print(y)

    await tqv.write_word_reg(60, 0b0100_0000) # color mode

    while (await tqv.read_word_reg(0x0) < 128):
        await measure_hsync()
        y = await tqv.read_word_reg(0x10)
        if (y % 16 == 0):
            print(y)

    await tqv.write_word_reg(52, ((3-1)<<16) | (960//320-1)) # pixel size
    await tqv.write_word_reg(56, 320) # vram stride
    await tqv.write_word_reg(60, 0b0110_0000) # color + 960 mode

    while (await tqv.read_word_reg(0x0) < 140):
        await measure_hsync()
        y = await tqv.read_word_reg(0x10)
        if (y % 16 == 0):
            print(y)

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
