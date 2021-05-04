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
RUN ls -alshtr
#RUN git init --initial-branch=master
RUN git init
RUN git config user.email "bartpio@patcher.invalid"
RUN git config user.name "Bart Piotrowski"
RUN git add . && git commit -m "hostapd `ls -d /bld/wpa-*`" && git log --oneline --no-abbrev
COPY dnc.patch .
RUN patch -u -p1 -F10 <dnc.patch
RUN git add . && git reset HEAD *.patch
RUN debuild -b -uc -us
RUN git checkout -b patched && git commit -m "dnc patched `ls -d /bld/wpa-*`" && git log --oneline --no-abbrev

RUN git checkout --orphan packages && git rm -rf . && cp /bld/*.deb . && cp /bld/*.udeb . && git add *.deb && git add *.udeb && git commit -m "dnc packaged `ls -d /bld/wpa-*`"

RUN mkdir /tmp/repo.git && git init --bare /tmp/repo.git && git remote add origin /tmp/repo.git && git push -u origin master patched packages
WORKDIR /tmp/repo.git
RUN git gc

FROM debian:buster AS packageholder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install git rsync && rm -rf /var/lib/apt/lists/*
USER 1000
WORKDIR /packages
COPY --from=builder /bld/*.deb /packages/
COPY --from=builder /bld/*.udeb /packages/
WORKDIR /repo.git
COPY --from=builder /tmp/repo.git/ /repo.git/
