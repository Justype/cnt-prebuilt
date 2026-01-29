# Makefile to build container artifacts under build/
# - Uses `apptainer build` to make build/.../base_image.sif from base_image.def
# - Uses `condatainer create -p` to create build/.../<name> directories for other .def files
#
# Usage examples:
#   make            # build all targets (all base_image.sif and condatainer stamps)
#   make -j8        # parallel build
#   make clean      # remove build/
#
CONDATINER ?= condatainer
COND_CREATE ?= create -p
APPTAINER ?= apptainer
APPT_BUILD ?= build
COND_FLAGS ?=
APPT_FLAGS ?=

# Find all .def files (relative paths), excluding anything under build/
DEF_SRCS := $(shell find . -type f -name '*.def' -not -path './build/*' -printf '%P\n')

# Base image SIF: only the root base_image.def will generate build/base_image.sif
ROOT_BASE := $(filter base_image.def,$(DEF_SRCS))
SIF_TARGETS := $(patsubst %.def,build/%.sif,$(ROOT_BASE))

# Produce .sqf files for all other defs. For subfolders, replace '/' with '--' in the build name
# Top-level defs only (no slash in path)
TOP_DEFS := $(filter $(notdir $(DEF_SRCS)),$(DEF_SRCS))
# Only top-level non-base defs become root-level build prefixes (no extension)
ROOT_SQF_TARGETS := $(patsubst %.def,build/%,$(filter-out base_image.def,$(TOP_DEFS)))
# Subdirectory defs (robustly find entries that have a directory component)
SUBDIR_DEFS := $(filter-out $(notdir $(DEF_SRCS)),$(DEF_SRCS))
# All build prefixes: root-level first, then transformed subdir defs (replace '/' with '--')
SQF_TARGETS := $(ROOT_SQF_TARGETS) \
               $(foreach f,$(SUBDIR_DEFS),build/$(subst /,--,$(patsubst %.def,%,$(f))))

# Aggregate non-sif targets
OTHER_TARGETS := $(SQF_TARGETS)

# Root target: builds only top-level defs (root base image + top-level .sqf targets)
.PHONY: root
root: $(SIF_TARGETS) $(ROOT_SQF_TARGETS)
	@echo "Built root-level targets: $(SIF_TARGETS) $(ROOT_SQF_TARGETS)"


.PHONY: all help list clean
all: $(SIF_TARGETS) $(SQF_TARGETS)
	@echo "Built all targets: $(SIF_TARGETS) $(SQF_TARGETS)"

help: ## Show help
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  all (default) - build all SIFs for base_image and run condatainer for other defs"
	@echo "  clean - remove build/ directory"
	@echo "Variables you can override: APPTAINER, CONDATINER, APPT_FLAGS, COND_FLAGS"

# Rule to build SIFs from base_image.def files
# Example: build/base_image.sif <- base_image.def
build/%.sif: %.def
	@echo "[apptainer] Building $@ from $<"
	@mkdir -p $(dir $@)
	$(APPTAINER) $(APPT_BUILD) $@ $(APPT_FLAGS) $<

# Generic rule to create build prefixes via condatainer (touch marker .sqf after create)
# Handles top-level defs (e.g., build/code-server) and transformed subdir targets
# (e.g., build/ubuntu20--code-server). The def file path is computed by converting
# a leading 'build/' and '--' back to '/' to find the original .def.
build/%:
	@def_path="$$(echo "$@" | sed 's|^build/||; s|--|/|g').def"; \
	if [ ! -e "$$def_path" ]; then echo "ERROR: def file not found: $$def_path"; exit 1; fi; \
	echo "[condatainer] Creating $@ from $$def_path"; \
	mkdir -p $(dir $@); \
	$(CONDATINER) $(COND_CREATE) $@ -f "$$def_path" $(COND_FLAGS); \
	touch $@.sqf

# Explicit rule for the root base image SIF
build/base_image.sif: base_image.def
	@echo "[apptainer] Building $@ from $<"
	@mkdir -p $(dir $@)
	$(APPTAINER) $(APPT_BUILD) $@ $(APPT_FLAGS) $<

# Convenience targets
list: ## List the discovered .def files and planned targets
	@echo "Will produce (all) - SIFs + all SQFs:"
	@printf '%s\n' $(SIF_TARGETS) $(SQF_TARGETS)
	@echo
	@echo "Will produce (root) - SIFs + root-level SQFs:"
	@printf '%s\n' $(SIF_TARGETS) $(ROOT_SQF_TARGETS)

clean: ## Remove build artifacts
	rm -rf build/
	@echo "cleaned build/"

# Avoid errors if no SIF targets are present
.SECONDARY:

# end of Makefile
