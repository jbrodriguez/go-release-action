#!/bin/bash -eux

# prepare binary/release name
BINARY_NAME=$(basename ${GITHUB_REPOSITORY})
if [ x${INPUT_BINARY_NAME} != x ]; then
  BINARY_NAME=${INPUT_BINARY_NAME}
fi
RELEASE_TAG=$(basename ${GITHUB_REF})
RELEASE_ASSET_NAME=${BINARY_NAME}-${RELEASE_TAG}-${INPUT_GOOS}-${INPUT_GOARCH}

# prepare upload URL
RELEASE_ASSETS_UPLOAD_URL=$(cat ${GITHUB_EVENT_PATH} | jq -r .release.upload_url)
if [ ! -z "${INPUT_UPLOAD_URL}"]; then
  RELEASE_ASSETS_UPLOAD_URL=${INPUT_UPLOAD_URL}
fi
RELEASE_ASSETS_UPLOAD_URL=${RELEASE_ASSETS_UPLOAD_URL%\{?name,label\}}

# execute pre-command if exist, e.g. `go get -v ./...`
if [ ! -z "${INPUT_PRE_COMMAND}" ]; then
    ${INPUT_PRE_COMMAND}
fi

# build binary
cd ${INPUT_PROJECT_PATH}
EXT=''
if [ ${INPUT_GOOS} == 'windows' ]; then
  EXT='.exe'
fi

GO_LDFLAGS=''
if [ ! -z "${INPUT_LDFLAGS}" ]; then
    GO_LDFLAGS="-ldflags \"${INPUT_LDFLAGS}\""
fi


bash -c "GOOS=${INPUT_GOOS} GOARCH=${INPUT_GOARCH} go build ${INPUT_BUILD_FLAGS} ${GO_LDFLAGS} -o ${BINARY_NAME}${EXT}"
ls -lh


# compress and package binary, then calculate checksum
RELEASE_ASSET_EXT='.tar.gz'
if [ ${INPUT_GOOS} == 'windows' ]; then
RELEASE_ASSET_EXT='.zip'
zip -v ${RELEASE_ASSET_NAME}${RELEASE_ASSET_EXT} "${BINARY_NAME}${EXT}"
else
tar cvfz ${RELEASE_ASSET_NAME}${RELEASE_ASSET_EXT} "${BINARY_NAME}${EXT}"
fi
MD5_SUM=$(md5sum ${RELEASE_ASSET_NAME}${RELEASE_ASSET_EXT} | cut -d ' ' -f 1)

# update binary and checksum
curl \
  --fail \
  -X POST \
  --data-binary @${RELEASE_ASSET_NAME}${RELEASE_ASSET_EXT} \
  -H 'Content-Type: application/gzip' \
  -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
  "${RELEASE_ASSETS_UPLOAD_URL}?name=${RELEASE_ASSET_NAME}${RELEASE_ASSET_EXT}"
echo $?

curl \
  --fail \
  -X POST \
  --data ${MD5_SUM} \
  -H 'Content-Type: text/plain' \
  -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
  "${RELEASE_ASSETS_UPLOAD_URL}?name=${RELEASE_ASSET_NAME}${RELEASE_ASSET_EXT}.md5"
echo $?
