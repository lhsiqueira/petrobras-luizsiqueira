FROM golang@sha256:70bd7ddea8b6cbe5d6943cde279d6b67feb10cc924fb9100d1d8757c1575b280 AS build
WORKDIR /src
COPY app/ ./
RUN go test -v -cover ./...
RUN CGO_ENABLED=0 go build -trimpath -o /out/petrobras-luizsiqueira .

FROM scratch
COPY --from=build /out/petrobras-luizsiqueira /petrobras-luizsiqueira
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/petrobras-luizsiqueira"]
