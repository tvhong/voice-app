ICON ?= icon.svg

.PHONY: icon
icon:
	./scripts/set_app_icon.sh "$(ICON)"
