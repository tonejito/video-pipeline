# Virtual RTSP stream	v1.1

Grab a video file from `SOURCE_URL` and play it on loop while exposing it as an RTSP stream in port 8554.

The `Containerfile` was modified to run everything in `/opt` and store the downloaded file in `/tmp` if needed.

The container _entrypoint_ was modified to download the video from the URL if the `DOWNLOAD_SOURCE` parameter is set to `true`.
Be sure to also pass the `FORMAT` variable, which serves as the file extension for the downloaded file.

Check the `kubernetes.yaml` for a deployment, and service resources that can be useful to deploy this workload in k8s.

--------

**TODO**: Migrate from `aler9/rtsp-simple-server` and `aler9/rtsp-simple-proxy` to `bluenviron/mediamtx`.
