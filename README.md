max1k-sdr-ds
==

V2 of MAX1K SDR project [here](https://github.com/fyazici/max1k-sdr-rtl).

Direct sampling method is used in this project. Onboard ADC of MAX1K has 1 Msps for sampling rate but datasheet claims a few MHz of analog bandwidth, and thus harmonic sampling, is possible. RTL, simulation scripts and a preliminary GUI software is provided in this repository. Although direct sampling is used, it still needs a proper RF frontend including a PA and a bandpass filter, possibly with band selector.
