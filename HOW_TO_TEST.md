# How to Test GPU Support for OpenAI Whisper

This guide outlines the steps to test the GPU-accelerated OpenAI Whisper transcription feature within the Dockerized application.

## Prerequisites

1.  **NVIDIA GPU:** Your machine must have an NVIDIA GPU compatible with CUDA.
2.  **NVIDIA Drivers:** Ensure you have the latest NVIDIA drivers installed for your GPU on your host system.
3.  **Docker:** Docker must be installed and running.
4.  **NVIDIA Docker Toolkit:** Install the NVIDIA Docker Toolkit (e.g., `nvidia-docker2` or `nvidia-container-toolkit`) to enable Docker containers to access the host's GPU. You might need to restart the Docker service after installation.
    *   Installation guide: [https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

## Testing Procedure

1.  **Clone the Repository (if you haven't already):**
    ```bash
    # Replace with your repository's URL
    git clone <repository_url>
    cd <repository_directory>
    git checkout feature/gpu-whisper-support # Or the branch with GPU changes
    ```

2.  **Build the Docker Image:**
    Navigate to the root directory of the project (where the `Dockerfile` is located) and run:
    ```bash
    docker build -t whisper-gpu-app .
    ```
    *(You can replace `whisper-gpu-app` with your preferred image name)*.
    This process might take some time as it downloads base images and builds dependencies.

3.  **Run the Docker Container with GPU Access:**
    Once the image is built successfully, run the container:
    ```bash
    # Ensure this port mapping matches your application's configured port
    docker run --gpus all -p 8080:8080 whisper-gpu-app
    ```
    *   `--gpus all`:  Makes all available host GPUs accessible to the container.
    *   `-p 8080:8080`: Maps port 8080 on your host to port 8080 in the container. Adjust if your application uses a different port.

4.  **Execute a Transcription Request:**
    While the container is running, send an API request to one of the transcription endpoints (e.g., `/transcribe-media` or `/v1/media/transcribe`).
    *   You can use tools like `curl`, Postman, or a custom client application.
    *   **Example using `curl` (adjust URL, endpoint, and file path as needed):**
        ```bash
        # Assuming your app has an endpoint that accepts a 'media_url'
        curl -X POST -F "media_url=<URL_TO_YOUR_MEDIA_FILE_OR_LOCAL_PATH_IF_HANDLED>" http://localhost:8080/v1/media/transcribe 
        # Or if it accepts file uploads:
        # curl -X POST -F "file=@/path/to/your/audio.mp3" http://localhost:8080/v1/media/transcribe
        ```
    *   Use a media file that is sufficiently long to observe GPU activity.

5.  **Monitor GPU Usage (in a separate terminal):**
    While the transcription request is being processed, open a new terminal on your **host machine** and run:
    ```bash
    nvidia-smi
    ```
    *   Observe the output. You should see a Python process (related to Whisper/PyTorch) utilizing one of your GPUs. The GPU memory usage and GPU-Util percentage for that process should increase.
    *   You can also use `watch -n 1 nvidia-smi` for continuous monitoring.

6.  **Verify Output and Application Logs:**
    *   **API Response:** Check the transcription result returned by the API for accuracy and correct formatting.
    *   **Container Logs:** Inspect the logs from your running Docker container.
        *   First, find your container's ID or name: `docker ps`
        *   Then, view its logs: `docker logs <container_id_or_name>`
        *   Look for log messages indicating the device being used, such as:
            *   `INFO: Using device: cuda for Whisper model`
            *   `INFO: Loaded Whisper base model on cuda` (the model name might vary)

7.  **Optional: Test CPU Fallback:**
    To ensure the application correctly falls back to CPU if a GPU is not available or not requested:
    *   Stop the GPU-enabled container: `docker stop <container_id_or_name>` (get name/ID from `docker ps`).
    *   Run the container *without* the `--gpus all` flag:
        ```bash
        docker run -p 8080:8080 whisper-gpu-app
        ```
    *   Execute another transcription request.
    *   Check the container logs. You should now see messages like:
        *   `INFO: Using device: cpu for Whisper model`
    *   The transcription process will likely be noticeably slower on the CPU.

## Troubleshooting

*   **`docker build` fails:**
    *   Carefully examine the error messages in the build output.
    *   Ensure your Docker and network setup are correct.
    *   Check for compatibility issues with the base image or dependencies.
*   **Container fails to start or exits immediately:**
    *   Use `docker logs <container_id_or_name>` to get error messages from the application startup.
*   **GPU not utilized during transcription:**
    *   Verify that NVIDIA drivers are correctly installed on the host.
    *   Ensure the NVIDIA Docker Toolkit is installed and the Docker service was restarted.
    *   Confirm that the `--gpus all` flag was used in the `docker run` command.
    *   Check the container logs to see if it reported using "cuda" or "cpu".
*   **Transcription errors or unexpected behavior:**
    *   Consult the application logs within the container for specific error messages from Whisper, PyTorch, or other application components.
