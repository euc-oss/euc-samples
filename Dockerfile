#############################################################################
# build markdown to html

# get python image to create static pages
FROM python:alpine AS builder

# install require pyton packages (mkdocs, etc)
WORKDIR /workspace
COPY requirements.txt .
RUN apk add git && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# build the static pages
COPY . .
RUN mkdocs build -f mkdocs.yml

#############################################################################
# build the final image with content from builder

# get base image
FROM httpd:2.4-alpine AS final

WORKDIR /usr/local/apache2/htdocs/

# add metadata via labels
LABEL com.vmware.eocto.version="0.0.1"
LABEL com.vmware.eocto.git.repo="https://github.com/EUCDigitalWorkspace/EUCDigitalWorkspace.github.io"
LABEL com.vmware.eocto.git.commit="DEADBEEF"
LABEL com.vmware.eocto.maintainer.name="Richard Croft"
LABEL com.vmware.eocto.maintainer.email="rcroft@vmware.com"
LABEL com.vmware.eocto.released="9999-99-99"
LABEL com.vmware.eocto.based-on="httpd:2.4-alpine"
LABEL com.vmware.eocto.project="EUCDigitalWorkspace.github.io"

# copy the html to wwwroot
#COPY --chmod=nobody:nogroup --from=builder /app/html ./
COPY --from=builder /workspace/.site ./

#############################################################################
# vim: ft=unix sync=dockerfile ts=4 sw=4 et tw=78:
