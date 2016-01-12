current_dir = $(shell pwd)

SOURCE = ../ck
BUILD = ../obj
BUILD_NODEBUG=../obj_nodebug
BUILD_SELINUX=../obj_selinux
BUILD_CM13=../obj_cm13

PACKAGE = $(current_dir)

export USE_CCACHE=1
export CCACHE_DIR=../ck_ccache

#ARM_CC = /home/chrono/tools/opt/armv7a-linux-gnueabihf-gcc-5.2.0_i686/bin/armv7a-linux-gnueabihf-
#ARM_CC = /media/chrono/Other/cross/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux/bin/arm-linux-gnueabihf-
ARM_CC = ../armv7a-linux-gnueabihf-gcc-5.2.0_with_isl_x86/bin/armv7a-linux-gnueabihf-
#ARM_CC = ../LinaroMod-arm-eabi-5.1/bin/arm-eabi-
#ARM_CC = ../arm-cortex_a9-linux-gnueabihf-linaro_4.9.4-2015.06/bin/arm-eabi-
#ARM_CC = ../arm-eabi-5.1/bin/arm-eabi-

VERSION=$(shell git -C $(SOURCE) describe --tags --exact-match --match 'r[0-9]*')
ifeq ("$(VERSION)", "")
   VERSION=$(shell git -C $(SOURCE) tag | grep "r4" | tail -n 1 )
   OUT=$(shell git -C $(SOURCE) tag $(VERSION) -f )
endif
KERNEL_NAME=chrono_kernel_$(VERSION).zip
KERNEL_NAME_NODEBUG=chrono_kernel_$(VERSION)-nodebug.zip
KERNEL_NAME_SELINUX=chrono_kernel_$(VERSION)-selinux.zip
KERNEL_NAME_CM13=chrono_kernel_$(VERSION)-cm13.zip
KERNEL_NAME_PRIVATE=chrono_kernel_$(VERSION)-private.zip

AUTOLOAD_LIST = cpufreq_zenx cpufreq_ondemandplus logger pn544
SYSTEM_MODULE_LIST = param j4fs exfat f2fs startup_reason display-ws2401_dpi display-s6d27a1_dpi

all: codina upload codina-nodebug upload-nodebug

codina: build package-full
codina-light: build package-light
codina-nodebug: build-nodebug package-full-nodebug
codina-nodebug-light: build-nodebug package-light-nodebug
codina-selinux: build-selinux package-full-selinux
codina-selinux-light: build-selinux package-light-selinux
codina-cm13: build-cm13 package-full-cm13 
codina-cm13: build-cm13 package-light-cm13
codina-private: update-private-config build-private package-private

update-private-config: $(SOURCE)/arch/arm/configs/codina_nodebug_defconfig
	cp $(SOURCE)/arch/arm/configs/codina_nodebug_defconfig $(SOURCE)/arch/arm/configs/private_defconfig
	sed -ie "s,CONFIG_LIVEOPP_CUSTOM_BOOTUP_FREQ_MIN=[0-9]*,# bootup min freq\nCONFIG_LIVEOPP_CUSTOM_BOOTUP_FREQ_MIN=1200000," $(SOURCE)/arch/arm/configs/private_defconfig
	sed -ie "s,CONFIG_LIVEOPP_CUSTOM_BOOTUP_FREQ_MAX=[0-9]*,# bootup max freq\nCONFIG_LIVEOPP_CUSTOM_BOOTUP_FREQ_MAX=1200000," $(SOURCE)/arch/arm/configs/private_defconfig

build-private: $(SOURCE)
	mkdir -p $(BUILD_NODEBUG);
	make -C $(SOURCE) O=$(BUILD_NODEBUG) ARCH=arm private_defconfig
	-make -C $(SOURCE) O=$(BUILD_NODEBUG) ARCH=arm CROSS_COMPILE=$(ARM_CC)  -j1 -k

build: $(SOURCE)
	mkdir -p $(BUILD);
	make -C $(SOURCE) O=$(BUILD) ARCH=arm codina_defconfig
	-make -C $(SOURCE) O=$(BUILD) ARCH=arm CROSS_COMPILE=$(ARM_CC)  -j1 -k

build-nodebug: $(SOURCE)
	mkdir -p $(BUILD_NODEBUG);
	make -C $(SOURCE) O=$(BUILD_NODEBUG) ARCH=arm codina_nodebug_defconfig
	-make -C $(SOURCE) O=$(BUILD_NODEBUG) ARCH=arm CROSS_COMPILE=$(ARM_CC)  -j1 -k

build-selinux: $(SOURCE)
	mkdir -p $(BUILD_SELINUX);
	make -C $(SOURCE) O=$(BUILD_SELINUX) ARCH=arm codina_selinux_defconfig
	-make -C $(SOURCE) O=$(BUILD_SELINUX) ARCH=arm CROSS_COMPILE=$(ARM_CC)  -j1 -k

build-cm13: $(SOURCE)
	mkdir -p $(BUILD_CM13);
	make -C $(SOURCE) O=$(BUILD_CM13) ARCH=arm codina_cm13_defconfig
	-make -C $(SOURCE) O=$(BUILD_CM13) ARCH=arm CROSS_COMPILE=$(ARM_CC)  -j1 -k

