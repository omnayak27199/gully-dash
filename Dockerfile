# Reproducible Godot Android debug-build environment.
# Versions are intentionally pinned; update them together with CI validation and docs.
FROM ubuntu:24.04

ARG GODOT_VERSION=4.7.2
ARG ANDROID_CMDLINE_TOOLS_REVISION=15859902
ARG ANDROID_CMDLINE_TOOLS_SHA256=4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583
ARG ANDROID_PLATFORM=android-36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK_VERSION=29.0.14206865
ARG ANDROID_CMAKE_VERSION=3.22.1

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    GODOT_VERSION=${GODOT_VERSION} \
    PATH=/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/usr/local/bin:/usr/bin:/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip zip bash openjdk-17-jdk-headless \
      libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxext6 \
      libxrender1 libxi6 libxrandr2 libxfixes3 libasound2t64 \
    && rm -rf /var/lib/apt/lists/*

# Install a pinned official Godot binary and matching export templates.
RUN set -eux; \
    curl --fail --location --retry 3 \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
      --output /tmp/godot.zip; \
    unzip -t /tmp/godot.zip; \
    unzip -q /tmp/godot.zip -d /tmp/godot-bin; \
    install -m 0755 /tmp/godot-bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot; \
    curl --fail --location --retry 3 \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
      --output /tmp/godot-templates.tpz; \
    unzip -t /tmp/godot-templates.tpz; \
    mkdir -p /opt/godot/export_templates/${GODOT_VERSION}.stable /tmp/godot-templates; \
    unzip -q /tmp/godot-templates.tpz -d /tmp/godot-templates; \
    cp -a /tmp/godot-templates/templates/. /opt/godot/export_templates/${GODOT_VERSION}.stable/; \
    chmod -R a+rX /opt/godot; \
    rm -rf /tmp/godot.zip /tmp/godot-bin /tmp/godot-templates.tpz /tmp/godot-templates; \
    godot --headless --version

# Install a pinned Android command-line tools archive and verify its SHA-256.
RUN set -eux; \
    mkdir -p /opt/android-sdk/cmdline-tools/latest /tmp/android-tools; \
    curl --fail --location --retry 3 \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_REVISION}_latest.zip" \
      --output /tmp/android-commandline-tools.zip; \
    echo "${ANDROID_CMDLINE_TOOLS_SHA256}  /tmp/android-commandline-tools.zip" | sha256sum --check -; \
    unzip -q /tmp/android-commandline-tools.zip -d /tmp/android-tools; \
    cp -a /tmp/android-tools/cmdline-tools/. /opt/android-sdk/cmdline-tools/latest/; \
    yes | sdkmanager --sdk_root=/opt/android-sdk --licenses >/dev/null || true; \
    sdkmanager --sdk_root=/opt/android-sdk \
      "platform-tools" \
      "platforms;${ANDROID_PLATFORM}" \
      "build-tools;${ANDROID_BUILD_TOOLS}" \
      "cmake;${ANDROID_CMAKE_VERSION}" \
      "ndk;${ANDROID_NDK_VERSION}"; \
    rm -rf /tmp/android-tools /tmp/android-commandline-tools.zip

# Keep readable Android SDK/JDK settings for non-root builds.
RUN mkdir -p /opt/godot && \
    printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/java_sdk_path = "%s"\nexport/android/android_sdk_path = "%s"\n' \
      "${JAVA_HOME}" "${ANDROID_HOME}" > /opt/godot/editor_settings-4.tres && \
    chmod a+r /opt/godot/editor_settings-4.tres

COPY docker/build-android.sh /usr/local/bin/build-android.sh
RUN chmod 0755 /usr/local/bin/build-android.sh && mkdir -p /workspace/build

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/build-android.sh"]
