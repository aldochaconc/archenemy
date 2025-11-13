# ==============================================================================
#  Archenemy QEMU Harness (minimal, reproducible)
# ==============================================================================
#
#  This Makefile provisions a VM with a single virtio disk so we can run
#  Archinstall exactly like on bare metal and then test the post-install script.
#
#  Targets:
#    make iso         -> Download the latest Arch ISO
#    make disks       -> Create the qcow2 disk
#    make run-live    -> Boot from ISO (install / run phase 1)
#    make run-disk    -> Boot from installed disk (phase 2 / daily use)
#    make ssh         -> Open SSH session to the guest (needs sshd in guest)
#    make test-script -> Run curl | bash installer inside the guest over SSH
#    make clean       -> Remove ISO/disks
#
#  Override any variable below on the command line, e.g.
#    make run-live RAM_MB=6144 DISK_SIZE=120G
# ==============================================================================

VM_NAME            ?= archenemy-dev
WORKDIR            ?= $(CURDIR)/.vm-harness

ISO_URL            ?= https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
ISO_PATH           := $(WORKDIR)/archlinux.iso

DISK_SIZE          ?= 80G
DISK_PATH          := $(WORKDIR)/$(VM_NAME).qcow2

UEFI               ?= 1
OVMF_DIR           ?= /usr/share/ovmf/x64
OVMF_CODE_CANDIDATES := \
	$(OVMF_DIR)/OVMF_CODE.fd \
	$(OVMF_DIR)/OVMF_CODE.4m.fd \
	$(OVMF_DIR)/OVMF_CODE.secboot.4m.fd
OVMF_VARS_CANDIDATES := \
	$(OVMF_DIR)/OVMF_VARS.fd \
	$(OVMF_DIR)/OVMF_VARS.4m.fd
OVMF_CODE_DEFAULT := $(firstword $(wildcard $(OVMF_CODE_CANDIDATES)))
OVMF_VARS_DEFAULT := $(firstword $(wildcard $(OVMF_VARS_CANDIDATES)))
OVMF_CODE_PATH     ?= $(OVMF_CODE_DEFAULT)
OVMF_VARS_TEMPLATE ?= $(OVMF_VARS_DEFAULT)
OVMF_VARS_PATH     := $(WORKDIR)/OVMF_VARS.fd

RAM_MB             ?= 4096
CPUS               ?= 4
SSH_PORT           ?= 2222
SSH_USER           ?= root

ARCHENEMY_INSTALL_CMD ?= curl -fsSL https://raw.githubusercontent.com/aldochaconc/archenemy/main/install.sh | bash

QEMU_BIN           ?= qemu-system-x86_64

QEMU_COMMON_FLAGS = \
	-enable-kvm \
	-machine type=q35,accel=kvm \
	-m $(RAM_MB) \
	-smp $(CPUS) \
	-name $(VM_NAME) \
	-display gtk \
	-audiodev pa,id=snd0 \
	-device ich9-intel-hda \
	-device hda-duplex,audiodev=snd0 \
	-netdev user,id=net0,hostfwd=tcp::$(SSH_PORT)-:22 \
	-device virtio-net-pci,netdev=net0 \
	-device virtio-vga

QEMU_DISK_FLAGS = \
	-drive if=virtio,format=qcow2,file=$(DISK_PATH)

FIRMWARE_DEPS :=
QEMU_FIRMWARE_FLAGS :=

ifeq ($(UEFI),1)
FIRMWARE_DEPS += $(OVMF_VARS_PATH)
QEMU_FIRMWARE_FLAGS = \
	-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE_PATH) \
	-drive if=pflash,format=raw,file=$(OVMF_VARS_PATH)
endif

.PHONY: all iso disks run-live run-disk ssh test-script clean help

all: help

$(WORKDIR):
	mkdir -p "$(WORKDIR)"

iso: $(WORKDIR)
	@if [ ! -f "$(ISO_PATH)" ]; then \
		echo "[INFO] ISO not found. Downloading to $(ISO_PATH)"; \
		curl -L --fail --retry 3 -C - -o "$(ISO_PATH).part" "$(ISO_URL)"; \
		mv "$(ISO_PATH).part" "$(ISO_PATH)"; \
		echo "[DONE] ISO ready."; \
	else \
		echo "[INFO] ISO already exists at $(ISO_PATH). Skipping download."; \
	fi

disks: $(DISK_PATH)

$(DISK_PATH): $(WORKDIR)
	@if [ -f "$(DISK_PATH)" ]; then \
		echo "[INFO] Disk already exists at $(DISK_PATH). Skipping creation."; \
	else \
		echo "[INFO] Creating disk ($(DISK_SIZE)) at $(DISK_PATH)"; \
		qemu-img create -f qcow2 "$(DISK_PATH)" $(DISK_SIZE); \
		echo "[DONE] Disk ready."; \
	fi

