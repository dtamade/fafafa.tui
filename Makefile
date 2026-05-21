FPC ?= fpc
TUI_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(TUI_ROOT)/src
TESTS_DIR := $(TUI_ROOT)/tests
EXAMPLES_DIR := $(TUI_ROOT)/examples
BENCHMARKS_DIR := $(TUI_ROOT)/benchmarks
BUILD_DIR := $(TUI_ROOT)/build
BIN_DIR := $(BUILD_DIR)/bin

UNIT_DIRS := \
	$(SRC_DIR)/core \
	$(SRC_DIR)/text \
	$(SRC_DIR)/layout \
	$(SRC_DIR)/widgets \
	$(SRC_DIR)/backend \
	$(SRC_DIR)/terminal \
	$(SRC_DIR)/input \
	$(TESTS_DIR)

FPC_BASE_FLAGS := -MObjFPC -Sh -O3 -gl -CR -Xs
FPC_BENCH_FLAGS := -MObjFPC -Sh -O3 -Xs
FPC_UNIT_FLAGS := $(foreach d,$(UNIT_DIRS),-Fu$(d))
FPC_LINK_FLAGS := -FE$(BIN_DIR)
FPC_FLAGS := $(FPC_BASE_FLAGS) $(FPC_UNIT_FLAGS) $(FPC_LINK_FLAGS)

.PHONY: all test examples benchmarks bench acceptance ci clean help

all: test

help:
	@echo "fafafa.tui make targets:"
	@echo "  test         build & run tests/test_runner.lpr"
	@echo "  examples     build everything in examples/"
	@echo "  benchmarks   build everything in benchmarks/"
	@echo "  bench        build + run all benchmarks with summary table"
	@echo "  acceptance   PTY-level demo verification (requires tmux)"
	@echo "  ci           full gate: test + examples + benchmarks + acceptance"
	@echo "  clean        wipe build/ and stray .ppu/.o"

test:
	@mkdir -p $(BIN_DIR)
	@if [ -f $(TESTS_DIR)/test_runner.lpr ]; then \
		$(FPC) $(FPC_FLAGS) $(TESTS_DIR)/test_runner.lpr && \
		$(BIN_DIR)/test_runner; \
	else \
		echo "(no tests/test_runner.lpr yet — skipping)"; \
	fi

examples:
	@mkdir -p $(BIN_DIR)
	@for f in $(EXAMPLES_DIR)/*.lpr; do \
		[ -e "$$f" ] || continue; \
		echo ">> $$f"; \
		$(FPC) $(FPC_FLAGS) $$f || exit $$?; \
	done

benchmarks:
	@mkdir -p $(BIN_DIR)
	@for f in $(BENCHMARKS_DIR)/*.lpr; do \
		[ -e "$$f" ] || continue; \
		echo ">> $$f"; \
		$(FPC) $(FPC_BENCH_FLAGS) $(FPC_UNIT_FLAGS) $(FPC_LINK_FLAGS) $$f || exit $$?; \
	done

clean:
	rm -rf $(BUILD_DIR)
	find $(SRC_DIR) -name '*.o' -delete 2>/dev/null || true
	find $(SRC_DIR) -name '*.ppu' -delete 2>/dev/null || true
	find $(TESTS_DIR) -name '*.o' -delete 2>/dev/null || true
	find $(TESTS_DIR) -name '*.ppu' -delete 2>/dev/null || true
	find $(EXAMPLES_DIR) -name '*.o' -delete 2>/dev/null || true
	find $(EXAMPLES_DIR) -name '*.ppu' -delete 2>/dev/null || true
	find $(BENCHMARKS_DIR) -name '*.o' -delete 2>/dev/null || true
	find $(BENCHMARKS_DIR) -name '*.ppu' -delete 2>/dev/null || true
	find $(TUI_ROOT) -name 'link*.res' -delete 2>/dev/null || true
	find $(TUI_ROOT) -name 'ppas.sh' -delete 2>/dev/null || true

acceptance: examples
	@echo "Running PTY acceptance tests (requires tmux)..."
	@bash scripts/acceptance_test.sh

ci: test examples benchmarks acceptance
	@echo ""
	@echo "=== CI gate passed ==="

bench: benchmarks
	@bash scripts/bench_all.sh

quickstart:
	@if [ -z "$(NAME)" ]; then echo "Usage: make quickstart NAME=myapp"; exit 1; fi
	@mkdir -p $(NAME)
	@cp templates/quickstart.lpr $(NAME)/$(NAME).lpr
	@sed -i "s/quickstart/$(NAME)/g" $(NAME)/$(NAME).lpr
	@cp templates/quickstart_makefile $(NAME)/Makefile
	@sed -i "s|__FTUI_ROOT__|$(TUI_ROOT)|g" $(NAME)/Makefile
	@sed -i "s|__APP_NAME__|$(NAME)|g" $(NAME)/Makefile
	@echo "Created $(NAME)/"
	@echo "  $(NAME).lpr  — your app"
	@echo "  Makefile     — build system (make run)"
	@echo ""
	@echo "Next: cd $(NAME) && make run"
