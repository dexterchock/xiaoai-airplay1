# xiaoai airplay1

High fidelity AirPlay 1 receiver (`shairport-sync`) built specifically for the Xiaomi Smart Speaker Pro (`OH2P`).

## Audio Pipeline Features

* **SoXR Sinc Interpolation**: Compiled with static `libsoxr` (`interpolation = "soxr"`) for ultra clean clock drift compensation.
* **Apple ALAC Reference Decoder**: Compiled with `libalac` (`alac_decoder = "apple"`) for bit accurate lossless 44.1 kHz 16 bit stereo decoding.
* **Cortex A53 NEON Optimization**: Built with ARMv7 NEON VFPv4 and Cortex A53 instruction tuning.
* **Tapered 60 dB Volume Curve**: Uses `dasl_tapered` volume profiling with 32 bit TPDF dithering and forces the underlying ALSA `notify` mixer to 100% unity gain.
* **Dedicated CPU Window**: Automatically pauses Xiaomi voice daemons during active AirPlay streaming and runs the audio pipeline at elevated scheduler priority (`nice -n -10`).

## Installation on Speaker

SSH into your Xiaomi Smart Speaker Pro (`OH2P`) and run:

```sh
curl -sSfL [https://fastly.jsdelivr.net/gh/dexterchock/xiaoai-airplay1@main/install.sh](https://fastly.jsdelivr.net/gh/dexterchock/xiaoai-airplay1@main/install.sh) | sh
