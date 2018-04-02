## pek: a.k.a. ./docker-for-jenkins-nodes/cpanel-perl/build.sh -c 7 -v 11.74 -p 526
## ensure the cPanel version is synced with the similar variable in the Jenkinsfile
FROM cpanel-perl/centos7:11.74
MAINTAINER Pax Aurora <pax@cpanel.net>

## which: used in the B::C testsuite
## gdbm-devel: for '-lgdbm'
## libdb-devel: for '-ldb'
RUN yum -y update \
    && yum -y groups install "Development Tools" \
    && yum -y install sudo which gdbm-devel libdb-devel \
    && yum clean all \
    && rm -rf /var/cache/yum

## from bamboo.sh
COPY rpms/cpanel-perl-526-5.26.0-1.debuginfo.cp1170.x86_64.rpm /
RUN rpm -Uv --force cpanel-perl-526-5.26.0-1.debuginfo.cp1170.x86_64.rpm

RUN echo -e 'Defaults:jenkins !requiretty\njenkins ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/jenkins \
    && groupadd --gid 1008 jenkins \
    && useradd --uid 1008 --gid 1008 --comment "User to match the host user id" jenkins

USER jenkins