clean:
	rm -fr system/lib/modules/*
	mkdir -p system/lib/modules/autoload
	touch system/lib/modules/autoload/.placeholder
	rm -fr ramdisk/modules/*
	mkdir -p ramdisk/modules/autoload
	touch ramdisk/modules/autoload/.placeholder
	rm -f boot.img
	

modules-install:
	-make -C $(SOURCE) O=$(BUILD) modules_install INSTALL_MOD_PATH=$(PACKAGE)/system/

modules-install-nodebug:
	-make -C $(SOURCE) O=$(BUILD_NODEBUG) modules_install INSTALL_MOD_PATH=$(PACKAGE)/system/

modules-install-selinux:
	-make -C $(SOURCE) O=$(BUILD_SELINUX) modules_install INSTALL_MOD_PATH=$(PACKAGE)/system/

modules-install-cm13:
	-make -C $(SOURCE) O=$(BUILD_CM13) modules_install INSTALL_MOD_PATH=$(PACKAGE)/system/

package-modules:
	$(foreach module,$(SYSTEM_MODULE_LIST), \
                        cp $(PACKAGE)/system/lib/modules/$(module).ko \
                         $(PACKAGE)/ramdisk/modules/$(module).ko;)

	$(foreach module,$(AUTOLOAD_LIST), \
                        cp $(PACKAGE)/system/lib/modules/$(module).ko \
                         $(PACKAGE)/ramdisk/modules/autoload/$(module).ko;)

	7za a -t7z modules.7z -m0=lzma2 -mx=9 -aoa -mfb=64 -md=32m -ms=on -m1=LZMA2:d=128m -mhe ramdisk system

package-ramdisk:
	7za a -t7z ramdisk.7z -m0=lzma2 -mx=9 -aoa -mfb=64 -md=32m -ms=on -m1=LZMA2:d=128m -mhe osfiles recovery

package-full: clean modules-install package-modules package-ramdisk
	cp -f $(BUILD)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME);
	zip -9r $(KERNEL_NAME) META-INF genfstab boot.img ramdisk.7z modules.7z 7za scripts init.d

package-full-selinux: clean modules-install-selinux package-modules package-ramdisk
	cp -f $(BUILD_SELINUX)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME_SELINUX);
	zip -9r $(KERNEL_NAME_SELINUX) META-INF genfstab boot.img ramdisk.7z 7za modules.7z scripts init.d

package-full-cm13: clean modules-install-cm13 package-modules package-ramdisk
	cp -f $(BUILD_CM13)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME_CM13);
	zip -9r $(KERNEL_NAME_CM13) META-INF genfstab boot.img ramdisk.7z 7za modules.7z scripts init.d

package-full-nodebug: clean modules-install-nodebug package-modules package-ramdisk
	cp -f $(BUILD_NODEBUG)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME);
	zip -9r $(KERNEL_NAME_NODEBUG) META-INF genfstab boot.img ramdisk.7z 7za modules.7z scripts init.d

package-light: clean modules-install package-modules
	cp -f $(BUILD)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME);
	zip -9r $(KERNEL_NAME) META-INF modules.7z boot.img scripts/main.sh \
		scripts/remove_modules.sh scripts/check_ramdisk_partition.sh scripts/initd_install.sh init.d

package-light-nodebug: clean modules-install-nodebug package-modules
	cp -f $(BUILD_NODEBUG)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME_NODEBUG);
	zip -9r $(KERNEL_NAME_NODEBUG) META-INF modules.7z boot.img scripts/main.sh \
		scripts/remove_modules.sh scripts/check_ramdisk_partition.sh scripts/initd_install.sh init.d

package-light-selinux: clean modules-install-nodebug package-modules
	cp -f $(BUILD_SELINUX)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME_SELINUX);
	zip -9r $(KERNEL_NAME_SELINUX) META-INF modules.7z boot.img scripts/main.sh \
		scripts/check_ramdisk_partition.sh scripts/initd_install.sh init.d

package-light-cm13: clean modules-install-nodebug package-modules
	cp -f $(BUILD_CM13)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME_CM13);
	zip -9r $(KERNEL_NAME_CM13) META-INF modules.7z boot.img scripts/main.sh \
		scripts/remove_modules.sh scripts/check_ramdisk_partition.sh scripts/initd_install.sh init.d

package-private: clean modules-install-nodebug package-modules
	cp -f $(BUILD_NODEBUG)/arch/arm/boot/zImage $(PACKAGE)/boot.img
	rm -f $(KERNEL_NAME_PRIVATE);
	zip -9r $(KERNEL_NAME_PRIVATE) META-INF modules.7z boot.img scripts/update_modules.sh scripts/main.sh \
		scripts/remove_modules.sh scripts/check_ramdisk_partition.sh scripts/initd_install.sh init.d

modules:
	-make -C $(SOURCE) O=$(BUILD) CROSS_COMPILE=$(ARM_CC) modules
	-make -C $(SOURCE) O=$(BUILD) modules_install INSTALL_MOD_PATH=$(PACKAGE)/system/

modules_nodebug:
	-make -C $(SOURCE) O=$(BUILD_NODEBUG) CROSS_COMPILE=$(ARM_CC) modules
	-make -C $(SOURCE) O=$(BUILD_NODEBUG) modules_install INSTALL_MOD_PATH=$(PACKAGE)/system/


install: $(KERNEL_NAME)
	adb push $(KERNEL_NAME) /storage/sdcard0/

install-private: $(KERNEL_NAME_PRIVATE)
	adb push $(KERNEL_NAME_PRIVATE) /storage/sdcard0/

upload: $(KERNEL_NAME)
	u $(KERNEL_NAME)

upload-nodebug: $(KERNEL_NAME_NODEBUG)
	u $(KERNEL_NAME_NODEBUG)

upload-selinux: $(KERNEL_NAME_SELINUX)
	u $(KERNEL_NAME_SELINUX)

upload-cm13: $(KERNEL_NAME_CM13)
	u $(KERNEL_NAME_CM13)

upload-private: $(KERNEL_NAME_PRIVATE)
	u $(KERNEL_NAME_PRIVATE)