ifeq ($(UEFI),1)
$(OVMF_VARS_PATH): $(WORKDIR)
	@if [ -z "$(OVMF_CODE_PATH)" ]; then \
		echo "[ERROR] Unable to locate a default OVMF_CODE image under $(OVMF_DIR). Install 'edk2-ovmf' or set OVMF_CODE_PATH=/path/to/OVMF_CODE.fd."; \
		exit 1; \
	fi
	@if [ ! -f "$(OVMF_CODE_PATH)" ]; then \
		echo "[ERROR] OVMF_CODE not found at $(OVMF_CODE_PATH). Install 'edk2-ovmf' or override OVMF_CODE_PATH."; \
		exit 1; \
	fi
	@if [ -z "$(OVMF_VARS_TEMPLATE)" ]; then \
		echo "[ERROR] Unable to locate a default OVMF_VARS template under $(OVMF_DIR). Install 'edk2-ovmf' or set OVMF_VARS_TEMPLATE=/path/to/OVMF_VARS.fd."; \
		exit 1; \
	fi
	@if [ ! -f "$(OVMF_VARS_TEMPLATE)" ]; then \
		echo "[ERROR] Missing OVMF_VARS template at $(OVMF_VARS_TEMPLATE). Install 'edk2-ovmf' or override OVMF_VARS_TEMPLATE."; \
		exit 1; \
	fi
	@if [ ! -f "$(OVMF_VARS_PATH)" ]; then \
		echo "[INFO] Initializing UEFI variable store at $(OVMF_VARS_PATH)"; \
		cp "$(OVMF_VARS_TEMPLATE)" "$(OVMF_VARS_PATH)"; \
	else \
		echo "[INFO] UEFI variable store already exists at $(OVMF_VARS_PATH)."; \
	fi
endif

run-live: iso $(DISK_PATH) $(FIRMWARE_DEPS)
	@if [ ! -f "$(ISO_PATH)" ]; then echo "Missing ISO. Run 'make iso'."; exit 1; fi
	@echo "[INFO] Booting from ISO..."
	$(QEMU_BIN) $(QEMU_COMMON_FLAGS) $(QEMU_FIRMWARE_FLAGS) \
		$(QEMU_DISK_FLAGS) \
		-cdrom "$(ISO_PATH)" \
		-boot order=d

run-disk: $(DISK_PATH) $(FIRMWARE_DEPS)
	@if [ ! -f "$(DISK_PATH)" ]; then echo "Missing disk. Run 'make disks'."; exit 1; fi
	@echo "[INFO] Booting from disk..."
	$(QEMU_BIN) $(QEMU_COMMON_FLAGS) $(QEMU_FIRMWARE_FLAGS) \
		$(QEMU_DISK_FLAGS) \
		-boot order=c

ssh:
	@echo "[INFO] Connecting to guest via SSH (ensure sshd is running in the VM)..."
	ssh -p $(SSH_PORT) $(SSH_USER)@localhost

test-script:
	@echo "[INFO] Running installer inside the guest via SSH..."
	ssh -p $(SSH_PORT) $(SSH_USER)@localhost "sh -c '$(ARCHENEMY_INSTALL_CMD)'"

clean:
	@echo "[WARN] Removing ISO and disk ..."
	rm -f "$(ISO_PATH)" "$(DISK_PATH)" "$(OVMF_VARS_PATH)"
	@echo "[DONE] Cleaned."

help:
	@echo ""
	@echo "Archenemy VM Harness"
	@echo "---------------------"
	@echo "make iso         Download latest Arch ISO ($(ISO_URL))"
	@echo "make disks       Create $(DISK_PATH) ($(DISK_SIZE))"
	@echo "make run-live    Boot VM from the ISO (install / phase 1)"
	@echo "make run-disk    Boot the installed system from disk (phase 2 / testing)"
	@echo "make ssh         SSH into the guest (requires sshd + password in VM)"
	@echo "make test-script Run the installer remotely via SSH (uses ARCHENEMY_INSTALL_CMD)"
	@echo "make clean       Remove ISO and qcow2 disk"
	@echo ""
	@echo "UEFI firmware is enabled by default (OVMF). Override UEFI=0 to boot with legacy SeaBIOS."
	@echo ""
	@echo "Inside the live ISO:"
	@echo "  1. Run archinstall but DO NOT reboot."
	@echo "  2. In the same shell, execute:"
	@echo "       $(ARCHENEMY_INSTALL_CMD)"
	@echo "  3. Reboot into the installed disk and accept the phase-2 prompt."
