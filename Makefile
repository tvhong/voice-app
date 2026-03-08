ICON ?= icon.png

.PHONY: icon
icon:
	./scripts/set_app_icon.sh "$(ICON)"
