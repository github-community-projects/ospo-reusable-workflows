FROM alpine:3.24.0@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4

WORKDIR /app

# copy all files from repo to ensure all changes are included
# which will ensure a new image digest is generated
COPY . .

CMD ["cat", "README.md"]
