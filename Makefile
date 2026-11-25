TOPDIR = $(shell pwd)
MOCK_CONFIG ?= rocky-10-x86_64
SPEC = SPECS/sudo.spec

all: srpm

srpm:
	rpmbuild -bs --define "_topdir $(TOPDIR)" $(SPEC)

mock: srpm
	mkdir -p $(TOPDIR)/RPMS
	mock -r $(MOCK_CONFIG) --resultdir=$(TOPDIR)/RPMS $(TOPDIR)/SRPMS/*.src.rpm

clean:
	rm -rf BUILD BUILDROOT RPMS/* SRPMS/*

.PHONY: all srpm mock clean
