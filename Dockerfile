# Base runtime: Terraform + tools (pin digest; bump intentionally).
FROM stupean/yandex-terraform@sha256:e55da7ecc64d3cff1048900f856b84ec6228e2568f1b64f09154500f932bd417

# Baked module + scripts (version of infra == image tag/digest).
COPY terraform/ /module/
COPY scripts/ /module/scripts/
COPY docker/entrypoint.sh /entrypoint.sh

USER root
RUN chmod +x /entrypoint.sh /module/scripts/bootstrap.sh /module/scripts/join.sh \
  && mkdir -p /work \
  && chmod 777 /work

ENV MODULE_DIR=/module \
    WORK_DIR=/work

WORKDIR /work
ENTRYPOINT ["/entrypoint.sh"]
CMD ["help"]
