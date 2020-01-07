===========
Engineering
===========

.. contents::
   :local:

Overview
--------

This is a engineering guide to build a docker image to push to the repository. 

Build Docker Image
------------------

Checkout this repository::

  git clone ssh://git@bitbucket.ris.wustl.edu:7999/appeng/docker-icc-ifort-mpi.git

Build a docker image::

  docker build --tag registry.gsc.wustl.edu/sleong/base-icc-ifort-mpi-mlx .

Run Docker Container
--------------------

Shown below are steps to run the docker image locally or on compute1.

Locally
~~~~~~~

Run the following command to get an interactive container instance::

  docker run --rm -it registry.gsc.wustl.edu/sleong/base-icc-ifort-mpi-mlx /bin/bash

Compute1
~~~~~~~~

Login to compute1 client host::

  ssh compute1-client-1

Run the following command to get an interactive container instance.  Please
replace "/your/intel/licenses/path" below with your intel license file.  You
also can add your storage1 path to be visible in your docker images by adding
another path separated by a white space character.  For example,
"/your/intel/licenses/path:/opt/licenses /storage1/fs1/sleong/Active/:/my-projects"
to the LSF_DOCKER_VOLUMES variable below::

  LSF_DOCKER_SHM_SIZE=20G LSF_DOCKER_VOLUMES="/your/intel/licenses/path:/opt/licenses" bsub -q general-interactive -Is -a "docker(registry.gsc.wustl.edu/sleong/base-icc-ifort-mpi-mlx)" /bin/bash

Test Docker Image
-----------------

Shown below are the tests that can be used to test the docker image.

Fortran
~~~~~~~

This is an MPI job that can be used to test on compute1.

Login to compute1::

  ssh compute1-client-1

Get an LSF interactive job::

  LSF_DOCKER_SHM_SIZE=20G LSF_DOCKER_VOLUMES="/your/intel/licenses/path:/opt/licenses" bsub -q general-interactive -Is -a "docker(registry.gsc.wustl.edu/sleong/base-icc-ifort-mpi-mlx)" /bin/bash

Run the test::

  wget https://computing.llnl.gov/tutorials/mpi/samples/Fortran/mpi_ringtopo.f
  mpiifort mpi_ringtopo.f
  mpirun -np 6 ./a.out
