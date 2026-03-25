#!/bin/bash
#runs kryoflux gui by invoking java

cd /home/bcadmin

ln -s /home/bcadmin/Desktop/More_Software/kryoflux_2.6_linux/dtc cddtc

cd cddtc

java -jar kryoflux-ui.jar
