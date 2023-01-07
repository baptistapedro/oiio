FROM ubuntu:22.04 as builder

RUN ln -snf /usr/share/zoneinfo/$CONTAINER_TIMEZONE /etc/localtime && echo $CONTAINER_TIMEZONE > /etc/timezone

RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update && apt-get install -y build-essential wget git clang cmake  automake autotools-dev libtool zlib1g zlib1g-dev libexif-dev \
	python3 python2 python3-pip libboost-all-dev clang-format python3-pybind11 libopenexr25 openexr libopenexr-dev afl++ libtiff-dev libjpeg-dev

ADD . /oiio
WORKDIR /oiio
RUN OPENEXR_INSTALL_DIR=/usr/local ./src/build-scripts/build_openexr.bash
RUN mkdir ./build
WORKDIR ./build
RUN cmake -DBoost_ROOT=/usr/lib/x86_64-linux-gnu -DZLIB_ROOT=/usr/lib/x86_64-linux-gnu \
-DCMAKE_CXX_FLAGS='-Wno-error=unused-variable' -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++  -DBUILD_SHARED_LIBS=ON ..
RUN make 
RUN mkdir ./corpus
RUN wget https://web.stanford.edu/class/ee398a/data/image/airfield512x512.tif
RUN wget https://web.stanford.edu/class/ee398a/data/image/boats512x512.tif
RUN wget https://web.stanford.edu/class/ee398a/data/image/bridge512x512.tif
RUN wget https://web.stanford.edu/class/ee398a/data/image/cman.tif
RUN wget https://web.stanford.edu/class/ee398a/data/image/smandril.tif
RUN mv *.tif ./corpus

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y afl++
COPY --from=builder /oiio/build/bin/oiiotool  /
COPY --from=builder /oiio/build/corpus/*.tif  /testsuite/
COPY --from=builder /usr/local/lib/*          /usr/local/lib/

# Copy dependencies .so files	
COPY --from=builder /oiio/build/lib/* /usr/local/lib/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libboost* /usr/local/lib/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libz* /usr/local/lib/

# Find deps shared objects
ENV LD_LIBRARY_PATH=/usr/local/lib

ENTRYPOINT ["afl-fuzz", "-m", "2048", "-i", "/testsuite", "-o", "/oiiotoolOut"]
CMD ["/oiiotool", "@@", "-o", "/dev/null"] 
