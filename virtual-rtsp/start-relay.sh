#!/bin/bash

# FFMPEG_DEBUG="-v debug"

export PAGER=cat
export TERM=linux
# export NO_COLOR=1
export NO_PROMPT=1

export RTSP_PORT=8554

set -eo pipefail

pushd /opt

# Download the source URL to /tmp, this should be an ephemeral volume (emptyDir) in Kubernetes
if [ "${DOWNLOAD_SOURCE}" == "true" -a -n "${SOURCE_FORMAT}" -a -n "${SOURCE_URL}" ]
then
  echo "Downloading input file from '${SOURCE_URL}' to '/tmp/input.${SOURCE_FORMAT}'"
  wget -c -nv -O- "${SOURCE_URL}" > "/tmp/input.${SOURCE_FORMAT}"
  export SOURCE_URL="file:///tmp/input.${SOURCE_FORMAT}"
fi

echo "${SOURCE_URL}"
# export SOURCE_URL

if [[ "${SOURCE_URL}" == file://* ]]
then
  echo "Source comes from a file at '${SOURCE_URL}'"
  export FFMPEG_INPUT_ARGS="${FFMPEG_INPUT_ARGS} -re -stream_loop -1"
fi

if [[ "${SOURCE_URL}" == rtsp://* ]] && [ "${FORCE_FFMPEG_SOURCE}" == "false" ]
then
  echo "Source is RTSP: '${SOURCE_URL}'"
  envsubst < ./proxy.template.yml > ./proxy.yml
  echo "	./proxy.yml"
  # cat ./proxy.yml
  echo "Starting rtsp proxy from ${SOURCE_URL} to rtsp://0.0.0.0:${RTSP_PORT}/$STREAM_NAME..."
  rtsp-simple-proxy ./proxy.yml
else
  if [ "${SOURCE_URL}" != "" ]
  then
    envsubst < ./server.template.yml > ./server.yml
    echo "	./server.yml"
    # cat ./server.yml
    echo "Starting RTSP server..."
    rtsp-simple-server ./server.yml &
    sleep 5

    echo "Start relaying from ${SOURCE_URL} to rtsp://0.0.0.0:${RTSP_PORT}/${STREAM_NAME}"
    while true
    do
      set -x
      ffmpeg ${FFMPEG_DEBUG} ${FFMPEG_INPUT_ARGS} -i ${SOURCE_URL} ${FFMPEG_OUTPUT_ARGS} -f rtsp rtsp://127.0.0.1:${RTSP_PORT}/${STREAM_NAME}
      set +x
      echo "Reconnecting..."
      sleep 5
    done
  else
    echo "Won't restream a source feed to the server because SOURCE_URL was not defined"
    echo "Starting RTSP server. You can publish feeds to it"
    echo "ex.: ffmpeg -i somesource.mjpg -c copy -f rtsp rtsp://localhost:8554/myfeed"
    rtsp-simple-server
  fi
fi
