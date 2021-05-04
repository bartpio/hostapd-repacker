FROM debian:buster AS builder
COPY sources.list /etc/apt/sources.list
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install devscripts && apt-get -y build-dep hostapd
RUN mkdir /bld
RUN chown 1000 /bld
USER 1000
WORKDIR /bld
RUN apt-get -y source hostapd
RUN ln -s `pwd`/wpa-* `pwd`/wpa
WORKDIR /bld/wpa

#change some fake thing (when testing)
#RUN echo "# dummy upd8 test `date`" >> src/Makefile
#RUN sed -i -e 's/Could not creat/Could not lolioo /1' src/ap/accounting.c

RUN ls -alshtr
#RUN git init --initial-branch=master # will be a future thing!
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

RUN mkdir /code
ENV HOME=/root
RUN mkdir /root/.ssh && chmod 700 /root/.ssh

WORKDIR /packages
COPY --from=builder /bld/*.deb /packages/
COPY --from=builder /bld/*.udeb /packages/
WORKDIR /repo.git
COPY --from=builder /tmp/repo.git/ /repo.git/

WORKDIR /code
RUN git clone file:///repo.git hostapd
WORKDIR /code/hostapd
RUN git checkout packages && git checkout patched && git checkout master
COPY known_hosts /root/.ssh/known_hosts

RUN git remote add azu git@ssh.dev.azure.com:v3/bartpio/hostapd/hostapd
# realmode ....
RUN --mount=type=secret,id=pushkey ln -s /run/secrets/pushkey /root/.ssh/id_rsa && git push azu master patched packages

# test notepadmode ....
#RUN git checkout packages && git checkout -b notepad/packages
#RUN git checkout patched && git checkout -b notepad/patched
#RUN git checkout master && git checkout -b notepad/master
#RUN --mount=type=secret,id=pushkey ln -s /run/secrets/pushkey /root/.ssh/id_rsa && git push azu notepad/master notepad/patched notepad/packages
