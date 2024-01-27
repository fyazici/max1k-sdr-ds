#!/bin/sh

# exit immediately if any command fails
set -e

if ! [ -f "$1.vhd" ]; then
    echo "Top level file $1.vhd does not exist"
    exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Invalid arguments"
    echo "usage: sim.sh {top-level} {stop-time}"
    echo "ex: sim.sh tb_top 100us"
    exit 2
fi

TOPLEVEL="$1"
STOPTIME="$2"

SRCS="$1.vhd ../src/top.vhd pll_0_sim.vhd ../src/dsp_fir.vhd ../src/dsp_cplx_abs.vhd ../src/dsp_mixer.vhd ../src/dsp_decim.vhd ../src/dsp_nco.vhd ../src/dsp_atten.vhd ../src/dbg_aligner.vhd ../src/uart_rx.vhd ../src/uart_tx.vhd ../src/param_ctl.vhd ../src/adc_ctl.vhd ../src/reset_ctl.vhd"
LIBFLAGS="-P./adc_0"
CFLAGS+="-O2"
VCDOUT="./out/${TOPLEVEL%.*}.vcd"

echo "compiling adc_0 into ./adc_0"
mkdir -p adc_0
ghdl -i --std=08 --workdir=adc_0 $CFLAGS --work=adc_0 adc_0_sim.vhd
ghdl -m --std=08 --workdir=adc_0 $CFLAGS --work=adc_0 adc_0

echo "compiling $TOPLEVEL into ./work"
mkdir -p work
ghdl -i --std=08 --workdir=work $LIBFLAGS $CFLAGS $SRCS
ghdl -m --std=08 --workdir=work $LIBFLAGS $CFLAGS $TOPLEVEL

echo "running $TOPLEVEL for duration $STOPTIME"
echo "outputs will be saved to $VCDOUT"
mkdir -p out
ghdl -r --std=08 --workdir=work $LIBFLAGS $CFLAGS $TOPLEVEL --stop-time=$STOPTIME --vcd=$VCDOUT
