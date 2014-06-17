TARGET := iphone:clang::5.0
ARCHS := armv7 arm64

ifdef CCC_ANALYZER_OUTPUT_FORMAT
  TARGET_CXX = $(CXX)
  TARGET_LD = $(TARGET_CXX)
endif

ADDITIONAL_CFLAGS += -g -fobjc-arc -fvisibility=hidden
ADDITIONAL_LDFLAGS += -g -fobjc-arc -Wl,-map,$@.map -x c /dev/null -x none

BUNDLE_NAME = PurchaseStats PurchaseStatsSettings

PurchaseStats_FILES = PurchaseStatsController.m PurchaseStatsView.m PurchaseStatsSettings.m PurchaseStatsFetcher.m PurchaseStatsStore.m MSPullToRefreshController.m
PurchaseStats_INSTALL_PATH = /Library/WeeLoader/Plugins
PurchaseStats_FRAMEWORKS = CoreGraphics UIKit

PurchaseStatsSettings_FILES = PurchaseStatsPreferences.x PurchaseStatsStore.m
PurchaseStatsSettings_BUNDLE_RESOURCE_DIRS := Settings
PurchaseStatsSettings_INSTALL_PATH = /Library/PreferenceBundles
PurchaseStatsSettings_LIBRARIES = substrate
PurchaseStatsSettings_FRAMEWORKS = UIKit
PurchaseStatsSettings_PRIVATE_FRAMEWORKS = Preferences

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk

before-PurchaseStats-all::
	@$(foreach js,$(wildcard *.js), \
		jshint $(js) && \
		jsmin < $(js) > $(js).min && \
		bin/generate_js_header $(js).min && \
	):

after-stage::
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) \( -iname '*.plist' -or -iname '*.strings' \) -execdir plutil -convert binary1 {} \;$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -d \( -iname '*.dSYM' -or -iname '*.map' \) -execdir rm -rf {} \;$(ECHO_END)
	$(ECHO_NOTHING)mv $(THEOS_STAGING_DIR)$(PurchaseStatsSettings_INSTALL_PATH)/PurchaseStatsSettings.bundle/PurchaseStatsSettings $(THEOS_STAGING_DIR)$(PurchaseStatsSettings_INSTALL_PATH)/PurchaseStatsSettings.bundle/PurchaseStats $(ECHO_END)
	$(ECHO_NOTHING)mv $(THEOS_STAGING_DIR)$(PurchaseStatsSettings_INSTALL_PATH)/PurchaseStatsSettings.bundle $(THEOS_STAGING_DIR)$(PurchaseStatsSettings_INSTALL_PATH)/PurchaseStats.bundle $(ECHO_END)
	$(ECHO_NOTHING)cp LICENSE $(THEOS_STAGING_DIR)$(PurchaseStats_INSTALL_PATH)/PurchaseStats.bundle$(ECHO_END)
	$(ECHO_NOTHING)ln -s $(PurchaseStats_INSTALL_PATH)/PurchaseStats.bundle/PurchaseStats.png $(THEOS_STAGING_DIR)/$(PurchaseStatsSettings_INSTALL_PATH)/PurchaseStats.bundle/$(ECHO_END)
	$(ECHO_NOTHING)ln -s $(PurchaseStats_INSTALL_PATH)/PurchaseStats.bundle/PurchaseStats@2x.png $(THEOS_STAGING_DIR)/$(PurchaseStatsSettings_INSTALL_PATH)/PurchaseStats.bundle/$(ECHO_END)

after-install::
	install.exec "(killall backboardd || killall SpringBoard) 2>/dev/null"

after-clean::
	rm -f *.js.min*
