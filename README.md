# uplain-gearshifft
gearshifft FFTW benchmark

## Goal

The goal is to split the build up into multiple images (potentially) and allow for different target platforms to be uniquely build for (CPU micro-arch, GPUs, ...). 

## Multi-stage build

The Dockerfile uses two stages to first build BOOST, FFTW and gearshift with all dependencies present.

```
apt install -y --no-install-recommends \
                build-essential \
                ca-certificates \
                cmake \
                git \
                file \
                fort77 \
                wget
```

The second stage uses a plain ubuntu image to only hold the compiled binaries and libraries.

```
RUN apt-get update \
 && apt-get install -y libgomp1 \
 && rm -rf /var/cache
## COPY boost
COPY --from=build /usr/local/boost /usr/local/boost
## COPY fftw
COPY --from=build /usr/local/fftw/3.3.8_single /usr/local/fftw
COPY --from=build /opt/gearshifft/release/gearshifft/gearshifft_fftw /usr/bin/
COPY --from=build /opt/gearshifft/share/gearshifft/extents.conf /opt/gearshifft/share/gearshifft/extents.conf
CMD ["gearshifft_fftw", "--run-benchmarks", "Fftw/float/512x512/Inplace_Real"]
```