#!/bin/bash

for x in core2 nehalem sandybridge ivybridge haswell skylake;do
  docker build -t qnib/uplain-gearshifft:build-${x} --target=build --build-arg=CFLAGS_MARCH=${x} .
  docker build -t qnib/uplain-gearshifft:${x} --build-arg=CFLAGS_MARCH=${x} .
done
