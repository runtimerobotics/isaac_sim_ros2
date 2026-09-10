#!/usr/bin/env bash
# Runs during `docker build`. Do not weaken this script with skip keys or
# best-effort error handling: a non-zero result means the dev container failed.
set -Eeuo pipefail

readonly workspace=/workspace
readonly reports="${workspace}/build-reports"
readonly isaac_lab="${workspace}/IsaacLab"
readonly isaac_ros="${workspace}/IsaacSim-ros_workspaces"
readonly jazzy_ws="${isaac_ros}/jazzy_ws"
readonly lab_ref="${ISAACLAB_REF:?ISAACLAB_REF is required}"
readonly ros_ref="${ISAACSIM_ROS_REF:?ISAACSIM_ROS_REF is required}"

source_setup() {
  # Generated ROS/ament setup scripts read optional tracing variables that may
  # be unset in a clean Docker build environment.  Keep nounset for this build
  # script, but not while evaluating those generated scripts.
  set +u
  source "$1"
  set -u
}

mkdir -p "${reports}"
source_setup /opt/ros/jazzy/setup.bash
test "${ROS_DISTRO}" = jazzy
python3 --version | tee "${reports}/python_version.txt"
python3 -c 'import sys; assert sys.version_info[:2] == (3, 12), sys.version'

git clone --depth 1 --branch "${lab_ref}" https://github.com/isaac-sim/IsaacLab.git "${isaac_lab}"
git -C "${isaac_lab}" describe --exact-match --tags HEAD | grep -Fx "${lab_ref}"
ln -s /isaac-sim "${isaac_lab}/_isaac_sim"
test -L "${isaac_lab}/_isaac_sim"
test "$(readlink -f "${isaac_lab}/_isaac_sim")" = /isaac-sim

git clone --depth 1 --branch "${ros_ref}" https://github.com/isaac-sim/IsaacSim-ros_workspaces.git "${isaac_ros}"
git -C "${isaac_ros}" describe --exact-match --tags HEAD | grep -Fx "${ros_ref}"
git -C "${isaac_ros}" submodule sync --recursive
git -C "${isaac_ros}" submodule update --init --recursive
if git -C "${isaac_ros}" submodule status --recursive | grep -Eq '^[+-]'; then
  echo 'ERROR: uninitialized, missing, or mismatched submodule' >&2
  git -C "${isaac_ros}" submodule status --recursive >&2
  exit 1
fi

cd "${jazzy_ws}"
colcon list | tee "${reports}/isaac_ros_packages.txt"
awk '{print $1}' "${reports}/isaac_ros_packages.txt" | sort -u > "${reports}/isaac_ros_package_names.txt"
package_count=$(wc -l < "${reports}/isaac_ros_package_names.txt" | tr -d ' ')
test "${package_count}" -gt 0

# First check makes missing rosdep keys visible in the build log. The second is
# mandatory and proves rosdep resolved every package.xml dependency.
if ! rosdep check --from-paths src --ignore-src --rosdistro jazzy 2>&1 | tee "${reports}/rosdep_check_before.log"; then
  # The dependency-image layer clears APT indexes to keep the image small.
  # rosdep invokes apt-get itself, so refresh its package metadata first.
  mkdir -p /var/lib/apt/lists/partial
  apt-get update
  PIP_BREAK_SYSTEM_PACKAGES=1 rosdep install --from-paths src --ignore-src --rosdistro jazzy -r -y 2>&1 \
    | tee "${reports}/rosdep_install.log"
  # rosdep's pip dependencies can replace setuptools and remove pkg_resources,
  # which is required by Ubuntu's /usr/bin/rosdep entry point.  Restore the
  # distro-provided module before the mandatory post-install rosdep check.
  apt-get install --reinstall -y python3-pkg-resources
  /usr/bin/python3 -c 'import pkg_resources'
  rm -rf /var/lib/apt/lists/*
fi
rosdep check --from-paths src --ignore-src --rosdistro jazzy 2>&1 | tee "${reports}/rosdep_check_after.log"

rm -rf build install log
colcon build --symlink-install --event-handlers console_direct+ 2>&1 | tee "${reports}/isaac_ros_colcon_build.log"
test -f install/setup.bash
test -f install/local_setup.bash

source_setup /opt/ros/jazzy/setup.bash
source_setup install/setup.bash
while IFS= read -r package; do
  ros2 pkg prefix "${package}" >> "${reports}/isaac_ros_package_prefixes.txt"
done < "${reports}/isaac_ros_package_names.txt"
for package in isaacsim_bringup isaac_tutorials; do
  if grep -Fxq "${package}" "${reports}/isaac_ros_package_names.txt"; then
    ros2 pkg prefix "${package}"
  fi
done

# A second build catches generated-environment and ament_python ordering bugs.
colcon build --symlink-install 2>&1 | tee -a "${reports}/isaac_ros_colcon_build.log"

failed=$(grep -Eic '(^|[[:space:]])[0-9]+ packages? failed|^Failed[[:space:]]*<<|^Failed[[:space:]]*>>' "${reports}/isaac_ros_colcon_build.log" || true)
aborted=$(grep -Eic '(^|[[:space:]])[0-9]+ packages? aborted|^Aborted[[:space:]]*<<|^Aborted[[:space:]]*>>' "${reports}/isaac_ros_colcon_build.log" || true)
stderr_packages=$(sed -nE 's/^Summary: ([0-9]+) packages? had stderr output.*/\1/p' "${reports}/isaac_ros_colcon_build.log" | tail -n1)
stderr_packages=${stderr_packages:-0}
successful=$(sed -nE 's/^Summary: ([0-9]+) packages finished.*/\1/p' "${reports}/isaac_ros_colcon_build.log" | tail -n1)
successful=${successful:-0}
if (( failed != 0 || aborted != 0 || successful != package_count )); then
  echo "ERROR: incomplete colcon build: finished=${successful}, expected=${package_count}, failed=${failed}, aborted=${aborted}" >&2
  exit 1
fi

{
  printf 'git_commit=%s\n' "$(git -C "${isaac_ros}" rev-parse HEAD)"
  printf 'git_tag=%s\n' "$(git -C "${isaac_ros}" describe --exact-match --tags HEAD)"
  printf 'ros_distro=%s\n' "${ROS_DISTRO}"
  printf 'python_version=%s\n' "$(python3 --version)"
  printf 'total_package_count=%s\n' "${package_count}"
  printf 'successful_package_count=%s\n' "${successful}"
  printf 'failed_package_count=%s\n' "${failed}"
  printf 'aborted_package_count=%s\n' "${aborted}"
  printf 'packages_with_stderr=%s\n' "${stderr_packages}"
  printf 'rosdep_status=resolved\n'
} > "${reports}/isaac_ros_build_summary.txt"
