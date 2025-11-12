# ==============================================================================
#  Archenemy QEMU Harness (minimal, reproducible)
# ==============================================================================
#
#  This Makefile provisions a VM with two virtio disks so we can run Archinstall
#  exactly like on bare metal and then test the post-install script via SSH.
#
#  Targets:
#    make iso         -> Download the latest Arch ISO
#    make disks       -> Create OS + data qcow2 disks
#    make run-live    -> Boot from ISO (install / run phase 1)
#    make run-disk    -> Boot from installed disk (phase 2 / daily use)
#    make ssh         -> Open SSH session to the guest (needs sshd in guest)
#    make test-script -> Run curl | bash installer inside the guest over SSH
#    make clean       -> Remove ISO/disks
#
#  Override any variable below on the command line, e.g.
#    make run-live RAM_MB=6144 PRIMARY_DISK_SIZE=120G
# ==============================================================================

VM_NAME            ?= archenemy-dev
WORKDIR            ?= $(CURDIR)/.vm-harness

ISO_URL            ?= https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
ISO_PATH           := $(WORKDIR)/archlinux.iso

PRIMARY_DISK_SIZE  ?= 80G
PRIMARY_DISK_PATH  := $(WORKDIR)/$(VM_NAME).qcow2
DATA_DISK_SIZE     ?= 80G
DATA_DISK_PATH     := $(WORKDIR)/$(VM_NAME)-data.qcow2

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
	-drive if=virtio,format=qcow2,file=$(PRIMARY_DISK_PATH) \
	-drive if=virtio,format=qcow2,file=$(DATA_DISK_PATH)

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

disks: $(WORKDIR)
	@echo "[INFO] Creating primary disk ($(PRIMARY_DISK_SIZE)) at $(PRIMARY_DISK_PATH)"
	qemu-img create -f qcow2 "$(PRIMARY_DISK_PATH)" $(PRIMARY_DISK_SIZE)
	@echo "[INFO] Creating data disk ($(DATA_DISK_SIZE)) at $(DATA_DISK_PATH)"
	qemu-img create -f qcow2 "$(DATA_DISK_PATH)" $(DATA_DISK_SIZE)
	@echo "[DONE] Disks created."

run-live: iso disks
	@if [ ! -f "$(ISO_PATH)" ]; then echo "Missing ISO. Run 'make iso'."; exit 1; fi
	@echo "[INFO] Booting from ISO..."
	$(QEMU_BIN) $(QEMU_COMMON_FLAGS) \
		$(QEMU_DISK_FLAGS) \
		-cdrom "$(ISO_PATH)" \
		-boot order=d

run-disk: disks
	@if [ ! -f "$(PRIMARY_DISK_PATH)" ]; then echo "Missing disk. Run 'make disks'."; exit 1; fi
	@echo "[INFO] Booting from disk..."
	$(QEMU_BIN) $(QEMU_COMMON_FLAGS) \
		$(QEMU_DISK_FLAGS) \
		-boot order=c

ssh:
	@echo "[INFO] Connecting to guest via SSH (ensure sshd is running in the VM)..."
	ssh -p $(SSH_PORT) $(SSH_USER)@localhost

test-script:
	@echo "[INFO] Running installer inside the guest via SSH..."
	ssh -p $(SSH_PORT) $(SSH_USER)@localhost "sh -c '$(ARCHENEMY_INSTALL_CMD)'"

clean:
	@echo "[WARN] Removing ISO and disks ..."
	rm -f "$(ISO_PATH)" "$(PRIMARY_DISK_PATH)" "$(DATA_DISK_PATH)"
	@echo "[DONE] Cleaned."

help:
	@echo ""
	@echo "Archenemy VM Harness"
	@echo "---------------------"
	@echo "make iso         Download latest Arch ISO ($(ISO_URL))"
	@echo "make disks       Create $(PRIMARY_DISK_PATH) ($(PRIMARY_DISK_SIZE)) and $(DATA_DISK_PATH) ($(DATA_DISK_SIZE))"
	@echo "make run-live    Boot VM from the ISO (install / phase 1)"
	@echo "make run-disk    Boot the installed system from disk (phase 2 / testing)"
	@echo "make ssh         SSH into the guest (requires sshd + password in VM)"
	@echo "make test-script Run the installer remotely via SSH (uses ARCHENEMY_INSTALL_CMD)"
	@echo "make clean       Remove ISO and qcow2 disks"
	@echo ""
	@echo "Inside the live ISO:"
	@echo "  1. Run archinstall but DO NOT reboot."
	@echo "  2. In the same shell, execute:"
	@echo "       $(ARCHENEMY_INSTALL_CMD)"
	@echo "  3. Reboot into the installed disk and accept the phase-2 prompt."
