FROM registry.gsc.wustl.edu/sleong/base-icc-ifort-mpi-mlx as build

ENV SPACK_ROOT /opt/spack
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/intel/bin:/opt/spack/bin

RUN yum install -y tzdata lsb-release bison tcl dpatch chrpath flex gfortran autoconf kmod tk ethtool graphviz lsof swig libgfortran3 automake pciutils \
                   openssl-devel.x86_64 openssl-libs.x86_64 numactl-libs.x86_64 numactl-devel.x86_64 libtool-ltdl.x86_64 libtool-ltdl-devel.x86_64 libmnl.x86_64 \
                   libnl3 gcc-gfortran tcsh mesa-libOSMesa.x86_64 mesa-libOSMesa-devel.x86_64 logrotate \
                   libtiff-devel.x86_64 fftw-devel.x86_64 gcc-c++ gcc-gfortran \
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
&&  yum clean -y all

COPY ./rc/bashrc /etc/bashrc
COPY ./rc/zshenv /etc/zshenv

RUN cd /opt && git clone https://github.com/spack/spack.git
COPY spack/etc/spack/packages.yaml $SPACK_ROOT/etc/spack/packages.yaml
COPY spack/etc/spack/compilers.yaml /etc/spack/compilers.yaml
COPY env2 /env2

RUN mkdir -p /usr/share/Modules/modulefiles/intel \
&&   echo "#%Module" > /usr/share/Modules/modulefiles/intel/20 \
&&   chmod +x /env2 \
&&   perl /env2 -from bash -to modulecmd "/opt/intel/compilers_and_libraries/linux/bin/compilervars.sh intel64" >> /usr/share/Modules/modulefiles/intel/20 \
&&   rm /env2

# Detect intel compilers with spack
RUN    . /opt/intel/compilers_and_libraries/linux/bin/compilervars.sh intel64 && \
    spack compiler find && \
    chmod 755 /etc/bashrc /etc/zshenv

COPY licenses /opt/intel/licenses

# Install ESMF
RUN . /usr/share/Modules/init/sh && module load intel/20 && \
    for i in $(spack find target=x86_64 | grep -v "^--" | grep -v "^=="); do spack uninstall --dependents -y $i target=x86_64; done && \
    spack bootstrap && \
    spack install -v netcdf-c ^hdf5 ^intel-mpi && \
    spack install -v netcdf-fortran ^hdf5 ^intel-mpi

# && spack install --no-checksum esmf@8.0.0 -lapack -pio -pnetcdf -xerces ^hdf5 ^openmpi

RUN spack compiler find

# Install gFTL
RUN . /usr/share/Modules/init/sh && module load intel/20 && \
    . /etc/bashrc && git clone https://github.com/Goddard-Fortran-Ecosystem/gFTL.git /gFTL \
&&  cd /gFTL \
&&  mkdir build \
&&  cd build \
&&  cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gFTL \
&&  make -j install \
&&  rm -rf /gFTL

RUN export FORCE_UNSAFE_CONFIGURE=1 &&  . /usr/share/Modules/init/sh && module load intel/20 && . /etc/bashrc && spack install nco

RUN cd /tmp/ && \
    git clone https://git.code.sf.net/p/esmf/esmf && cd esmf && \
    git checkout -b ESMF_8_0_0 && mkdir -p /opt/ibm/lsfsuite/lsf/conf/ && \
    touch /opt/ibm/lsfsuite/lsf/conf/profile.lsf && \
    . /etc/bashrc && export FORCE_UNSAFE_CONFIGURE=1 && \
    module load intel/20 && \
    /opt/spack/bin/spack load hdf5 && \
    /opt/spack/bin/spack load netcdf-c && \
    /opt/spack/bin/spack load netcdf-fortran && \
    mkdir /tmp/esmf-install && \
    export ESMF_COMPILER=intel && \
    export ESMF_DIR=/tmp/esmf && \
    export ESMF_INSTALL_PREFIX=/tmp/esmf-install && \
    export ESMF_COMM=intelmpi && \
    make && make install && \
    cd /tmp/ && rm -fr esmf

RUN rm -fr /opt/intel/licenses /opt/ibm /opt/intel

FROM registry.gsc.wustl.edu/sleong/base-icc-ifort-mpi-mlx
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/intel/bin:/opt/spack/bin
COPY --from=build /opt /opt
COPY --from=build /etc/spack/compilers.yaml /etc/spack/compilers.yaml
COPY --from=build /usr/share/Modules /usr/share/Modules
COPY --from=build /tmp/esmf-install /usr/local

RUN yum install -y tzdata lsb-release bison tcl dpatch chrpath flex gfortran autoconf kmod tk ethtool graphviz lsof swig libgfortran3 automake pciutils \
                   openssl-devel.x86_64 openssl-libs.x86_64 numactl-libs.x86_64 numactl-devel.x86_64 libtool-ltdl.x86_64 libtool-ltdl-devel.x86_64 libmnl.x86_64 \
                   libnl3 gcc-gfortran tcsh mesa-libOSMesa.x86_64 mesa-libOSMesa-devel.x86_64 logrotate \
                   libtiff-devel.x86_64 fftw-devel.x86_64 gcc-c++ gcc-gfortran \
                   autoconf automake flex bison make python environment-modules patch libsigsegv libtool texinfo findutils \
                   xorg-x11-util-macros libpciaccess-devel numactl libxml2-devel gettext help2man libuuid-devel libjpeg* && \
                   yum groupinstall -y 'Development Tools' \
                   &&  yum install -y epel-release \
                   &&  yum -y install  https://centos7.iuscommunity.org/ius-release.rpm \
                   &&  yum -y remove git* && yum -y install  git2u-all \
                   &&  yum install -y zsh wget vim cmake3 sssd gcc c++ g++ \
                   &&  yum groupinstall 'Xfce' -y \
                   &&  yum -y install tigervnc-server tigervnc-server-minimal \
                   &&  ln -s /usr/bin/cmake3 /usr/bin/cmake \
                   &&  export ZSH=/usr/share/oh-my-zsh \
                   &&  wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh \
                   &&  yum clean -y all \
                   &&  chmod 755 /etc/bashrc /etc/zshenv

COPY --from=build /etc/bashrc /etc/bashrc
COPY --from=build /etc/zshenv /etc/zshenv

ENV ESMF_ROOT /usr/local
ENV gFTL_ROOT /opt/gFTL/GFTL-1.2/

