# Isaac Sim 6 + ROS 2 Jazzy development container

This repository provides a reproducible development container for NVIDIA Isaac
Sim 6.0.1, Isaac Lab, and the Isaac Sim ROS 2 Jazzy workspaces.  It is intended
for developing and running the ROS 2 bridge against the Isaac Sim installation
included in NVIDIA's container image.

## What the image builds

The image is based on `nvcr.io/nvidia/isaac-sim:6.0.1` and verifies that the
base is Ubuntu 24.04 (Noble).  During the image build it:

- installs ROS 2 Jazzy desktop and Fast DDS;
- clones `IsaacLab` at `v3.0.0-beta2.patch1` and links its `_isaac_sim` path to
  the image's `/isaac-sim` installation;
- clones `IsaacSim-ros_workspaces` at `IsaacSim-6.0.1`, including submodules;
- resolves its ROS dependencies and builds every package in `jazzy_ws` twice.

The build fails if any package is unresolved, fails, aborts, or is omitted.
It is therefore an image acceptance build, not a minimal runtime image.

## Prerequisites

- Linux host with a supported NVIDIA driver and Docker GPU support
  (`docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi`
  should work).
- Docker Buildx and either VS Code with the **Dev Containers** extension or the
  `devcontainer` CLI.
- Access to NVIDIA's NGC registry if your organisation requires authentication.
  Authenticate before building:

  ```bash
  docker login nvcr.io
  ```

  Use `$oauthtoken` as the username and an NGC API key as the password.

## Open with VS Code

1. Clone the repository and open its root directory in VS Code.
2. Run **Dev Containers: Rebuild and Reopen in Container**.
3. Wait for the full image build to complete.  The first build downloads the
   Isaac Sim base image and builds the full ROS workspace, so it can take time.

The dev container uses host networking, all host GPUs, and the host's
`ROS_DOMAIN_ID` when it is set (otherwise `0`).  It mounts persistent Docker
volumes for Isaac Sim Kit caches, so those assets survive image rebuilds.

## Build without VS Code

From the repository root, build the same Dockerfile and context used by the dev
container:

```bash
docker buildx build \
  --load \
  --tag isaac-sim-ros2:local \
  --file .devcontainer/Dockerfile \
  .
```

For graphical Isaac Sim on a Linux desktop, permit root in the local container
to use the current X server for the current session:

```bash
xhost +si:localuser:root
```

Then run the image:

```bash
docker run --rm -it \
  --gpus all \
  --network host \
  --ipc host \
  --env DISPLAY="$DISPLAY" \
  --env ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}" \
  --volume /tmp/.X11-unix:/tmp/.X11-unix:rw \
  --volume isaac-sim-kit-cache:/root/.cache/ov \
  --volume isaac-sim-kit-data:/root/.local/share/ov \
  --volume "$PWD":/workspace/ros2_ws \
  isaac-sim-ros2:local
```

When you are finished, revoke that X11 permission:

```bash
xhost -si:localuser:root
```

## Verify the prebuilt ROS workspace

Inside the container, the entrypoint sources ROS 2 Jazzy and the built Isaac
Sim ROS workspace.  Inspect the build records and installed packages with:

```bash
cat /workspace/build-reports/isaac_ros_build_summary.txt
cat /workspace/build-reports/isaac_ros_packages.txt
ros2 pkg prefix isaacsim_bringup
ros2 pkg prefix isaac_tutorials
readlink -f /workspace/IsaacLab/_isaac_sim
```

The final command should print `/isaac-sim`.

## Start Isaac Sim with the ROS 2 bridge

From a graphical container terminal:

```bash
/isaac-sim/isaac-sim.sh \
  --/isaac/startup/ros_bridge_extension=isaacsim.ros2.bridge
```

This starts the simulator with the bridge extension enabled.  It does not by
itself prove end-to-end ROS communication; confirm the expected ROS 2 nodes,
topics, and message flow for the scene or tutorial you run.

## Your workspace

The repository is bind-mounted at `/workspace/ros2_ws`.  Add your own ROS 2
packages under `src/`, then build them independently:

```bash
cd /workspace/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

The project pins its Isaac Lab and Isaac Sim ROS workspace revisions in
`.devcontainer/devcontainer.json`; update them there deliberately and rebuild
the image when changing versions.
