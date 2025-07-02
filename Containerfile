# syntax=docker/dockerfile:1

# 仅构建 void-glibc-full 镜像的简化 Containerfile（去掉 scratch）

# 1) 引入 BuildKit 语法，指定构建平台
FROM --platform=${BUILDPLATFORM} alpine:3.22 AS bootstrap

# 2) 镜像源和 LIBC 默认为 glibc
ARG MIRROR=https://repo-ci.voidlinux.org
ARG LIBC=glibc
ARG TARGETARCH
ARG LIBC=glibc

# 3) 安装基础工具并下载静态 xbps
RUN apk add --no-cache ca-certificates curl \
  && curl -fSL "${MIRROR}/static/xbps-static-static-0.59_5.$(uname -m)-${LIBC}.tar.xz" \
     | tar -xJ -C /usr/local

# 4) 拷贝签名密钥和初始化脚本
COPY keys/*                 /target/var/db/xbps/keys/
COPY setup.sh               /bootstrap/setup.sh
COPY noextract.conf         /target/etc/xbps.d/noextract.conf

# 5) 同步索引（仅索引，不安装包）
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache \
  . /bootstrap/setup.sh \
  && XBPS_TARGET_ARCH=$(uname -m) xbps-install -S -R "${REPO}" -r /target

# 6) 安装 full（base-container）变体
FROM bootstrap AS install-full
COPY --from=bootstrap /target /target
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache \
  . /bootstrap/setup.sh \
  && XBPS_TARGET_ARCH=$(uname -m) xbps-install -y -R "${REPO}" -r /target base-container

# 7) 最终镜像——直接基于 install-full，去掉 scratch
FROM install-full AS void-glibc-full
WORKDIR /
RUN \
  cp -a /target/. / \
  && install -dm1777 /tmp \
  && xbps-reconfigure -fa \
  && rm -rf /var/cache/xbps/* /target

CMD ["/bin/sh"]
