FROM debian:buster AS builder
COPY sources.list /etc/apt/sources.list
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install devscripts && apt-get -y build-dep hostapd
#&& rm -rf /var/lib/apt/lists/*
#RUN cat /etc/apt/sources.list
#RUN apt-get build-dep hostapd
RUN mkdir /bld
RUN chown 1000 /bld
#RUN apt-get update
USER 1000
WORKDIR /bld
RUN apt-get -y source hostapd
RUN ln -s `pwd`/wpa-* `pwd`/wpa
WORKDIR /bld/wpa

#change some fake thing
RUN echo "# dummy upd8 test `date`" >> src/Makefile
RUN sed -i -e 's/Could not creat/Could not lolioo /1' src/ap/accounting.c

RUN ls -alshtr
#RUN git init --initial-branch=master
RUN git init
RUN git config user.email "bartpio@patcher.invalid"
RUN git config user.name "Bart Piotrowski"
RUN git add . && git commit -m "hostapd `ls -d /bld/wpa-*`" && git log --oneline --no-abbrev
#COPY dnc.patch .
#RUN patch -u -p1 -F10 <dnc.patch

RUN git remote add azu https://bartpio@dev.azure.com/bartpio/hostapd/_git/hostapd
RUN git fetch azu && git reset --soft azu/master
RUN git status
RUN git commit -m "hostapd `ls -d /bld/wpa-*`" && git log --oneline --no-abbrev
RUN git checkout patched && git merge master
RUN git log --oneline --no-abbrev

#RUN git add . && git reset HEAD *.patch
RUN debuild -b -uc -us
#RUN git checkout -b patched && git commit -m "dnc patched `ls -d /bld/wpa-*`" && git log --oneline --no-abbrev

#RUN git checkout --orphan packages && git rm -rf . && cp /bld/*.deb . && cp /bld/*.udeb . && git add *.deb && git add *.udeb && git commit -m "dnc packaged `ls -d /bld/wpa-*`"
RUN git checkout packages && cp /bld/*.deb . && cp /bld/*.udeb . && git add *.deb && git add *.udeb
RUN git status && ls -alshtr
RUN git commit -m "dnc packaged `ls -d /bld/wpa-*`"

RUN mkdir /tmp/repo.git && git init --bare /tmp/repo.git && git remote add origin /tmp/repo.git && git push -u origin master patched packages
WORKDIR /tmp/repo.git
RUN git gc

FROM debian:buster AS packageholder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install git rsync && rm -rf /var/lib/apt/lists/*

# accept the arguments from who knows
ARG PUID=1000
ARG PGID=1000
ARG USER=someone

# Add the group (if not existing) 
# then add the user to the numbered group 
RUN addgroup -g ${PGID} ${USER} || true && adduser -D -u ${PUID} -G `getent group ${PGID} | cut -d: -f1` ${USER} || true

RUN mkdir /code && chown 1000 /code
RUN mkdir -p /home/someone && chown 1000 /home/someone
USER 1000
ENV HOME=/home/someone
RUN mkdir /home/someone/.ssh

WORKDIR /packages
COPY --from=builder /bld/*.deb /packages/
COPY --from=builder /bld/*.udeb /packages/
WORKDIR /repo.git
COPY --from=builder /tmp/repo.git/ /repo.git/

WORKDIR /code
RUN git clone file:///repo.git hostapd
WORKDIR /code/hostapd
RUN git checkout packages && git checkout patched && git checkout master
RUN --mount=type=secret,id=pushkey
RUN ln -s /run/secrets/pushkey /home/someone/.ssh/id_rsa
RUN git remote add azu git@ssh.dev.azure.com:v3/bartpio/hostapd/hostapd
RUN git push azu patched packages
