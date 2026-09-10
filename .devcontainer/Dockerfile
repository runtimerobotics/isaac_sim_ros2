# syntax=docker/dockerfile:1.7
#
# This image deliberately builds the complete pinned Isaac Sim ROS 2 workspace.
# A Docker build is therefore an acceptance test, not merely a dependency image.
FROM nvcr.io/nvidia/isaac-sim:6.0.1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The Isaac Sim base image runs as an unprivileged user.  Package installation
# and the system-wide ROS/locale setup below must run as root.
USER root

ARG DEBIAN_FRONTEND=noninteractive
ARG ISAACLAB_REF=v3.0.0-beta2.patch1
ARG ISAACSIM_ROS_REF=IsaacSim-6.0.1

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    ROS_DISTRO=jazzy \
    RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
    ROS_DOMAIN_ID=0 \
    ISAACSIM_PATH=/isaac-sim \
    ISAACSIM_PYTHON_EXE=/isaac-sim/python.sh \
    COLCON_HOME=/workspace/.colcon

# Isaac Sim 6.0.1 is required to be a Noble-based image for this configuration.
# Do not silently add a Jazzy apt repository to a different Ubuntu release.
RUN . /etc/os-release && test "$VERSION_ID" = "24.04" && test "$VERSION_CODENAME" = "noble"

# The NGC image normally exposes this path. Keep the assertion explicit because
# Isaac Lab must use this exact installation, never a second downloaded copy.
RUN test -d /isaac-sim && test -x /isaac-sim/python.sh

RUN mkdir -p /var/lib/apt/lists/partial \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg2 locales lsb-release software-properties-common \
    && locale-gen en_US.UTF-8 \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        | gpg --dearmor -o /etc/apt/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu noble main" \
        > /etc/apt/sources.list.d/ros2.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential cmake git curl wget \
        python3-rosdep python3-colcon-common-extensions python3-vcstool \
        ros-jazzy-desktop ros-jazzy-rmw-fastrtps-cpp \
    && rm -rf /var/lib/apt/lists/*

# rosdep init is system-wide and can already have been done by an upstream base.
RUN if ! rosdep init 2>/dev/null; then test -f /etc/ros/rosdep/sources.list.d/20-default.list; fi \
    && rosdep update

RUN mkdir -p /workspace/ros2_ws/src /workspace/build-reports

COPY .devcontainer/scripts/install_and_build_isaac_ros.sh /usr/local/bin/install_and_build_isaac_ros.sh
RUN chmod 0755 /usr/local/bin/install_and_build_isaac_ros.sh \
    && ISAACLAB_REF="${ISAACLAB_REF}" ISAACSIM_ROS_REF="${ISAACSIM_ROS_REF}" \
       /usr/local/bin/install_and_build_isaac_ros.sh

COPY .devcontainer/scripts/entrypoint.sh /usr/local/bin/isaac-ros-entrypoint.sh
RUN chmod 0755 /usr/local/bin/isaac-ros-entrypoint.sh

WORKDIR /workspace/ros2_ws
ENTRYPOINT ["/usr/local/bin/isaac-ros-entrypoint.sh"]
CMD ["bash"]
