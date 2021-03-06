FROM python:3.7-slim-buster
LABEL maintainer="Sharethrough <engineers@sharethrough.com>"
LABEL version=1.2.4

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.14
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS="crypto,celery,jdbc,mysql,ssh,slack,aws"
ARG PYTHON_DEPS="pytest mysql-connector-python SQLAlchemy==1.3.23 Flask-SQLAlchemy==2.4.4"
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

ENV USER="airflow"
ENV GROUP="airflow"

RUN groupadd ${GROUP}
RUN useradd -g ${GROUP} ${USER}

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
        vim \
        jq \
        wget \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && python -m pip install --upgrade pip\
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install apache-airflow[${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install 'redis==3.2' \
    && pip install yq \
    && pip install awscli\
    && pip install PyYAML\
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/airflow_config_environment.py /airflow_config_environment.py

COPY config/airflow.cfg ${AIRFLOW_USER_HOME}/airflow.cfg
COPY config/pools.yml ${AIRFLOW_USER_HOME}/pools.yml

COPY ./Makefile ${AIRFLOW_USER_HOME}/Makefile
COPY ./tests ${AIRFLOW_USER_HOME}/tests

RUN chown -R ${USER}:${GROUP} ${AIRFLOW_USER_HOME}
RUN chown -R ${USER}:${GROUP} /home

EXPOSE 8080 5555 8793

WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"] # set default arg for entrypoint
