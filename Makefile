# Default values
CLOUD_INIT_DIR ?= cloud-init
CLOUD_INIT_ISO ?= cloud-init.iso
GRUB_CFG_FILE ?= grub/grub.cfg
UBUNTU_ISO_URL ?= https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso
UBUNTU_VOLUME_NAME ?= Ubuntu-Server 24.04.1 LTS amd64
UBUNTU_BUILD_DIR ?= build
UBUNTU_TARGET_ISO ?= ubuntu-24.04-unattended-server-amd64.iso

UBUNTU_ISO_NAME := $(shell basename $(UBUNTU_ISO_URL))
UBUNTU_SRC_ISO_PATH := $(UBUNTU_BUILD_DIR)/$(UBUNTU_ISO_NAME)
UBUNTU_MBR_IMAGES := $(UBUNTU_BUILD_DIR)/BOOT
UBUNTU_EXTRACT_DIR := $(UBUNTU_BUILD_DIR)/iso
UBUNTU_OUT_DIR := $(UBUNTU_BUILD_DIR)/out

# Function to display help
.PHONY: help
help:
	@echo "Usage: make [TARGET] [VARIABLES]"
	@echo ""
	@echo "Targets:"
	@echo "  help                         Display this help message"
	@echo "  download                     Download the input ISO"
	@echo "  inspect                      Inspect the mkisofs options"
	@echo "  extract                      Extract the input ISO"
	@echo "  patch                        Patch the build directory with custom files"
	@echo "  ubuntu                       Build the new ISO"
	@echo "  cloud-init                   Build a cloud-init ISO"
	@echo "  clean                        Clean up temporary files"
	@echo "  all                          Run the complete process (download, extract, patch, build, clean)"
	@echo ""
	@echo "Variables:"
	@echo "  CLOUD_INIT_DIR               Path to the cloud-init directory (default: cloud-init)"
	@echo "  CLOUD_INIT_ISO               Path to the cloud-init ISO file (default: cloud-init.iso)"
	@echo "  GRUB_CFG_FILE                Path to the GRUB configuration file (default: grub/grub.cfg)"
	@echo "  UBUNTU_ISO_URL               URL to download the Ubuntu ISO (default: https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso)"
	@echo "  UBUNTU_VOLUME_NAME           Volume name for the new ISO (default: 'Ubuntu-Server 24.04 LTS amd64')"
	@echo "  UBUNTU_BUILD_DIR             Directory for build artifacts (default: build)"
	@echo "  UBUNTU_TARGET_ISO            Path to the output ISO file (default: ubuntu-24.04-unattended-server-amd64.iso)"

# Download the input ISO
.PHONY: download
download: $(UBUNTU_SRC_ISO_PATH)

$(UBUNTU_SRC_ISO_PATH):
	@echo "Downloading the input ISO..."
	mkdir -p $(UBUNTU_BUILD_DIR)
	curl --progress-bar -L -o $(UBUNTU_SRC_ISO_PATH) $(UBUNTU_ISO_URL)

# Inspect the mkisofs options on the ISO
.PHONY: inspect
inspect: download
	@echo "Inspecting mkisofs options... Adjust the ubuntu target as needed"
	xorriso -indev $(UBUNTU_SRC_ISO_PATH) -report_el_torito as_mkisofs

# Extract the input ISO
.PHONY: extract
extract: clean download
	@echo "Extracting the input ISO..."
	mkdir -p $(UBUNTU_EXTRACT_DIR)
	7z x $(UBUNTU_SRC_ISO_PATH) -o"$(UBUNTU_EXTRACT_DIR)"
	mv $(UBUNTU_EXTRACT_DIR)/\[BOOT\] $(UBUNTU_MBR_IMAGES)

# Patch the build directory with custom files
.PHONY: patch
patch: extract
	@echo "Patching the build directory for"
	cp -r $(CLOUD_INIT_DIR) $(UBUNTU_EXTRACT_DIR)/nocloud
	cp $(GRUB_CFG_FILE) $(UBUNTU_EXTRACT_DIR)/boot/grub/grub.cfg
	chmod 0444 $(UBUNTU_EXTRACT_DIR)/boot/grub/grub.cfg

# Build the new ISO
.PHONY: ubuntu
ubuntu: patch
	@echo "Building the new ISO..."
	mkdir -p $(UBUNTU_OUT_DIR)
	xorriso -as mkisofs -r \
	  -V '$(UBUNTU_VOLUME_NAME)' \
	  --modification-date="$(shell date -u +"%Y%m%d%H%M%S00")" \
	  --grub2-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:'$(UBUNTU_SRC_ISO_PATH)' \
	  --protective-msdos-label \
	  -partition_cyl_align off \
	  -partition_offset 16 \
	  --mbr-force-bootable \
	  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b --interval:local_fs:5406916d-5417059d::'$(UBUNTU_SRC_ISO_PATH)' \
	  -appended_part_as_gpt \
	  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
	  -c '/boot.catalog' \
	  -b '/boot/grub/i386-pc/eltorito.img' \
	  -no-emul-boot \
	  -boot-load-size 4 \
	  -boot-info-table \
	  --grub2-boot-info \
	  -eltorito-alt-boot \
	-e '--interval:appended_partition_2_start_1351729s_size_10144d:all::' \
	  -no-emul-boot \
	  -boot-load-size 10144 \
	  -o "$(UBUNTU_OUT_DIR)/$(UBUNTU_TARGET_ISO)" \
	  "$(UBUNTU_EXTRACT_DIR)"

# Build the cloud-init ISO
.PHONY: cloud-init
cloud-init:
	@echo "Building the cloud-init ISO..."
	cloud-localds $(CLOUD_INIT_ISO) $(CLOUD_INIT_DIR)/user-data $(CLOUD_INIT_DIR)/meta-data

# Clean up temporary files
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -rf $(UBUNTU_EXTRACT_DIR)
	rm -rf $(UBUNTU_MBR_IMAGES)
	rm -rf $(UBUNTU_BUILD_DIR)/out

.PHONY: all
all: ubuntu

.DEFAULT_GOAL := help
