TARGET := iphone:clang::5.0
ARCHS := armv7 arm64

ifdef CCC_ANALYZER_OUTPUT_FORMAT
  TARGET_CXX = $(CXX)
  TARGET_LD = $(TARGET_CXX)
endif

ADDITIONAL_CFLAGS += -g -fobjc-arc -fvisibility=hidden
ADDITIONAL_LDFLAGS += -g -fobjc-arc -x c /dev/null -x none

TWEAK_NAME = PurchaseStatsSettings
PurchaseStatsSettings_FILES = PurchaseStatsSettingsTweak.x PurchaseStatsStore.m
PurchaseStatsSettings_FRAMEWORKS = UIKit
PurchaseStatsSettings_PRIVATE_FRAMEWORKS = Preferences

BUNDLE_NAME = PurchaseStats
PurchaseStats_FILES = PurchaseStatsController.m PurchaseStatsView.m PurchaseStatsSettings.m PurchaseStatsFetcher.m PurchaseStatsStore.m MSPullToRefreshController.m
PurchaseStats_INSTALL_PATH = /Library/WeeLoader/Plugins
PurchaseStats_FRAMEWORKS = CoreGraphics UIKit

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

before-PurchaseStats-all::
	@$(foreach js,$(wildcard *.js), \
		jshint $(js) && \
		jsmin < $(js) > $(js).min && \
		bin/generate_js_header $(js).min && \
	):

after-stage::
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) \( -iname '*.plist' -or -iname '*.strings' \) -execdir plutil -convert binary1 {} \;$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -d -name '*.dSYM' -execdir rm -rf {} \;$(ECHO_END)
	$(ECHO_NOTHING)cp LICENSE $(THEOS_STAGING_DIR)/Library/WeeLoader/Plugins/$(BUNDLE_NAME).bundle$(ECHO_END)

after-clean::
	rm -f *.js.min*
