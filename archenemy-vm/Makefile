# ==============================================================
#  Archenemy Virtual Machine Environment
# ==============================================================
#  Enhanced Makefile CLI with dynamic mirror selection using rankmirrors.
#  Includes an optional host-side pacman cache (USE_CACHE=1) exposed to the VM
#  via virtio-9p so we can mimic the USB cache workflow during local testing.
# ==============================================================

VM_NAME        := archenemy-vm
VM_DIR         := $(CURDIR)
ISO_NAME       := archlinux.iso
ISO_FILE       := $(VM_DIR)/$(ISO_NAME)
DISK_FILE      := $(VM_DIR)/$(VM_NAME).qcow2
DISK_SIZE      := 40G
RAM_MB         := 4096
CPUS           := 4
USE_CACHE     ?= 0
CACHE_ROOT     := $(VM_DIR)/vm-cache
PACMAN_CACHE_DIR := $(CACHE_ROOT)/pacman
CACHE_MOUNT_TAG := archenemy-cache

# --- Device / Driver configuration ---
GPU_DEVICE     := virtio-vga
AUDIO_DEVICE   := ich9-intel-hda
AUDIO_CODEC    := hda-duplex
UEFI_CODE_CANDIDATES := \
 /usr/share/OVMF/OVMF_CODE.fd \
 /usr/share/OVMF/x64/OVMF_CODE.fd \
 /usr/share/OVMF/OVMF_CODE.4m.fd \
 /usr/share/OVMF/x64/OVMF_CODE.4m.fd \
 /usr/share/edk2-ovmf/OVMF_CODE.fd \
 /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
 /usr/share/edk2-ovmf/OVMF_CODE.4m.fd \
 /usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd \
 /usr/share/edk2/x64/OVMF_CODE.fd \
 /usr/share/edk2/x64/OVMF_CODE.4m.fd
UEFI_VARS_CANDIDATES := \
 /usr/share/OVMF/OVMF_VARS.fd \
 /usr/share/OVMF/x64/OVMF_VARS.fd \
 /usr/share/OVMF/OVMF_VARS.4m.fd \
 /usr/share/OVMF/x64/OVMF_VARS.4m.fd \
 /usr/share/edk2-ovmf/OVMF_VARS.fd \
 /usr/share/edk2-ovmf/x64/OVMF_VARS.fd \
 /usr/share/edk2-ovmf/OVMF_VARS.4m.fd \
 /usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd \
 /usr/share/edk2/x64/OVMF_VARS.fd \
 /usr/share/edk2/x64/OVMF_VARS.4m.fd
UEFI_CODE      := $(firstword $(wildcard $(UEFI_CODE_CANDIDATES)))
UEFI_VARS_SRC  := $(firstword $(wildcard $(UEFI_VARS_CANDIDATES)))
UEFI_VARS      := $(VM_DIR)/OVMF_VARS.fd
SSH_FORWARD_PORT ?= 5901
VM_SSH_HOST   ?= localhost
VM_SSH_USER   ?= $(USER)
SSH_OPTIONS   ?=
LOG_LINES     ?= 200
INSTALL_LOG_PATH ?= /var/log/archenemy-install.log
MIRRORLIST_TMP := /tmp/mirrorlist
MIRROR_CMD     = awk '/Server = / {gsub("^Server = ", "", $$0); sub("/\\$$repo.*", "", $$0); print $$0; exit}' /etc/pacman.d/mirrorlist 2>/dev/null
MIRROR_URL     := $(shell $(MIRROR_CMD))
DETECTED_BRIDGE_IF := $(strip $(shell ip -o link show type bridge 2>/dev/null | head -n1 | cut -d: -f2 | tr -d ' '))
DETECTED_TAP_IF := $(strip $(shell ip tuntap show 2>/dev/null | head -n1 | cut -d: -f1))
NETWORK_MODE   ?= user
NETWORK_TAP_IF ?= $(if $(DETECTED_TAP_IF),$(DETECTED_TAP_IF),tap0)
NETWORK_TAP_UP ?= /etc/qemu-ifup
NETWORK_TAP_DOWN ?= /etc/qemu-ifdown
NETWORK_BRIDGE_IF ?= $(if $(DETECTED_BRIDGE_IF),$(DETECTED_BRIDGE_IF),virbr0)
NETWORK_BRIDGE_HELPER ?= /usr/lib/qemu/qemu-bridge-helper
QEMU_COMMON_ARGS = \
 -enable-kvm \
 -name $(VM_NAME) \
 -m $(RAM_MB) \
 -smp $(CPUS) \
 -drive file=$(DISK_FILE),format=qcow2 \
 -device $(GPU_DEVICE) \
 -device $(AUDIO_DEVICE) \
 -device $(AUDIO_CODEC),audiodev=snd0 \
 -audiodev pa,id=snd0,out.frequency=44100,out.channels=2 \
 -display gtk,gl=on \
 -machine type=q35,accel=kvm \
 -cpu host \
 -drive if=pflash,format=raw,readonly=on,file=$(UEFI_CODE) \
 -drive if=pflash,format=raw,file=$(UEFI_VARS)

