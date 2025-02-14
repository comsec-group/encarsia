# Copyright 2023 Flavien Solt and Matej Bölcskei, ETH Zurich.
# Licensed under the General Public License, Version 3.0, see LICENSE for details.
# SPDX-License-Identifier: GPL-3.0-only

FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl gnupg apt-utils && \
    apt-get install -y apt-transport-https curl gnupg git perl python3 make autoconf g++ flex bison ccache libgoogle-perftools-dev numactl perl-doc libfl2 libfl-dev zlib1g zlib1g-dev \
    autoconf automake autotools-dev libmpc-dev libmpfr-dev libgmp-dev gawk build-essential \
    bison flex texinfo gperf libtool patchutils bc zlib1g-dev git perl python3 python3.10-venv make g++ libfl2 \
    libfl-dev zlib1g zlib1g-dev git autoconf flex bison gtkwave clang \
    tcl-dev libreadline-dev jq libexpat-dev device-tree-compiler vim \
    software-properties-common default-jdk default-jre gengetopt patch diffstat texi2html subversion chrpath wget libgtk-3-dev gettext python3-pip python3.8-dev rsync libguestfs-tools expat \
    libexpat1-dev libusb-dev libncurses5-dev cmake help2man && \
    apt-get install apt-transport-https curl gnupg -yqq

RUN add-apt-repository -y ppa:openjdk-r/ppa && \
    apt-get install -y openjdk-8-jre && update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java 111111 && \
    apt-get install -y openjdk-8-jdk && update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac 111111 && \
    echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list && \
    echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list && \
    curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import && \
    chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg && \
    apt-get update && apt-get install sbt

# Install oh my zsh and some convenience plugins
RUN apt-get install -y zsh && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
RUN sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' /root/.zshrc

# Install RISC-V toolchain
RUN apt-get install -y autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build
ENV RISCV="/opt/riscv"
RUN git clone https://github.com/riscv/riscv-gnu-toolchain
RUN cd riscv-gnu-toolchain && git checkout 2023.06.09 && ./configure --prefix=/opt/riscv --enable-multilib && make -j 200
ENV PATH="$PATH:/opt/riscv/bin"

# Install spike
RUN git clone https://github.com/riscv-software-src/riscv-isa-sim.git
RUN cd riscv-isa-sim && mkdir build && cd build && ../configure --prefix=$RISCV && make -j 200 && make install

# Some environment variables
ENV PREFIX_CASCADE="$HOME/prefix-cascade"
ENV CARGO_HOME=$PREFIX_CASCADE/.cargo
ENV RUSTUP_HOME=$PREFIX_CASCADE/.rustup

ENV RUSTEXEC="$CARGO_HOME/bin/rustc"
ENV RUSTUPEXEC="$CARGO_HOME/bin/rustup"
ENV CARGOEXEC="$CARGO_HOME/bin/cargo"

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Install Morty
RUN $CARGOEXEC install --force morty --root $PREFIX_CASCADE

# Install Bender
RUN $CARGOEXEC install --force bender --root $PREFIX_CASCADE

# Install fusesoc
RUN pip3 install fusesoc

# Install stack
RUN curl -sSL https://get.haskellstack.org/ | sh

# Install sv2v
RUN git clone https://github.com/zachjs/sv2v.git && cd sv2v && git checkout v0.0.11 && make -j 200 && mkdir -p $PREFIX_CASCADE/bin/ && cp bin/sv2v $PREFIX_CASCADE/bin

# Install some Python dependencies
RUN pip3 install tqdm

# Install makeelf
RUN git clone https://github.com/flaviens/makeelf && cd makeelf && git checkout finercontrol && python3 setup.py install

# Install miniconda
RUN mkdir -p miniconda && wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda/miniconda.sh \
		&& cd miniconda/ && bash miniconda.sh -u -b -p $PREFIX_CASCADE/miniconda \
		&& $PREFIX_CASCADE/miniconda/bin/conda update -y -n base -c defaults conda \
		&& $PREFIX_CASCADE/miniconda/bin/conda config --add channels conda-forge \
		&& $PREFIX_CASCADE/miniconda/bin/conda config --set channel_priority strict

# Install Verilator
RUN git clone https://github.com/verilator/verilator && cd verilator && git checkout v5.006 && autoconf && ./configure && make -j 200 && make install

# Install Yosys
RUN git clone https://github.com/encarsia-artifacts/encarsia-yosys.git /encarsia-yosys
RUN cd encarsia-yosys && make -j 200 && make install

##
# Design repositories
##

RUN echo "Cloning the repositories!"

