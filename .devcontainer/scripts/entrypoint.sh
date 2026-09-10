#!/usr/bin/env bash
set -e

source /opt/ros/jazzy/setup.bash
if [ -f /workspace/IsaacSim-ros_workspaces/jazzy_ws/install/setup.bash ]; then
  source /workspace/IsaacSim-ros_workspaces/jazzy_ws/install/setup.bash
fi
if [ -f /workspace/ros2_ws/install/setup.bash ]; then
  source /workspace/ros2_ws/install/setup.bash
fi

export ISAACSIM_PATH=/isaac-sim
export ISAACSIM_PYTHON_EXE=/isaac-sim/python.sh
export ROS_DISTRO=jazzy
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"

exec "$@"