ifeq ($(USE_CACHE),1)
QEMU_CACHE_ARGS = \
 -virtfs local,path=$(PACMAN_CACHE_DIR),mount_tag=$(CACHE_MOUNT_TAG),security_model=passthrough,id=cache0
else
QEMU_CACHE_ARGS =
endif

ifeq ($(NETWORK_MODE),tap)
QEMU_NET_ARGS = \
 -netdev tap,id=net0,ifname=$(NETWORK_TAP_IF),script=$(NETWORK_TAP_UP),downscript=$(NETWORK_TAP_DOWN) \
 -device virtio-net-pci,netdev=net0
else ifeq ($(NETWORK_MODE),bridge)
QEMU_NET_ARGS = \
 -netdev bridge,id=net0,br=$(NETWORK_BRIDGE_IF),helper=$(NETWORK_BRIDGE_HELPER) \
 -device virtio-net-pci,netdev=net0
else
QEMU_NET_ARGS = \
 -netdev user,id=net0,hostfwd=tcp::$(SSH_FORWARD_PORT)-:22 \
 -device virtio-net-pci,netdev=net0
endif

BLUE   := $(shell printf "\033[1;34m")
GREEN  := $(shell printf "\033[1;32m")
YELLOW := $(shell printf "\033[1;33m")
RED    := $(shell printf "\033[1;31m")
RESET  := $(shell printf "\033[0m")

msg_info = @bash -c 'printf "$(BLUE)[INFO]$(RESET) %s\n" "$(1)"'
msg_done = @bash -c 'printf "$(GREEN)[DONE]$(RESET) %s\n" "$(1)"'
msg_warn = @bash -c 'printf "$(YELLOW)[WARN]$(RESET) %s\n" "$(1)"'
msg_err  = @bash -c 'printf "$(RED)[ERROR]$(RESET) %s\n" "$(1)"'

.PHONY: all deps mirror iso image prepare run run-installed logs ssh clean cache cache-clean help

all: help

# --------------------------------------------------------------
# Dependencies
# --------------------------------------------------------------
deps:
	$(call msg_info,Installing virtualization dependencies...)
	sudo pacman -Syu --noconfirm --needed qemu-full libvirt virt-manager dnsmasq vde2 bridge-utils openbsd-netcat edk2-ovmf reflector pacman-contrib aria2
	sudo systemctl enable --now libvirtd
	sudo usermod -aG libvirt $$(whoami) || true
	$(call msg_done,Dependencies installed and libvirtd enabled.)

# --------------------------------------------------------------
# Dynamic mirror ranking (top 5 fastest mirrors)
# --------------------------------------------------------------
mirror:
	$(call msg_info,Ranking fastest Arch mirrors...)
	sudo cp /etc/pacman.d/mirrorlist $(MIRRORLIST_TMP).bak || true
	sudo rankmirrors -n 5 /etc/pacman.d/mirrorlist > $(MIRRORLIST_TMP)
	sudo mv $(MIRRORLIST_TMP) /etc/pacman.d/mirrorlist
	$(eval MIRROR_URL=$(shell $(MIRROR_CMD)))
	$(call msg_done,Top mirror: $(MIRROR_URL))

# --------------------------------------------------------------
# Download Arch ISO using best mirror
# --------------------------------------------------------------
iso: mirror
	$(call msg_info,Downloading Arch Linux ISO from $(MIRROR_URL))
	@if [ -f "$(ISO_FILE)" ]; then \
		printf "$(YELLOW)[WARN]$(RESET) ISO already exists at %s; delete it if you want a fresh copy.\n" "$(ISO_FILE)"; \
	else \
		curl -L --fail --retry 3 -C - --progress-bar -o $(ISO_FILE) $(MIRROR_URL)/iso/latest/archlinux-x86_64.iso; \
		$(call msg_done,ISO downloaded to $(ISO_FILE)); \
	fi

# --------------------------------------------------------------
# Create VM image and vars
# --------------------------------------------------------------
image:
	$(call msg_info,Creating QCOW2 disk image ($(DISK_SIZE))...)
	qemu-img create -f qcow2 $(DISK_FILE) $(DISK_SIZE)
	@if [ -z "$(UEFI_VARS_SRC)" ]; then \
		echo "Missing OVMF_VARS template (package edk2-ovmf)."; \
		exit 1; \
	fi
	cp $(UEFI_VARS_SRC) $(UEFI_VARS)
	$(call msg_done,Disk created at $(DISK_FILE))

prepare: deps iso image
	$(call msg_done,Environment ready for VM launch.)

# --------------------------------------------------------------
# Shared pacman cache helpers (QEMU-only, optional)
# --------------------------------------------------------------
cache:
	$(call msg_info,Preparing shared pacman cache at $(PACMAN_CACHE_DIR)...)
	mkdir -p $(PACMAN_CACHE_DIR)
	$(call msg_done,Pacman cache directory ready.)

