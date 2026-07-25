#!/bin/bash
#
# Shared OpenJDK installer.
# OneinStack installs only GPLv2+CPE OpenJDK distributions from the operating
# system or Eclipse Temurin. Oracle JDK is intentionally not downloaded.

JDK_Major_From_Home() {
  local java_home=$1
  local specification_version

  [ -x "${java_home}/bin/java" ] || return 1
  specification_version=$(
    "${java_home}/bin/java" -XshowSettings:properties -version 2>&1 |
      awk -F= '/^[[:space:]]*java.specification.version =/ {
        gsub(/[[:space:]]/, "", $2)
        print $2
        exit
      }'
  )
  [ "${specification_version}" = '1.8' ] && specification_version=8
  printf '%s\n' "${specification_version}"
}

JDK_Home_From_Package() {
  local package_name=$1
  local javac_path

  if [ "${Family}" = 'rhel' ]; then
    javac_path=$(rpm -ql "${package_name}" 2>/dev/null | awk '/\/bin\/javac$/ { print; exit }')
  else
    javac_path=$(dpkg-query -L "${package_name}" 2>/dev/null | awk '/\/bin\/javac$/ { print; exit }')
  fi
  [ -n "${javac_path}" ] || return 1
  dirname "$(dirname "${javac_path}")"
}

