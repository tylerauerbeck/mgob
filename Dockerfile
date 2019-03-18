FROM golang:1.11

ARG APP_VERSION=unkown

ADD . /go/src/github.com/stefanprodan/mgob

WORKDIR /go/src/github.com/stefanprodan/mgob

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags "-X main.version=$APP_VERSION" \
    -a -installsuffix cgo -o mgob github.com/stefanprodan/mgob

FROM centos:7 

LABEL org.label-schema.name="mgob" \
      org.label-schema.description="MongoDB backup automation tool" \
      org.label-schema.url="https://github.com/stefanprodan/mgob" \
      org.label-schema.vcs-url="https://github.com/stefanprodan/mgob" \
      org.label-schema.vendor="stefanprodan.com" \
      org.label-schema.schema-version="1.0"

RUN yum install -y epel-release && yum install -y python-pip mongodb ca-certificates && useradd -ms /bin/bash mgob 

RUN curl -o mc  https://dl.minio.io/client/mc/release/linux-amd64/mc && mv mc /usr/bin && chmod 755 /usr/bin/mc

#Install gcloud
RUN echo -e "[google-cloud-sdk]\nname=Google Cloud SDK\nbaseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg\n\thttps://packages.cloud.google.com/yum/doc/rpm-package-key.gpg" > /etc/yum.repos.d/google-cloud-sdk.repo && \
	yum install -y google-cloud-sdk && ln -s /lib /lib64 && \
	gcloud config set core/disable_usage_reporting true && \
	gcloud config set component_manager/disable_update_check true && \
	gcloud config set metrics/environment github_docker_image && \
	gcloud --version

#Install azure-cli
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo && \
    yum -y install azure-cli && yum clean all

COPY --from=0 /go/src/github.com/stefanprodan/mgob/mgob /usr/bin

VOLUME ["/config", "/storage", "/tmp", "/data"]

USER mgob

ENTRYPOINT [ "usr/bin/mgob" ]
