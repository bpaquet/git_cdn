FROM python:3.10-alpine as base
WORKDIR     /app

FROM base as builder

RUN apk add --update --no-cache \
        alpine-sdk \
        libffi-dev \
        musl-dev \
        openssl-dev

COPY . /app/
RUN make poetry-install build export

FROM base

# Only install dependencies
RUN  apk --no-cache add \
        git \
        libstdc++ \
        make \
     && \
     apk add --update --no-cache \
        curl \
        gzip \
        libffi \
        openssl

COPY --from=builder /app/requirements.txt /app/requirements.txt
COPY --from=builder /app/dist /app/

RUN apk add --update --no-cache --virtual \
        .build-deps \
        alpine-sdk \
        libffi-dev \
        musl-dev \
        openssl-dev \
    &&\
    python -m pip install --constraint requirements.txt /app/git_cdn-*.whl && \
    apk del .build-deps

# Configure git for git-cdn
RUN git config --global pack.threads 4  &&\
    git config --global http.postBuffer 524288000 && \
    # Allow git clone/fetch --filter
    git config --global uploadpack.allowfilter true

ADD config.py /app/

CMD ["newrelic-admin", "run-program", "gunicorn", "git_cdn.app:app", "-c", "config.py", "--bind", ":8000"]

EXPOSE 8000
