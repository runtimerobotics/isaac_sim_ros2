# Isaac Sim 6.0.1 ROS 2 Jazzy dev container

This Dev Container is intentionally an all-or-nothing build. It starts from
`nvcr.io/nvidia/isaac-sim:6.0.1`, asserts Ubuntu 24.04, installs ROS 2 Jazzy,
clones only `IsaacLab@v3.0.0-beta2.patch1` and
`IsaacSim-ros_workspaces@IsaacSim-6.0.1`, and builds every package in the
pinned `jazzy_ws`. It never uses `--packages-skip` or rosdep skip keys.

Before **Dev Containers: Rebuild and Reopen in Container**, authenticate Docker
to NGC if your organization requires it. On a Linux graphical host, permit the
container to use the current X server for this session:

```bash
xhost +si:localuser:root
```

The container uses host networking and the host's `ROS_DOMAIN_ID` when set
(otherwise `0`), `rmw_fastrtps_cpp`, NVIDIA GPU access, and the X11 Unix socket.
It creates persistent Kit cache volumes so rebuilding the development image
does not require redownloading Isaac Sim assets.

After it builds, inspect the immutable acceptance records:

```bash
cat /workspace/build-reports/isaac_ros_build_summary.txt
cat /workspace/build-reports/isaac_ros_packages.txt
source /workspace/IsaacSim-ros_workspaces/jazzy_ws/install/setup.bash
ros2 pkg prefix isaacsim_bringup
ros2 pkg prefix isaac_tutorials
```

The shared Isaac Sim link is verified during build:

```bash
readlink -f /workspace/IsaacLab/_isaac_sim
# /isaac-sim
```

To run the installed simulator with its ROS 2 bridge enabled, use a container
terminal after the X11 permission command above:

```bash
/isaac-sim/isaac-sim.sh --/isaac/startup/ros_bridge_extension=isaacsim.ros2.bridge
```

`/workspace/ros2_ws` is the bind-mounted user workspace. Build it separately
when it has packages:

```bash
cd /workspace/ros2_ws
colcon build --symlink-install
source install/setup.bash
```
