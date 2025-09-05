# Custom Llama-Swap Container Images

This repository contains custom instructions to build [llama-swap](https://github.com/mostlygeek/llama-swap) container images.
Currently, only the Vulkan backend is supported.

Available tags:
- `vulkan`, `v<llama-swap-version>-vulkan-b<llama.cpp-version>`: images using [config.example.yaml](config.example.yaml),
- `vulkan-constrained`, `v<llama-swap-version>-vulkan-constrained-b<llama.cpp-version>`: images using [config.constrained.yaml](config.constrained.yaml).

### Description

- The GitHub workflow runs daily to build images containing the latest llama-swap and [llama.cpp](https://github.com/ggml-org/llama.cpp) servers.
- The image is based on AlmaLinux 10 minimal.
- The AlmaLinux base is updated during each image build.
- The image has a disabled `root` account and password.
- An unprivileged `llama` user and group are used instead.
- The image is mostly compatible with the llama-swap [image](https://github.com/mostlygeek/llama-swap/pkgs/container/llama-swap), except that this image's unprivileged user is named `llama` and is used by default.

### Example Usage

The following examples are based on rootless Podman containers using AMD GPU, run on a user account.
On SELinux-enabled distributions, it may be necessary to execute the following command first: 
```shell
sudo setsebool -P container_use_devices true
```

The simple run:

```shell
podman run \
    --rm \
    --device '/dev/kfd' \
    --device '/dev/dri/renderD128' \
    -p 8080:8080 \
    --health-cmd '/usr/bin/curl --silent --show-error --fail http://localhost:8080/health' \
    ghcr.io/0rzech/llama-swap:vulkan
```

When using `Docker` instead of `Podman`, the `--health-cmd` is not needed, because the image has this instruction embedded.

For better security and to use your own config and model directory, you can do the following instead:

```shell
podman run \
    --rm \
    --cap-drop all \
    --security-opt no-new-privileges \
    --device '/dev/kfd' \
    --device '/dev/dri/renderD128' \
    -p 8080:8080 \
    --mount "type=bind,src=${HOME}/.config/llama-swap.yaml,dst=/home/llama/config.yaml,relabel=private,ro=true" \
    --mount "type=bind,src=${HOME}/.cache/llama.cpp,dst=/home/llama/.cache/llama.cpp,relabel=private" \
    --health-cmd '/usr/bin/curl --silent --show-error --fail http://localhost:8080/health' \
    ghcr.io/0rzech/llama-swap:vulkan \
        -config '/home/llama/config.yaml'
```

You can also use Podman Quadlets.
Just place the following `llama-swap.container` file in the `.config/containers/systemd/` directory:

```ini
[Unit]
Description=Llama Swap Server
After=network-online.target

[Container]
ContainerName=llama-swap
Image=ghcr.io/0rzech/llama-swap:vulkan
AutoUpdate=local

Exec=-config /home/llama/config.yaml
HealthCmd=/usr/bin/curl --silent --show-error --fail http://localhost:8080/health

PublishPort=8080:8080

DropCapability=ALL
NoNewPrivileges=true

AddDevice=/dev/kfd
AddDevice=/dev/dri/renderD128

Mount=type=bind,src=%h/.config/llama-swap.yaml,dst=/home/llama/config.yaml,relabel=private,ro=true
Mount=type=bind,src=%h/.cache/llama.cpp,dst=/home/llama/.cache/llama.cpp,relabel=private

[Service]
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
```

And then execute:

```shell
systemctl --user daemon-reload
systemctl --user enable llama-swap.service
systemctl --user start llama-swap.service
```
