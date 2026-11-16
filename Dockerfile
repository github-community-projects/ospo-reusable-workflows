FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

WORKDIR /app

# copy all files from repo to ensure all changes are included
# which will ensure a new image digest is generated
COPY . .

CMD ["cat", "README.md"]
