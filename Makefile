.PHONY: help build release app install run clean test info open edit-config all sparkle-archive

help: ## Show this help message
	@echo "CCProxy - macOS menu bar app"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Swift executable (debug)
	@echo "🔨 Building Swift executable..."
	@cd src && swift build
	@echo "✅ Build complete: src/.build/debug/CCProxy"

release: ## Build the app bundle for release
	@echo "🔨 Building release app bundle..."
	@./create-app-bundle.sh
	@echo "✅ Build complete: CCProxy.app"

sparkle-archive: release ## Create zip archive for Sparkle
	@echo "🗜️  Creating Sparkle archive..."
	@rm -f "CCProxy.app.zip"
	@ditto -c -k --keepParent "CCProxy.app" "CCProxy.app.zip"
	@echo "✅ Created CCProxy.app.zip"

app: release ## Create the .app bundle

install: app ## Build and install to /Applications
	@echo "📲 Installing to /Applications..."
	@rm -rf "/Applications/CCProxy.app"
	@cp -r "CCProxy.app" /Applications/
	@echo "✅ Installed to /Applications/CCProxy.app"

run: app ## Build and run the app
	@echo "🚀 Launching app..."
	@open "CCProxy.app"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning..."
	@rm -rf src/.build
	@rm -rf "CCProxy.app"
	@rm -rf src/Sources/Resources/cli-proxy-api
	@rm -rf src/Sources/Resources/config.yaml
	@rm -rf src/Sources/Resources/static
	@echo "✅ Clean complete"

test: ## Run Swift tests
	@echo "🧪 Running tests..."
	@cd src && swift test
	@echo "✅ Tests passed"

info: ## Show project information
	@echo "Project: CCProxy"
	@echo "Type: macOS menu bar app"
	@echo "Language: Swift 5.9+"
	@echo "Platform: macOS 13.0+"
	@echo ""
	@echo "Files:"
	@find src/Sources -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print "  Swift code: " $$1 " lines"}'
	@echo ""
	@echo "Outputs:"
	@echo "  App bundle: CCProxy.app"
	@echo "  Executable: src/.build/release/CCProxy"

open: ## Open app bundle to inspect contents
	@if [ -d "CCProxy.app" ]; then \
		open "CCProxy.app"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
	fi

edit-config: ## Edit the bundled config.yaml
	@if [ -d "CCProxy.app" ]; then \
		open -e "CCProxy.app/Contents/Resources/config.yaml"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
	fi

# Shortcuts
all: app ## Same as 'app'
