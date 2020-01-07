FROM registry.gsc.wustl.edu/sleong/base-icc-ifort-mpi-mlx

ENV SPACK_ROOT /opt/spack
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/intel/bin:/opt/spack/bin
COPY ./rc/bashrc /etc/bashrc
COPY ./rc/zshenv /etc/zshenv

RUN yum install -y tzdata lsb-release bison tcl dpatch chrpath flex gfortran autoconf kmod tk ethtool graphviz lsof swig libgfortran3 automake pciutils \
                   openssl-devel.x86_64 openssl-libs.x86_64 numactl-libs.x86_64 numactl-devel.x86_64 libtool-ltdl.x86_64 libtool-ltdl-devel.x86_64 libmnl.x86_64 \
                   libnl3 gcc-gfortran tcsh mesa-libOSMesa.x86_64 mesa-libOSMesa-devel.x86_64 logrotate \
                   libtiff-devel.x86_64 fftw-devel.x86_64 gcc-c++ gcc-gfortran \
                   centos-release-scl devtoolset-7-gcc devtoolset-7-gcc-c++ devtoolset-7-gcc-gfortran devtoolset-8-gcc devtoolset-8-gcc-c++ devtoolset-8-gcc-gfortran \
                   autoconf automake flex bison make python environment-modules patch libsigsegv libtool texinfo findutils \
                   xorg-x11-util-macros libpciaccess-devel numactl libxml2-devel gettext help2man libuuid-devel libjpeg*


# Create intel/20 modulefile
COPY lsf/ /opt/ibm/lsfsuite/lsf/
ENV LSF_ENVDIR /opt/ibm/lsfsuite/lsf/conf
ENV LSF_LIBDIR /opt/ibm/lsfsuite/lsf/10.1/linux2.6-glibc2.3-x86_64/lib

RUN yum groupinstall -y 'Development Tools' \
&&  yum install -y epel-release \
&&  yum -y install  https://centos7.iuscommunity.org/ius-release.rpm \
&&  yum -y remove git* && yum -y install  git2u-all \
&&  yum install -y zsh wget vim cmake3 sssd gcc c++ g++ \
&&  ln -s /usr/bin/cmake3 /usr/bin/cmake \
&&  export ZSH=/usr/share/oh-my-zsh \
&&  wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh \
&&  yum clean -y all \
&&  chmod 755 /etc/bashrc /etc/zshenv

RUN cd /opt && git clone https://github.com/spack/spack.git
COPY spack/etc/spack/packages.yaml /spack/etc/spack/packages.yaml
COPY spack/etc/spack/compilers.yaml /etc/spack/compilers.yaml
COPY env2 /env2

RUN mkdir -p /usr/share/modulefiles/intel \
&&   echo "#%Module" > /usr/share/modulefiles/intel/20 \
&&   chmod +x /env2 \
&&   perl /env2 -from bash -to modulecmd "/opt/intel/compilers_and_libraries/linux/bin/compilervars.sh intel64" >> /usr/share/modulefiles/intel/20 \
&&   rm /env2

# Detect intel compilers with spack
RUN    . /opt/intel/compilers_and_libraries/linux/bin/compilervars.sh intel64 && \
    spack compiler find && \
    chmod 755 /etc/bashrc /etc/zshenv

# Install ESMF
RUN . /usr/share/Modules/init/sh && module load intel/20 && \
    for i in $(spack find target=x86_64 | grep -v "^--" | grep -v "^=="); do spack uninstall --dependents -y $i target=x86_64; done && \
    spack bootstrap && \
    spack install -v netcdf-c ^hdf5 ^openmpi && \
    spack install -v netcdf-fortran ^hdf5 ^openmpi 

# && spack install --no-checksum esmf@8.0.0 -lapack -pio -pnetcdf -xerces ^hdf5 ^openmpi

# Install gFTL
RUN git clone https://github.com/Goddard-Fortran-Ecosystem/gFTL.git /gFTL \
&&  cd /gFTL \
&&  mkdir build \
&&  cd build \
&&  cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gFTL \
&&  make -j install \
&&  rm -rf /gFTL

COPY licenses /opt/intel/licenses
RUN cd /tmp/ && \
    git clone https://git.code.sf.net/p/esmf/esmf && cd esmf && \
    git checkout -b ESMF_8_0_0 && mkdir -p /opt/ibm/lsfsuite/lsf/conf/ && \
    touch /opt/ibm/lsfsuite/lsf/conf/profile.lsf && \
    . /etc/bashrc && export FORCE_UNSAFE_CONFIGURE=1 && \
    module load intel/20 && \
    /opt/spack/bin/spack load hdf5 && \
    /opt/spack/bin/spack load netcdf-c && \
    /opt/spack/bin/spack load netcdf-fortran && \
    export ESMF_COMPILER=intel && \
    export ESMF_DIR=/tmp/esmf && \
    export ESMF_INSTALL_PREFIX=/usr/local && \
    export ESMF_COMM=intelmpi && \
    make && make install

#RUN mkdir -p /opt/ibm/lsfsuite/lsf/conf/ && touch /opt/ibm/lsfsuite/lsf/conf/profile.lsf && . /etc/bashrc && export FORCE_UNSAFE_CONFIGURE=1 && module load intel/20 && /opt/spack/bin/spack install nco