RUN git clone https://github.com/cascade-artifacts-designs/cascade-chipyard
# Initialize the chipyard repository
RUN bash -c "cd cascade-chipyard && git branch stable && CASCADE_JOBS=250 scripts/init-submodules-no-riscv-tools.sh -f"
# Make sure to fix the BOOM bug
RUN sed -i 's/r_buffer_fin.rm := io.fcsr_rm/r_buffer_fin.rm := Mux(ImmGenRm(io.req.bits.uop.imm_packed) === 7.U, io.fcsr_rm, ImmGenRm(io.req.bits.uop.imm_packed))/' /cascade-chipyard/generators/boom/src/main/scala/exu/execution-units/fdiv.scala

RUN git clone https://github.com/encarsia-artifacts/encarsia-cascade.git --recursive
# Set the design repo locations correctly for the Docker environment
COPY design_repos.json /encarsia-cascade/design-processing/design_repos.json

ENV PATH="$PATH:$PREFIX_CASCADE/bin"

# Make sure that the Chipyard will support supervisor mode
RUN sed -i 's/useSupervisor: Boolean = false,/useSupervisor: Boolean = true,/' /cascade-chipyard/generators/boom/src/main/scala/common/parameters.scala
RUN sed -i 's/r_buffer_fin.rm := io.fcsr_rm,/r_buffer_fin.rm := Mux(ImmGenRm(io.req.bits.uop.imm_packed) === 7.U, io.fcsr_rm, ImmGenRm(io.req.bits.uop.imm_packed))/' /cascade-chipyard/generators/boom/src/main/scala/exu/execution-units/fdiv.scala
COPY config-mixins.scala /cascade-chipyard/generators/boom/src/main/scala/common

# Make all non-instrumented designs for Verilator (and the transparently instrumented for bug Y1)
RUN bash -c "source /encarsia-cascade/env.sh && cd /encarsia-cascade/design-processing && python3 -u make_all_designs.py"
# A second time to be sure
RUN bash -c "source /encarsia-cascade/env.sh && cd /encarsia-cascade/design-processing && python3 -u make_all_designs.py"

RUN git clone https://github.com/encarsia-artifacts/encarsia-ibex.git /encarsia-ibex

RUN pip3 uninstall -y edalize fusesoc && pip3 install mako git+https://github.com/lowRISC/edalize.git@ot git+https://github.com/lowRISC/fusesoc.git@ot
RUN git clone https://github.com/encarsia-artifacts/encarsia-cellift.git --recursive
COPY cellift_design_repos.json /encarsia-cellift/design-processing/design_repos.json
RUN bash -c "source /encarsia-cellift/env.sh && cd /encarsia-ibex/cellift && make run_vanilla_notrace"
RUN bash -c "source /encarsia-cellift/env.sh && cd /encarsia-ibex/cellift && make run_vanilla_notrace"

RUN pip3 install numpy matplotlib filelock

##
# DifuzzRTL
##

# Install elf2hex
RUN git clone https://github.com/sifive/elf2hex.git
RUN cd elf2hex && autoreconf -i && ./configure --target=riscv64-unknown-elf && make -j 200 && make install
# Fix some cpp files
RUN sed -i 's/objcopy=""/objcopy="riscv64-unknown-elf-objcopy"/' /usr/local/bin/riscv64-unknown-elf-elf2hex

# Install cocotb
RUN echo "host" | apt install -y make gcc g++ python3 python3-dev python3-pip
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN pip3 install cocotb==1.5.2

RUN pip3 install psutil sysv_ipc

RUN git clone https://github.com/encarsia-artifacts/encarsia-difuzz-rtl.git
RUN cd /encarsia-difuzz-rtl/Fuzzer/ISASim/riscv-isa-sim && mkdir build && cd build && ../configure --prefix=/encarsia-difuzz-rtl/Fuzzer/ISASim/riscv-isa-sim/build && make -j 200

##
# ProcessorFuzz
##

RUN git clone https://github.com/encarsia-artifacts/encarsia-processorfuzz.git /encarsia-processorfuzz
RUN cd /encarsia-processorfuzz/ && gunzip processorfuzz_spike.gz

RUN sed -i 's/int num_bugs = 1000;/int num_bugs = 4000;/' /encarsia-yosys/passes/inject/inject_amt.cc
RUN cd encarsia-yosys && make -j 200 && make install

COPY cascade_design_repos.json /encarsia-cascade/design-processing/design_repos.json

RUN pip install tabulate

RUN git clone https://github.com/encarsia-artifacts/encarsia-meta.git /encarsia-meta

COPY EnCorpus_*.tar.gz /

RUN mkdir -p /encarsia-meta/out/EnCorpus && tar -xvf /EnCorpus_boom.tar.gz -C /encarsia-meta/out/EnCorpus && tar -xvf /EnCorpus_ibex.tar.gz -C /encarsia-meta/out/EnCorpus && tar -xvf /EnCorpus_rocket.tar.gz -C /encarsia-meta/out/EnCorpus