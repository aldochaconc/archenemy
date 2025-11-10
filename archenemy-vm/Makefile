# ==============================================================
#  Archenemy Virtual Machine Environment
# ==============================================================
#  Enhanced Makefile CLI with dynamic mirror selection using rankmirrors
# ==============================================================

VM_NAME        := archenemy-vm
VM_DIR         := $(CURDIR)
ISO_NAME       := archlinux.iso
ISO_FILE       := $(VM_DIR)/$(ISO_NAME)
DISK_FILE      := $(VM_DIR)/$(VM_NAME).qcow2
DISK_SIZE      := 30G
RAM_MB         := 4096
CPUS           := 4
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
SPICE_PORT     := 5901
SCRIPTS_DIR    := $(VM_DIR)/scripts
MIRRORLIST_TMP := /tmp/mirrorlist
MIRROR_CMD     = awk '/Server = / {gsub("^Server = ", "", $$0); sub("/\\$$repo.*", "", $$0); print $$0; exit}' /etc/pacman.d/mirrorlist 2>/dev/null
MIRROR_URL     := $(shell $(MIRROR_CMD))

BLUE   := $(shell printf "\033[1;34m")
GREEN  := $(shell printf "\033[1;32m")
YELLOW := $(shell printf "\033[1;33m")
RED    := $(shell printf "\033[1;31m")
RESET  := $(shell printf "\033[0m")

msg_info = @bash -c 'printf "$(BLUE)[INFO]$(RESET) %s\n" "$(1)"'
msg_done = @bash -c 'printf "$(GREEN)[DONE]$(RESET) %s\n" "$(1)"'
msg_warn = @bash -c 'printf "$(YELLOW)[WARN]$(RESET) %s\n" "$(1)"'
msg_err  = @bash -c 'printf "$(RED)[ERROR]$(RESET) %s\n" "$(1)"'

.PHONY: all deps mirror iso image prepare run reset inspect bootstrap clean help

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
# Run VM
# --------------------------------------------------------------
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
	qemu-system-x86_64 \
	  -enable-kvm \
	  -name $(VM_NAME) \
	  -m $(RAM_MB) \
	  -smp $(CPUS) \
	  -boot d \
	  -cdrom $(ISO_FILE) \
	  -drive file=$(DISK_FILE),format=qcow2 \
		  -device $(GPU_DEVICE) \
		  -device $(AUDIO_DEVICE) \
		  -device $(AUDIO_CODEC),audiodev=snd0 \
		  -audiodev pa,id=snd0,out.frequency=44100,out.channels=2 \
	  -display gtk,gl=on \
	  -machine type=q35,accel=kvm \
	  -cpu host \
	  -drive if=pflash,format=raw,readonly=on,file=$(UEFI_CODE) \
	  -drive if=pflash,format=raw,file=$(UEFI_VARS) \
	  -net nic,model=virtio -net user,hostfwd=tcp::$(SPICE_PORT)-:22
	$(call msg_done,VM launched successfully.)

reset:
	$(call msg_info,Resetting VM environment...)
	bash $(SCRIPTS_DIR)/vm-reset.sh
	$(call msg_done,VM reset complete.)

inspect:
	$(call msg_info,Inspecting VM resources...)
	bash $(SCRIPTS_DIR)/vm-inspect.sh
	$(call msg_done,Inspection complete.)

bootstrap:
	$(call msg_info,Running Archenemy bootstrap inside guest...)
	bash $(SCRIPTS_DIR)/bootstrap.sh
	$(call msg_done,Bootstrap executed inside VM.)

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
	@echo "  $(BLUE)run$(RESET)        - Launch VM"
	@echo "  $(BLUE)reset$(RESET)      - Reset VM environment"
	@echo "  $(BLUE)inspect$(RESET)    - Inspect VM disk and metadata"
	@echo "  $(BLUE)bootstrap$(RESET)  - Run installer inside VM"
	@echo "  $(BLUE)clean$(RESET)      - Clean environment"
	@echo "  $(BLUE)help$(RESET)       - Show this help message\n"
	@echo "Example: make prepare && make run\n"
