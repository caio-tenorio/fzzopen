# Makefile to build fzzo

PYTHON := python3
VENV := venv
PYINSTALLER := $(VENV)/bin/pyinstaller
PIP := $(VENV)/bin/pip
SOURCE := fzzo_configurable.py
BINARY_NAME := fzzo
DIST_DIR := dist
BUILD_DIR := build

.PHONY: all build install clean test help venv

all: build

# Create virtual environment
venv: $(VENV)/bin/activate

$(VENV)/bin/activate:
	@echo "🔧 Creating virtual environment..."
	$(PYTHON) -m venv $(VENV)
	@echo "✅ Virtual environment created"

# Compile the binary
build: $(DIST_DIR)/$(BINARY_NAME)

$(DIST_DIR)/$(BINARY_NAME): $(SOURCE) $(VENV)/bin/activate
	@echo "🔧 Building $(SOURCE) to binary..."
	@if [ ! -f "$(PYINSTALLER)" ]; then \
		echo "📦 Installing PyInstaller..."; \
		$(PIP) install pyinstaller; \
	fi
	$(PYINSTALLER) --onefile \
		--name $(BINARY_NAME) \
		--console \
		--strip \
		--optimize 2 \
		$(SOURCE)
	@echo "✅ Build completed: $(DIST_DIR)/$(BINARY_NAME)"

# Install the binary on the system
install: build
	@echo "📦 Installing $(BINARY_NAME)..."
	@if [ -w /usr/local/bin ]; then \
		cp $(DIST_DIR)/$(BINARY_NAME) /usr/local/bin/; \
		echo "✅ Installed at /usr/local/bin/$(BINARY_NAME)"; \
	elif [ -d "$$HOME/.local/bin" ]; then \
		cp $(DIST_DIR)/$(BINARY_NAME) $$HOME/.local/bin/; \
		echo "✅ Installed at $$HOME/.local/bin/$(BINARY_NAME)"; \
	else \
		mkdir -p $$HOME/.local/bin; \
		cp $(DIST_DIR)/$(BINARY_NAME) $$HOME/.local/bin/; \
		echo "✅ Installed at $$HOME/.local/bin/$(BINARY_NAME)"; \
		echo "⚠️  Make sure $$HOME/.local/bin is in your PATH"; \
	fi

# Test the binary
test: build
	@echo "🧪 Testing $(BINARY_NAME)..."
	@echo "Python version used:"
	@$(PYTHON) --version
	@echo "Testing --help:"
	@./$(DIST_DIR)/$(BINARY_NAME) --help || true

# Clean generated files
clean:
	@echo "🧹 Cleaning generated files..."
	rm -rf $(DIST_DIR) $(BUILD_DIR) *.spec
	@echo "✅ Cleanup completed"

# Install dependencies
deps: $(VENV)/bin/activate
	@echo "📦 Installing dependencies..."
	$(PIP) install pyinstaller

# Show help
help:
	@echo "Available commands:"
	@echo "  make build    - Build the binary"
	@echo "  make install  - Install the binary on system"
	@echo "  make test     - Test the binary"
	@echo "  make clean    - Remove generated files"
	@echo "  make deps     - Install dependencies"
	@echo "  make help     - Show this help"
