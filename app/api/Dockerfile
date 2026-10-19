# Build the API as a static binary and ship it in a minimal runtime image.
FROM golang:1.27-alpine AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./

FROM alpine:3.22

RUN apk add --no-cache ca-certificates && addgroup -g 10001 -S app && adduser -S -u 10001 -G app app
COPY --from=build /out/api /usr/local/bin/api

USER app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/api"]
