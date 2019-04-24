FROM registry.access.redhat.com/rhscl/redis-32-rhel7:3.2

LABEL maintainer sandor.kosa

COPY config/redis.conf /redis-templates/redis.conf
COPY config/sentinel.conf /redis-templates/sentinel.conf

USER root
RUN  \
    rpm --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release && \
    yum-config-manager --disable "*" && \
    yum-config-manager --enable rhel-7-server-rpms && \
    yum -y install --setopt=tsflags=nodocs rsync && \
    yum clean all && \
    cd / && \
    mkdir /redis-conf && \
    chmod 777 /redis-conf && \
    download_dir=~/downloads && \
    mkdir -p $download_dir && \
    exporter_dir=/opt/redis-exporter && \
    mkdir -p $exporter_dir && \
    exporter_tar=redis_exporter-v0.11.2.linux-amd64.tar.gz && \
    cd $download_dir && \
    curl -LO https://github.com/oliver006/redis_exporter/releases/download/v0.11.2/$exporter_tar && \
    cd $exporter_dir && \
    tar -xzf $download_dir/$exporter_tar && \
    rm -rf   $download_dir 

EXPOSE 6379 16379 26379

COPY scripts/redis_pre_run.py /
COPY scripts/entrypoint.sh /
COPY scripts/sentinel_pre_run.py /
COPY scripts/health_check.sh /
COPY scripts/peer-finder /
RUN chmod +x /entrypoint.sh /health_check.sh /peer-finder

ENTRYPOINT [ "/entrypoint.sh" ]
