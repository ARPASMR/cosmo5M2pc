# Versione 1.0 - Settembre 2021
FROM debian:11-slim

LABEL name="plottaggi cosmo 5M"
LABEL version="1.0"
#LABEL decription=""
LABEL maintainer="EP"

# filesystem
RUN mkdir -p /opt/cosmo_5M/tmp/png
RUN mkdir -p /opt/cosmo_5M/web
RUN mkdir /opt/cosmo_5M/archivio
RUN mkdir /opt/cosmo_5M/bin
RUN mkdir /opt/cosmo_5M/cartog
RUN mkdir /opt/cosmo_5M/conf
RUN mkdir /opt/cosmo_5M/doc
RUN mkdir /opt/cosmo_5M/draw
RUN mkdir /opt/cosmo_5M/log
RUN mkdir /opt/cosmo_5M/src
RUN chmod -R 777 /opt/cosmo_5M

# do i permessi a tutti
RUN chmod -R 777 /opt/cosmo_5M

# modalita' non interattiva
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# cambio i timeout
RUN echo 'Acquire::http::Timeout "240";' >> /etc/apt/apt.conf.d/180Timeout
# installo gli aggiornamenti ed i pacchetti necessari 
# tolti libc-dev zlib1g gcc gfortran g++ udunits-bin
RUN apt-get update
RUN apt-get -y install curl git locales dnsutils openssh-client smbclient procps util-linux build-essential ncftp rsync libtool gcc gfortran
RUN apt-get -y install nfs-common openssl libqt5core5a libqt5gui5 libbz2-dev

# compilo hdf5
COPY ./src/hdf5-1.12.1.tar.gz /opt/cosmo_5M/src/
ENV CPPFLAGS="$CPPFLAGS -fcommon"
RUN mkdir -p /opt/cosmo_5M/src/build \
        && cd /opt/cosmo_5M/src \
        && tar xvfz hdf5-1.12.1.tar.gz \
        && cd /opt/cosmo_5M/src/build \
        && ../hdf5-1.12.1/configure --prefix=/usr/local/hdf5 --enable-fortran --enable-cxx --with-default-api-version=v110 \
        && make \
#       && make check \
        && make install \
        && cd /opt/cosmo_5M \
        && rm -rf src/*

# compilo netcdf
COPY ./src/netcdf-c-4.8.1.tar.gz /opt/cosmo_5M/src/
ENV CPPFLAGS="$CPPFLAGS -fcommon -I/usr/local/hdf5/include"
ENV LDFLAGS="-L/usr/local/hdf5/lib"
ENV LD_LIBRARY_PATH=/usr/local/hdf5/lib:$LD_LIBRARY_PATH
RUN cd /opt/cosmo_5M/src \
        && tar xvfz netcdf-c-4.8.1.tar.gz \
        && cd netcdf-c-4.8.1 \
        && ./configure --prefix=/usr/local/netcdf \
        && make \
#        && make check \
        && make install \
        && cd /opt/cosmo_5M \
        && rm -rf src/*

# finisco di installare i pacchetti
ENV PATH=$PATH:/usr/local/hdf5:/usr/local/netcdf
RUN apt-get -y install libnetcdf18 libnetcdf-dev jq libreadline-dev libeccodes0 libeccodes-tools r-base r-base-dev

# compilo cdo-1.7.2 [versione vecchia, ma compatibile con il formato del file di griglia I7 per PC]
ENV CPPFLAGS="$CPPFLAGS -fcommon"
COPY ./src/cdo-1.7.2.tar.gz /opt/cosmo_5M/src/
RUN cd /opt/cosmo_5M/src \
        && tar -xzvf cdo-1.7.2.tar.gz \
        && cd cdo-1.7.2 \
        && ./configure --with-netcdf=/usr/local/netcdf --with-hdf5=/usr/local/hdf5 \
        && make \
        && make install \
        && cd /opt/cosmo_5M \
        && rm -rf src
# compilo wgrib (va rivista questa parte decisamente obsoleta)
RUN mkdir -p /opt/cosmo_5M/src/wgrib
COPY ./src/wgrib_m.tar /opt/cosmo_5M/src/wgrib
RUN cd /opt/cosmo_5M/src/wgrib \
        && tar xvf wgrib_m.tar \
        && make \
        && mv wgrib /usr/local/bin/ \
        && cd /opt/cosmo_5M && rm -rf src/wgrib

# installo i pacchetti di R necessari agli scripts
RUN R -e "install.packages('ncdf4', repos = 'http://cran.mirror.garr.it/mirrors/CRAN/')"

# aggiungo ll
RUN echo "# .bash_aliases" >> /root/.bash_aliases \
        && echo "" >> /root/.bash_aliases && echo "alias ll='ls -alh'" >> /root/.bash_aliases \
        && echo "" >> /root/.bashrc \
        && echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi" >> /root/.bashrc

# definisco l'entrypoint
#ENTRYPOINT ["/bin/bash","/opt/cosmo_5M/entry.sh" ]
CMD "/bin/bash"

# atterro nella directory radice del processo
WORKDIR /opt/cosmo_5M
