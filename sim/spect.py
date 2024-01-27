import numpy as np
import matplotlib.pyplot as plt
import sys

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
    fig.tight_layout()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        x = np.loadtxt(sys.argv[1], delimiter=",", skiprows=135, usecols=(2, 19))
        x = x[:, 0] + 1j * x[:, 1]
    else:
        x = np.loadtxt(sys.argv[1], delimiter=",", skiprows=134, usecols=(2,))
    fs = 1000000
    n = x.shape[0]
    t = np.linspace(0, n / fs, n)
    plot_signal("x", fs, n, t, x / 32768)
    plt.show()
