#!/usr/bin/make -f

SHELL=/bin/bash

IFACE=virbr0
IP_ADDR=$(shell ip addr show dev "${IFACE}" | egrep '\<inet\>' | awk '{print $$2}' | cut -d '/' -f 1)

PYTHON_SCRIPT=real_time_stream_analysis.py

RTSP_PORT=8554
# STREAM_URL=rtsp://127.0.0.1:${RTSP_PORT}/stream
STREAM_URL=rtsp://${IP_ADDR}:${RTSP_PORT}/stream

OVMS_PORT=9000
# OVMS_URL=localhost:${OVMS_PORT}
OVMS_URL=${IP_ADDR}:${OVMS_PORT}

VISUALIZER_HOST=0.0.0.0
VISUALIZER_PORT=5000

MODEL_NAME=person-vehicle-bike-detection
MODEL_ID=${MODEL_NAME}-2002
MODEL_URL=https://storage.openvinotoolkit.org/repositories/open_model_zoo/2022.1/models_bin/2/${MODEL_ID}/FP32

WORKSPACE_DIR=workspace/${MODEL_ID}

INPUT_VIDEO=input.mp4

RESTART=no

default:
	@echo "Please run each component in a separate terminal"
	@echo ""
	@echo "% make rtsp"
	@echo "% make openvino-model-server"
	@echo "% make openvino-stream-analysis"
	@echo ""

# https://github.com/kerberos-io/virtual-rtsp
# VIRTUAL_RTSP_CONTAINER=docker.io/kerberos/virtual-rtsp:1.0.6
VIRTUAL_RTSP_CONTAINER=quay.io/tonejito/virtual-rtsp:1.1
rtsp:
	docker run -it --rm --name virtual-rtsp \
	  -v $(CURDIR)/mp4:/samples \
	  -p ${RTSP_PORT}:${RTSP_PORT} \
	  -e SOURCE_URL=file:///samples/${INPUT_VIDEO} \
	  --restart=${RESTART} \
	  ${VIRTUAL_RTSP_CONTAINER} \
	;

# https://storage.openvinotoolkit.org/repositories/open_model_zoo/2022.1/models_bin/2/person-vehicle-bike-detection-2002/FP32/person-vehicle-bike-detection-2002.bin
# https://storage.openvinotoolkit.org/repositories/open_model_zoo/2022.1/models_bin/2/person-vehicle-bike-detection-2002/FP32/person-vehicle-bike-detection-2002.xml
get-model:
	test -d ${WORKSPACE_DIR}/1 || \
	  mkdir -vp ${WORKSPACE_DIR}/1
	test -f ${WORKSPACE_DIR}/1/${MODEL_ID}.bin || \
	  wget -c -nv -P ${WORKSPACE_DIR}/1 ${MODEL_URL}/${MODEL_ID}.bin
	test -f ${WORKSPACE_DIR}/1/${MODEL_ID}.xml || \
	  wget -c -nv -P ${WORKSPACE_DIR}/1 ${MODEL_URL}/${MODEL_ID}.xml

# https://github.com/openvinotoolkit/model_server (2023.0)
# MODEL_SERVER_CONTAINER=docker.io/openvino/model_server:2023.0
MODEL_SERVER_CONTAINER=quay.io/tonejito/openvino-model_server:2023.0
openvino-model-server:	get-model
	docker run -it --rm --name ovms \
	  -v $(CURDIR)/workspace/${MODEL_ID}:/model \
	  -p ${OVMS_PORT}:${OVMS_PORT} \
	  --restart=${RESTART} \
	  ${MODEL_SERVER_CONTAINER} \
	    --model_path /model \
	    --model_name ${MODEL_NAME} \
	    --layout NHWC:NCHW \
	    --port ${OVMS_PORT} \
	;

# https://docs.openvino.ai/2022.3/ovms_demo_real_time_stream_analysis.html
STREAM_ANALYSIS_CONTAINER=quay.io/tonejito/openvino-stream-analysis:v2023.0
openvino-stream-analysis:
	docker run -it --rm --name video-analysis \
	  -p ${VISUALIZER_PORT}:${VISUALIZER_PORT} \
	  --restart=${RESTART} \
	  ${STREAM_ANALYSIS_CONTAINER} \
	    --stream_url '${STREAM_URL}' \
	    --ovms_url '${OVMS_URL}' \
	    --model_name '${MODEL_NAME}' \
	    --visualizer_addr '${VISUALIZER_HOST}' \
	    --visualizer_port ${VISUALIZER_PORT} \
	;
