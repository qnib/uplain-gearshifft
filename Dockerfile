ARG DOCKER_REGISTRY=docker.io
ARG FROM_IMG_REPO=qnib
ARG FROM_IMG_NAME="uplain-init"
ARG FROM_BASE_TAG="bionic-20190612"
ARG FROM_IMG_TAG="2019-07-11"
ARG FROM_IMG_HASH=""
FROM ${DOCKER_REGISTRY}/${FROM_IMG_REPO}/${FROM_IMG_NAME}:${FROM_BASE_TAG}_${FROM_IMG_TAG}${DOCKER_IMG_HASH} AS build

ARG NUM_THREADS=2
ARG CFLAGS_MARCH="core2"
ARG CFLAGS_OPT=2

ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true
## compile_boost.sh
# boost version to download
ENV BOOST_VERSION=1.67.0
# where to download
ENV BOOST_SRC="/usr/src/boost"
# boost install dir
ENV BOOST_ROOT="/usr/local/boost"
ENV CFLAGS="-march=${CFLAGS_MARCH} -O${CFLAGS_OPT} -pipe"
ENV CXXFLAGS="${CFLAGS}"

RUN apt update \
 && apt install -y --no-install-recommends \
                build-essential \
                ca-certificates \
                cmake \
                git \
                file \
                fort77 \
                wget

WORKDIR /opt
RUN git clone https://github.com/mpicbg-scicomp/gearshifft.git
# if install dir is empty, then download && build
RUN mkdir -p ${BOOST_SRC} ${BOOST_ROOT} 
WORKDIR ${BOOST_SRC}
RUN wget -qO- "https://dl.bintray.com/boostorg/release/${BOOST_VERSION}/source/boost_$(echo ${BOOST_VERSION} |sed -e 's#\.#_#g').tar.bz2" \
 |tar xfj - -C "${BOOST_SRC}" --strip-components=1 
RUN ./bootstrap.sh --with-libraries=program_options,filesystem,system,test \
 && ./b2 --prefix="$BOOST_ROOT" -d1 install --variant=release

## compile_fftw.sh
# fftw version to download
ENV FFTW_VERS=3.3.8
# we compile in separated directories, so binaries do not clash
ENV VERS_single=${FFTW_VERS}_single
ENV VERS_double=${FFTW_VERS}_double
# the install directory for fftw and fftwf
ENV FFTW_ROOT=/usr/local/fftw/${VERS_single}
# if directories do not exist, create them and unpack fftw_**.tar.gz
WORKDIR /usr/local/fftw/${VERS_single}
RUN wget -qO- http://www.fftw.org/fftw-${FFTW_VERS}.tar.gz | tar xfz - --strip-components=1
RUN cp -r /usr/local/fftw/${VERS_single} /usr/local/fftw/${VERS_double}
ENV IFLAG_STD="--enable-static=yes --enable-shared=yes --with-gnu-ld  --enable-silent-rules --with-pic"
ENV IFLAGS="--prefix=${FFTW_ROOT} --enable-openmp --enable-sse2 -q $IFLAG_STD"
RUN ./configure $IFLAGS "--enable-single"
RUN make -j${NUM_THREADS}
RUN make install
# double
WORKDIR /usr/local/fftw/${VERS_double}
RUN ./configure $IFLAGS \
 && make -j8 \
 && make install

WORKDIR /opt/gearshifft/release
RUN export CMAKE_PREFIX_PATH==${BOOST_ROOT}/lib:${BOOST_ROOT}/include:${CMAKE_PREFIX_PATH} \
 && cmake -DCMAKE_INSTALL_PREFIX=/usr/local/gearshifft ..
RUN make -j ${NUM_THREADS} install
ENV LD_LIBRARY_PATH=/usr/local/fftw/${FFTW_VERS}_single/lib/

FROM ${DOCKER_REGISTRY}/ubuntu:${FROM_BASE_TAG}
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true
ENV LD_LIBRARY_PATH=/usr/local/fftw/lib/
###
RUN apt-get update \
 && apt-get install --no-install-recommends -y libgomp1 \
 && rm -rf /var/cache
## COPY boost
COPY --from=build /usr/local/boost /usr/local/boost
## COPY fftw
COPY --from=build /usr/local/fftw/3.3.8_single /usr/local/fftw
COPY --from=build /opt/gearshifft/release/gearshifft/gearshifft_fftw /usr/bin/
COPY --from=build /opt/gearshifft/share/gearshifft/extents.conf /opt/gearshifft/share/gearshifft/extents.conf
CMD ["gearshifft_fftw", "--run-benchmarks", "Fftw/float/512x512/Inplace_Real"]