import numpy as np
import scipy.signal as sig
import matplotlib.pyplot as plt
import sys

def dump_fir(fout, coeff, bitwidth, scale=1):
    assert bitwidth == 16
    for i in range(len(coeff) - 1, -1, -1):
        c = int(coeff[i] * scale)
        lo_byte = (c & 0xFF)
        hi_byte = (c >> 8) & 0xFF
        fout.write(f"{hi_byte:02X}{lo_byte:02X}")

def plot_signal(name, fs, n, t, x):
    fig, (ax_t, ax_f) = plt.subplots(2, 1)
    ax_t.set_title(f"{name} time")
    if x.dtype == np.complex_:
        ax_t.step(t, x.real)
        ax_t.step(t, x.imag)
    else:
        ax_t.step(t, x)
    ax_f.set_title(f"{name} freq")
    fft_out = np.fft.fft(x)
    ax_f.plot(np.fft.fftfreq(n, 1.0/fs), 20 * np.log10(np.abs(fft_out)), linewidth=1)
    fig.tight_layout()

def plot_fir_response(name, fs, coeffs):
    w, h = sig.freqz(coeffs)
    _, (ax_t, ax_f) = plt.subplots(2, 1)
    ax_t.set_title("decim resp time")
    ax_t.plot(coeffs, "x--", linewidth=1)
    ax_t.grid()
    ax_f.set_title("decim resp freq")
    ax_f.semilogx(w * fs / 6.28, 20*np.log10(np.abs(h)))
    ax_f.grid()

if __name__ == "__main__":
    fs = 1000000
    fs_out = 20000
    nyq_rate = fs / 2
    bw_ch = fs_out / 2
    test_t = 0.05
    test_fc = 250000
    test_fm = 100
    throw_lsb_mixer = 11
    throw_lsb_if = 19
    throw_lsb_demod = 7

    scale = (1 << 21)

    decim_k = int(fs / fs_out)
    fir_if = np.int16(scale * sig.firwin(512, 5000/nyq_rate, window=("kaiser", sig.kaiser_beta(60))))

    print(f"decim: {decim_k}")
    with open("fir_if_coeff.txt", "w") as f:
        dump_fir(f, fir_if, 16)

    if len(sys.argv) > 1:
        # dont do response test run
        exit(0)

    plot_fir_response("fir_if", fs, fir_if)

    # test data
    n = int(test_t * fs)
    t = np.linspace(0, test_t, n)
    x = 0
    x += 100 * np.random.rand(n)
    x += 1000 * ((0.5 + 0.4 * np.sin(2 * np.pi * test_fm * t)) * (np.cos(2 * np.pi * (test_fc) * t)))
    x += 100 * np.cos(2 * np.pi * 50000 * t)
    print("max x", max(abs(x)))
    
    # plot samples
    plot_signal("x", fs, n, t, x)

    # do mixing zero-if
    lo = (1 << 15) * np.exp(2j * np.pi * (np.random.randn(n)-test_fc) * t)
    y = x * lo
    y = np.int16(np.int64(np.real(y)) / (1 << throw_lsb_mixer)) + 1j * np.int16(np.int64(np.imag(y)) / (1 << throw_lsb_mixer))
    print("y mixer", np.max(np.abs(y)))

    # plot mixer
    plot_signal("mixer", fs, n, t, y)

    # apply if filter
    y = sig.lfilter(fir_if, [1], y)
    y = np.int16(np.int64(np.real(y)) / (1 << throw_lsb_if)) + 1j * np.int16(np.int64(np.imag(y)) / (1 << throw_lsb_if))
    print("y if filt", np.max(np.abs(y)))

    # plot if
    plot_signal("if", fs, n, t, y)

    # demod
    z = np.uint16(np.int64(np.abs(y)) / (1 << throw_lsb_demod))
    print("z demod", np.max(np.abs(z)))
    
    # plot demod
    plot_signal("demod", fs, n, t, z)

    # filter and decimate
    n_out = int(n / decim_k)
    t_out = np.linspace(0, test_t, n_out)
    z = np.uint8(z)
    z_out = z[::decim_k]
    print("z decim", np.max(np.abs(z_out)))

    # plot time domain out
    plot_signal("decim", fs_out, n_out, t_out, z_out)

    plt.tight_layout()
    plt.show()