cache-clean:
	$(call msg_warn,Removing shared pacman cache...)
	rm -rf $(CACHE_ROOT)
	$(call msg_done,Pacman cache removed.)

# --------------------------------------------------------------
# Run VM
# --------------------------------------------------------------
ifeq ($(USE_CACHE),1)
run: cache
run-installed: cache
endif

run:
	$(call msg_info,Launching $(VM_NAME) with QEMU...)
	@if [ -z "$(UEFI_CODE)" ]; then \
		echo "Missing OVMF_CODE firmware (package edk2-ovmf)."; \
		exit 1; \
	fi
	@if [ ! -f "$(UEFI_VARS)" ]; then \
		echo "UEFI vars file is missing. Run 'make image' first."; \
		exit 1; \
	fi
	@if [ ! -f "$(ISO_FILE)" ]; then \
		echo "Arch ISO missing at $(ISO_FILE). Run 'make iso' first."; \
		exit 1; \
	fi
	@if [ ! -f "$(DISK_FILE)" ]; then \
		echo "Disk image missing at $(DISK_FILE). Run 'make image' first."; \
		exit 1; \
	fi
	qemu-system-x86_64 $(QEMU_COMMON_ARGS) $(QEMU_NET_ARGS) $(QEMU_CACHE_ARGS) \
	  -boot d \
	  -cdrom $(ISO_FILE)
	$(call msg_done,VM launched successfully.)

run-installed:
	$(call msg_info,Booting installed system from disk...)
	@if [ -z "$(UEFI_CODE)" ]; then \
		echo "Missing OVMF_CODE firmware (package edk2-ovmf)."; \
		exit 1; \
	fi
	@if [ ! -f "$(UEFI_VARS)" ]; then \
		echo "UEFI vars file is missing. Run 'make image' first."; \
		exit 1; \
	fi
	@if [ ! -f "$(DISK_FILE)" ]; then \
		echo "Disk image missing at $(DISK_FILE). Run 'make image' first."; \
		exit 1; \
	fi
	qemu-system-x86_64 $(QEMU_COMMON_ARGS) $(QEMU_NET_ARGS) $(QEMU_CACHE_ARGS) \
	  -boot c
	$(call msg_done,Installed system booted successfully.)

logs:
	$(call msg_info,Streaming installer log from $(VM_SSH_USER)@$(VM_SSH_HOST)...)
	ssh $(SSH_OPTIONS) -p $(SSH_FORWARD_PORT) $(VM_SSH_USER)@$(VM_SSH_HOST) "sudo tail -n $(LOG_LINES) $(INSTALL_LOG_PATH)"

ssh:
	$(call msg_info,Opening SSH session to $(VM_SSH_USER)@$(VM_SSH_HOST)...)
	ssh $(SSH_OPTIONS) -p $(SSH_FORWARD_PORT) $(VM_SSH_USER)@$(VM_SSH_HOST)

clean:
	$(call msg_warn,Removing generated files...)
	rm -f $(ISO_FILE) $(DISK_FILE) $(UEFI_VARS)
	$(call msg_done,Environment cleaned.)

help:
	@echo "\n$(YELLOW)Archenemy VM CLI$(RESET)\n"
	@echo "Usage: make [target]\n"
	@echo "Targets:"
	@echo "  $(BLUE)deps$(RESET)       - Install dependencies"
	@echo "  $(BLUE)mirror$(RESET)     - Rank fastest Arch mirrors"
	@echo "  $(BLUE)iso$(RESET)        - Download Arch Linux ISO using top mirror"
	@echo "  $(BLUE)image$(RESET)      - Create QCOW2 disk"
	@echo "  $(BLUE)prepare$(RESET)    - Install deps, rank mirror, download ISO, and create disk"
	@echo "  $(BLUE)run$(RESET)        - Launch VM from installer ISO"
	@echo "  $(BLUE)run-installed$(RESET) - Boot the installed system from disk"
	@echo "  $(BLUE)logs$(RESET)       - Tail /var/log/archenemy-install.log via SSH"
	@echo "  $(BLUE)ssh$(RESET)        - Open an SSH session to the guest"
	@echo "  $(BLUE)cache$(RESET)      - Prepare shared pacman cache directory"
	@echo "  $(BLUE)cache-clean$(RESET) - Remove the shared pacman cache directory"
	@echo "  $(BLUE)clean$(RESET)      - Clean environment"
	@echo "  $(BLUE)help$(RESET)       - Show this help message\n"
	@echo "Example: make prepare && make run\n"
	@echo "Set USE_CACHE=1 when running 'make run' or 'make run-installed' to attach $(PACMAN_CACHE_DIR)"
	@echo "into the guest via virtio-9p (mount tag '$(CACHE_MOUNT_TAG)'). Inside the VM, run:"
	@echo "  curl -fsSL https://raw.githubusercontent.com/aldochaconc/archenemy/dev/archenemy-vm/bootstrap-vm.sh | bash"
	@echo "The VM bootstrap script mounts the shared cache automatically before invoking the installer.\n"
