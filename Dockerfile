##
## devopstools
## A Docker with a standard set of tools used for devops
##
ARG HW_PLATFORM=arm64
ARG AWS_CLI_ZIP=awscli-exe-linux-aarch64.zip

ARG AWS_IAM_AUTHENTICATOR_VERSION=0.5.9

FROM python:3-bookworm as base

# Setup env
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1

WORKDIR /root

RUN apt-get -y update && \
  apt-get install -y \
    curl \
    git \
    groff \
    jq \
    make \
    sudo \
    tar \
    unzip \
    wget && \
  rm -rf /var/lib/apt/lists/*

RUN printf '%s\n' \
  "alias 'll'='ls -lah --color'" \
  'export PS1="\[\033[0;33m\]\w\[\033[0;0m\]\n\[\033[0;37m\]$(date +%H:%M)\[\033[0;0m\] $ "' \
  >> /root/.bashrc

FROM base AS build

WORKDIR /root

RUN pip install pipenv
RUN apt-get update && apt-get install -y --no-install-recommends gcc

# Install Python PIP packages
COPY Pipfile .
COPY Pipfile.lock .
RUN PIPENV_VENV_IN_PROJECT=1 pipenv install --deploy

ARG HW_PLATFORM

# Install AWS CLI v2
ARG AWS_CLI_ZIP
RUN curl "https://awscli.amazonaws.com/${AWS_CLI_ZIP}" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws*

# Install aws iam authenticator
ARG AWS_IAM_AUTHENTICATOR_VERSION
RUN curl -Lo /usr/local/bin/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${AWS_IAM_AUTHENTICATOR_VERSION}/aws-iam-authenticator_${AWS_IAM_AUTHENTICATOR_VERSION}_linux_${HW_PLATFORM} \
    && \
    chmod +x /usr/local/bin/aws-iam-authenticator

FROM base AS runtime

COPY --from=build /root/.venv /root/.venv
COPY --from=build /usr/local/aws-cli /usr/local/aws-cli
COPY --from=build /usr/local/bin /usr/local/bin
ENV PATH="/root/.venv/bin:$PATH"
ENV ANSIBLE_PYTHON_INTERPRETER=/root/.venv/bin/python3
