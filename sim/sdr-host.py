import numpy as np
import serial
import serial.tools.list_ports
import queue
import threading
import tkinter as tk

import matplotlib
import matplotlib.pyplot as plt
from matplotlib.figure import Figure
matplotlib.use("TkAgg")
from matplotlib.backends.backend_tkagg import (
    FigureCanvasTkAgg,
    NavigationToolbar2Tk    
)

class App:
    def __init__(self):
        ftdi_device = None
        for comport in serial.tools.list_ports.comports():
            if comport.vid == 0x0403 and comport.pid == 0x6010:
                ftdi_device = comport.device
        if not ftdi_device:
            print("ftdi device not found")
            exit(1)
        self.serial_if = serial.Serial(port=ftdi_device, baudrate=1000000, timeout=1)

        self.dsp_fs = 1_000_000
        self.baseband_fs = 20_000
        self.lo_freq = 100_000  # Hz
        self.mixer_atten = 0    # dB
        self.if_atten = 0   # dB
        self.demod_atten = 0    # dB
        self.param_led = 0

        self.window = tk.Tk()

        self.lbl_lo_freq = tk.Label(text="LO Freq [kHz]:", anchor="e")
        self.spn_lo_freq = tk.Spinbox(from_=0, to=499)
        self.lbl_mixer_atten = tk.Label(text="Mixer atten. [/2**x]:", anchor="e")
        self.spn_mixer_atten = tk.Spinbox(from_=0, to=31)
        self.lbl_if_atten = tk.Label(text="IF atten. [/2**x]:", anchor="e")
        self.spn_if_atten = tk.Spinbox(from_=0, to=31)
        self.lbl_demod_atten = tk.Label(text="Demod. atten. [/2**x]:", anchor="e")
        self.spn_demod_atten = tk.Spinbox(from_=0, to=15)
        self.lbl_param_led = tk.Label(text="Param. LED:", anchor="e")
        self.spn_param_led = tk.Spinbox(from_=0, to=1)
        self.btn_save = tk.Button(text="Save")

        self.lbl_lo_freq.grid(row=0, column=0, sticky="nesw")
        self.spn_lo_freq.grid(row=0, column=1, sticky="nesw")
        self.lbl_mixer_atten.grid(row=1, column=0, sticky="nesw")
        self.spn_mixer_atten.grid(row=1, column=1, sticky="nesw")
        self.lbl_if_atten.grid(row=2, column=0, sticky="nesw")
        self.spn_if_atten.grid(row=2, column=1, sticky="nesw")
        self.lbl_demod_atten.grid(row=3, column=0, sticky="nesw")
        self.spn_demod_atten.grid(row=3, column=1, sticky="nesw")
        self.lbl_param_led.grid(row=4, column=0, sticky="nesw")
        self.spn_param_led.grid(row=4, column=1, sticky="nesw")
        self.btn_save.grid(row=5, column=1, sticky="nesw")
        self.window.grid_columnconfigure(0, weight=0)
        self.window.grid_columnconfigure(1, weight=1)
        self.window.grid_rowconfigure(0, weight=1)
        self.window.grid_rowconfigure(1, weight=1)
        self.window.grid_rowconfigure(2, weight=1)
        self.window.grid_rowconfigure(3, weight=1)
        self.window.grid_rowconfigure(4, weight=1)
        self.window.grid_rowconfigure(5, weight=1)

        self.btn_save.bind("<Button-1>", self.on_btn_save_click)

        self.plot_window = tk.Toplevel()
        plt.ion()
        self.buf_len = 2048
        self.figure_1 = Figure()
        self.ax_1 = self.figure_1.add_subplot(211)
        self.ax_1.set_ylim(0, 255)
        self.ax_1.grid()
        self.line_1, = self.ax_1.plot(np.arange(self.buf_len), np.zeros(self.buf_len))
        self.ax_2 = self.figure_1.add_subplot(212)
        self.ax_2.set_ylim(-50, 50)
        self.ax_2.grid()
        self.line_2, = self.ax_2.plot(np.zeros(self.buf_len))
        self.canvas_1 = FigureCanvasTkAgg(self.figure_1, master=self.plot_window)
        self.canvas_1.draw()
        self.toolbar_1 = NavigationToolbar2Tk(self.canvas_1, self.plot_window)
        self.toolbar_1.update()
        self.canvas_1.get_tk_widget().pack(expand=1, fill="both")

        self.window.protocol("WM_DELETE_WINDOW", self.on_closing)

        self.running = threading.Event()
        self.rx_queue = queue.Queue(10)
        self.rx_thread = threading.Thread(target=self.rx_main)


    def on_closing(self):
        self.running.clear()
        self.window.destroy()

    def rx_main(self):
        buf = bytearray(self.buf_len)
        ydata = np.zeros(self.buf_len)
        while self.running.is_set():
            try:
                r = self.serial_if.readinto(buf)
            except Exception:
                continue
            if r < self.buf_len:
                print(f"read underrun: {r}")
                continue
            for i, x in enumerate(buf):
                    ydata[i] = np.float64(x)
            try:
                self.rx_queue.put(ydata, timeout=1)
            except queue.Full:
                print("write overrun")

    def plot_main(self):
        fdata = np.zeros(self.buf_len)
        if self.running.is_set():
            try:
                ydata = self.rx_queue.get(timeout=1)
                fdata = 20 * np.log10(np.abs(np.fft.fft(ydata) / self.buf_len))
                self.line_1.set_ydata(ydata)
                self.line_2.set_ydata(fdata)
                self.canvas_1.draw()
                self.canvas_1.flush_events()
            except queue.Empty:
                pass
            self.window.after("idle", self.plot_main)

    def tx_cmd(self, addr, val):
        buf = bytearray(2)
        buf[0] = addr
        buf[1] = val
        self.serial_if.write(buf)

    def on_btn_save_click(self, e):
        self.lo_freq = int(self.spn_lo_freq.get())
        self.mixer_atten = int(self.spn_mixer_atten.get())
        self.if_atten = int(self.spn_if_atten.get())
        self.demod_atten = int(self.spn_demod_atten.get())
        self.param_led = int(self.spn_param_led.get())
        print(self.lo_freq, self.mixer_atten, self.if_atten, self.demod_atten, self.param_led)
        pha_inc = int((2 ** 32) * (self.lo_freq * 1000 / self.dsp_fs))
        self.tx_cmd(0x00, (pha_inc      ) & 0xFF)
        self.tx_cmd(0x01, (pha_inc >> 8 ) & 0xFF)
        self.tx_cmd(0x02, (pha_inc >> 16) & 0xFF)
        self.tx_cmd(0x03, (pha_inc >> 24) & 0xFF)
        self.tx_cmd(0x04, self.mixer_atten)
        self.tx_cmd(0x08, self.if_atten)
        self.tx_cmd(0x0C, self.demod_atten)
        self.tx_cmd(0x10, self.param_led)
        self.tx_cmd(0xFF, 0)

    def run(self):
        try:
            self.running.set()
            self.rx_thread.start()
            self.window.after(100, self.plot_main)
            self.window.mainloop()
        finally:
            self.running.clear()
            self.rx_thread.join()


if __name__ == "__main__":
    app = App()
    app.run()