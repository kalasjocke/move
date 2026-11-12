PREFIX ?= $(HOME)/.local
APP_DIR ?= $(HOME)/Applications
APP := $(APP_DIR)/Move.app
EXE := $(APP)/Contents/MacOS/Move
LINK := $(PREFIX)/bin/move
STAGE := .build/Move.app
LABEL := local.move
PLIST := $(HOME)/Library/LaunchAgents/$(LABEL).plist
DOMAIN := gui/$(shell id -u)

# A code signing identity in your keychain. A stable identity keeps the
# Accessibility permission across rebuilds. See README.md.
SIGN_ID ?= move

.PHONY: build app test cert install uninstall restart log

build:
	swift build -c release

app: build
	rm -rf $(STAGE)
	mkdir -p $(STAGE)/Contents/MacOS
	cp Info.plist $(STAGE)/Contents/Info.plist
	cp .build/release/move $(STAGE)/Contents/MacOS/Move
	codesign --force --sign "$(SIGN_ID)" $(STAGE)

test:
	swift test

# Create the signing certificate unless the keychain already has it.
cert:
	@if security find-identity -p codesigning | grep -q '"$(SIGN_ID)"'; then \
	  echo "The code signing certificate $(SIGN_ID) exists"; \
	else \
	  scripts/create-cert.sh "$(SIGN_ID)"; \
	fi

# Copy the app next to the old one and swap them, so the running agent keeps
# its files until launchd restarts it.
install: app
	mkdir -p $(APP_DIR) $(PREFIX)/bin $(HOME)/Library/LaunchAgents $(HOME)/Library/Logs
	rm -rf $(APP).new
	ditto $(STAGE) $(APP).new
	rm -rf $(APP)
	mv $(APP).new $(APP)
	ln -sfn $(EXE) $(LINK)
	sed -e "s|__EXE__|$(EXE)|g" -e "s|__HOME__|$(HOME)|g" $(LABEL).plist > $(PLIST)
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	@for i in 1 2 3 4 5; do \
	  launchctl bootstrap $(DOMAIN) $(PLIST) 2>/dev/null && exit 0; sleep 1; \
	done; echo "launchctl bootstrap failed"; exit 1
	@echo "installed $(APP) and started $(LABEL)"

uninstall:
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	rm -rf $(PLIST) $(APP) $(LINK)

restart:
	launchctl kickstart -k $(DOMAIN)/$(LABEL)

log:
	tail -f $(HOME)/Library/Logs/move.log
