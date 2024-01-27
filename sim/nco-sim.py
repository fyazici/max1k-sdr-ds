import numpy as np
import matplotlib.pyplot as plt

pha_width = 32
ang_width = 15
mag_width = 16

def plot_signal(name, fs, n, t, x):
    fig, (ax_t, ax_f) = plt.subplots(2, 1)
    ax_t.set_title(f"{name} time")
    ax_t.grid()
    if x.dtype == np.complex_:
        ax_t.step(t, x.real)
        ax_t.step(t, x.imag)
    else:
        ax_t.step(t, x)
    ax_f.set_title(f"{name} freq")
    fft_out = np.fft.fft(x) / n
    ax_f.plot(np.fft.fftfreq(n, 1.0/fs), 20 * np.log10(np.abs(fft_out)), linewidth=1)
    print(np.abs(fft_out[n//10]) / np.abs(fft_out[104*n//1000]))
    fig.tight_layout()

if __name__ == "__main__":
    lut = np.int32(np.cos(np.linspace(0, 2*np.pi, 2 ** ang_width)) * (2 ** (mag_width - 1) - 1))
    fs = 1000000
    fc = 100000
    n = 1024
    pha_inc = int(np.floor((2 ** pha_width) / (fs / fc)))
    print(f"{pha_inc:08x}")
    t = np.arange(n)
    x = np.zeros(n, dtype=np.int32)
    pha = 0
    for i in range(n):
        ang = int(np.floor(pha / (2 ** (pha_width - ang_width))))
        x[i] = lut[ang % len(lut)]
        pha += pha_inc
    plot_signal("x", fs, n, t, x)
    plt.show()