Find_JDK_Home() {
  local expected_major=$1
  local package_name=$2
  local java_home javac_path

  java_home=$(JDK_Home_From_Package "${package_name}") || true
  if [ -n "${java_home}" ] &&
    [ "$(JDK_Major_From_Home "${java_home}")" = "${expected_major}" ]; then
    printf '%s\n' "${java_home}"
    return 0
  fi

  for javac_path in /usr/lib/jvm/*/bin/javac; do
    [ -e "${javac_path}" ] || continue
    java_home=$(dirname "$(dirname "${javac_path}")")
    if [ "$(JDK_Major_From_Home "${java_home}")" = "${expected_major}" ]; then
      printf '%s\n' "${java_home}"
      return 0
    fi
  done
  return 1
}

System_OpenJDK_Package() {
  local major=$1

  if [ "${Family}" = 'rhel' ]; then
    [ "${major}" = '8' ] &&
      printf '%s\n' 'java-1.8.0-openjdk-devel' ||
      printf 'java-%s-openjdk-devel\n' "${major}"
  else
    printf 'openjdk-%s-jdk\n' "${major}"
  fi
}

System_OpenJDK_Available() {
  local package_name=$1

  if [ "${Family}" = 'rhel' ]; then
    "${PM}" -q list "${package_name}" >/dev/null 2>&1
  else
    apt-cache policy "${package_name}" 2>/dev/null |
      awk '/^[[:space:]]*Candidate:/ { found=1; if ($2 != "(none)") available=1 }
        END { exit !(found && available) }'
  fi
}

Verify_Adoptium_Key() {
  local key_file="${oneinstack_dir}/src/adoptium.key"
  local actual_fingerprint expected_fingerprint

  expected_fingerprint=$(printf '%s' "${adoptium_repo_gpg_finger}" | tr '[:lower:]' '[:upper:]')
  [ -n "${expected_fingerprint}" ] || {
    echo "${CFAILURE}Adoptium repository fingerprint is not configured.${CEND}"
    return 1
  }
  [ -s "${key_file}" ] || {
    echo "${CFAILURE}Bundled Adoptium repository key is missing: ${key_file}${CEND}"
    return 1
  }

  command -v gpg >/dev/null 2>&1 || {
    if [ "${Family}" = 'rhel' ]; then
      "${PM}" -y install gnupg2 || return 1
    else
      apt-get --no-install-recommends -y install gnupg ca-certificates || return 1
    fi
  }

  actual_fingerprint=$(
    gpg --batch --show-keys --with-colons "${key_file}" 2>/dev/null |
      awk -F: '$1 == "fpr" { print toupper($10); exit }'
  )
  if [ "${actual_fingerprint}" != "${expected_fingerprint}" ]; then
    echo "${CFAILURE}Adoptium repository key fingerprint mismatch.${CEND}"
    echo "Expected: ${expected_fingerprint}"
    echo "Actual:   ${actual_fingerprint:-unavailable}"
    return 1
  fi
}

Adoptium_Deb_Codename() {
  local codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}

  if [ -z "${codename}" ]; then
    if [ "${Family}" = 'ubuntu' ]; then
      case "${Ubuntu_ver}" in
        16) codename=xenial ;;
        18) codename=bionic ;;
        20) codename=focal ;;
        22) codename=jammy ;;
        24) codename=noble ;;
        26) codename=resolute ;;
      esac
    else
      case "${Debian_ver}" in
        9) codename=stretch ;;
        10) codename=buster ;;
        11) codename=bullseye ;;
        12) codename=bookworm ;;
        13) codename=trixie ;;
      esac
    fi
  fi
  [ -n "${codename}" ] || return 1
  printf '%s\n' "${codename}"
}

Configure_Adoptium_Repository() {
  local codename keyring_file repo_key_file

  Verify_Adoptium_Key || return 1
  if [ "${Family}" = 'rhel' ]; then
    repo_key_file=/etc/pki/rpm-gpg/RPM-GPG-KEY-adoptium
    install -d -m 0755 /etc/pki/rpm-gpg
    install -m 0644 "${oneinstack_dir}/src/adoptium.key" "${repo_key_file}"
    cat > /etc/yum.repos.d/adoptium.repo << EOF
[Adoptium]
name=Eclipse Temurin
baseurl=https://packages.adoptium.net/artifactory/rpm/rhel/\$releasever/\$basearch
enabled=1
gpgcheck=1
gpgkey=file://${repo_key_file}
EOF
  else
    codename=$(Adoptium_Deb_Codename) || {
      echo "${CFAILURE}Unable to determine the Debian/Ubuntu codename for Adoptium.${CEND}"
      return 1
    }
    keyring_file=/usr/share/keyrings/adoptium.gpg
    install -d -m 0755 /usr/share/keyrings
    gpg --batch --yes --dearmor --output "${keyring_file}" \
      "${oneinstack_dir}/src/adoptium.key" || return 1
    chmod 0644 "${keyring_file}"
    cat > /etc/apt/sources.list.d/adoptium.list << EOF
deb [signed-by=${keyring_file}] https://packages.adoptium.net/artifactory/deb ${codename} main
EOF
    apt-get -y update || return 1
  fi
}

Install_Temurin() {
  local major=$1
  local package_name="temurin-${major}-jdk"

  Configure_Adoptium_Repository || return 1
  "${PM}" -y install "${package_name}" || return 1
  JDK_INSTALLED_PACKAGE=${package_name}
}

Write_OpenJDK_Profile() {
  local major=$1

  cat > /etc/profile.d/openjdk.sh << EOF
export JAVA_HOME=${JAVA_HOME}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
  if [ "${major}" = '8' ]; then
    cat >> /etc/profile.d/openjdk.sh << 'EOF'
export CLASSPATH=$JAVA_HOME/lib/tools.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib
EOF
  fi
  chmod 0644 /etc/profile.d/openjdk.sh
  . /etc/profile.d/openjdk.sh
}

Verify_OpenJDK_Installation() {
  local expected_major=$1
  local actual_major java_vendor java_runtime_version

  actual_major=$(JDK_Major_From_Home "${JAVA_HOME}") || return 1
  [ "${actual_major}" = "${expected_major}" ] || {
    echo "${CFAILURE}Installed JDK major version mismatch.${CEND}"
    echo "Expected: ${expected_major}; Actual: ${actual_major:-unavailable}"
    return 1
  }
  java_vendor=$(
    "${JAVA_HOME}/bin/java" -XshowSettings:properties -version 2>&1 |
      awk -F= '/^[[:space:]]*java.vendor =/ {
        sub(/^[[:space:]]*/, "", $2); sub(/[[:space:]]*$/, "", $2)
        print $2; exit
      }'
  )
  java_runtime_version=$(
    "${JAVA_HOME}/bin/java" -XshowSettings:properties -version 2>&1 |
      awk -F= '/^[[:space:]]*java.runtime.version =/ {
        sub(/^[[:space:]]*/, "", $2); sub(/[[:space:]]*$/, "", $2)
        print $2; exit
      }'
  )
  echo "JDK vendor: ${java_vendor:-unknown}"
  echo "JDK runtime: ${java_runtime_version:-unknown}"
  echo "JDK home: ${JAVA_HOME}"
  echo "JDK distribution policy: GPLv2+CPE OpenJDK only; Oracle JDK was not installed."
}

Install_OpenJDK() {
  local major=$1
  local package_name system_package

  system_package=$(System_OpenJDK_Package "${major}")
  if System_OpenJDK_Available "${system_package}" &&
    "${PM}" -y install "${system_package}"; then
    package_name=${system_package}
    echo "Using operating-system OpenJDK package: ${package_name}"
  else
    echo "OpenJDK ${major} is unavailable from the operating-system repository."
    echo "Falling back to the fingerprint-pinned Eclipse Temurin repository."
    Install_Temurin "${major}" || return 1
    package_name=${JDK_INSTALLED_PACKAGE}
  fi

  JAVA_HOME=$(Find_JDK_Home "${major}" "${package_name}") || {
    echo "${CFAILURE}Unable to locate the installed OpenJDK ${major} home.${CEND}"
    return 1
  }
  export JAVA_HOME
  Write_OpenJDK_Profile "${major}" || return 1
  Verify_OpenJDK_Installation "${major}" || return 1
  echo "${CSUCCESS}OpenJDK ${major} installed successfully! ${CEND}"
}
