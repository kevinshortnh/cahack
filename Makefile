#!/usr/bin/env make -f

# See https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html

# Root directories
BASE			= /home/kevin/github.com/kshortwindham/ca
BASE_CERTS		= $(BASE)/certs
BASE_CRL		= $(BASE)/crl
BASE_NEWCERTS		= $(BASE)/newcerts
BASE_PRIVATE		= $(BASE)/private

# Intermediate directories
INTD			= $(BASE)/intermediate
INTD_CERTS		= $(INTD)/certs
INTD_CRL		= $(INTD)/crl
INTD_CSR		= $(INTD)/csr
INTD_NEWCERTS		= $(INTD)/newcerts
INTD_PRIVATE		= $(INTD)/private

# Root files
ROOT_PRIVATE_KEY 	= $(BASE_PRIVATE)/ca.key.pem
ROOT_CERT		= $(BASE_CERTS)/ca.cert.pem
ROOT_SERIAL		= $(BASE)/serial
ROOT_INDEX		= $(BASE)/index.txt

ROOT_CRUFT		+= $(BASE)/index.*
ROOT_CRUFT		+= $(BASE)/serial.*

CRL			= $(BASE_CRL)/ca.crl.pem

ROOT_FILES		+= $(ROOT_PRIVATE_KEY)
ROOT_FILES		+= $(ROOT_CERT)
ROOT_FILES		+= $(ROOT_SERIAL)
ROOT_FILES		+= $(ROOT_INDEX)
ROOT_FILES		+= $(ROOT_CRUFT)

# Precious files	DO NOT DELETE !!
CNF_ROOT		= $(BASE)/config/openssl.cnf-root
CNF_INT			= $(BASE)/config/openssl.cnf-intermediate

# Intermediate files
INTF_PRIVATE_KEY 	= $(INTD_PRIVATE)/intermediate.key.pem
INTF_CSR		= $(INTD_CSR)/intermediate.csr.pem
INTF_CERT		= $(INTD_CERTS)/intermediate.cert.pem
INTF_SERIAL		= $(INTD)/serial
INTF_INDEX		= $(INTD)/index.txt
INTF_CRLNUMBER		= $(INTD)/crlnumber

# See http://datacenteroverlords.com/2012/03/01/creating-your-own-ssl-certificate-authority/

DEVICE_CRT	= device.crt		# public;  Device Certificate
DEVICE_CSR	= device.csr		# public;  Device Certificate SIgning Request
DEVICE_KEY	= device.key		# PRIVATE; Device Key

DEVICE_FILES	+= $(DEVICE_CRT)
DEVICE_FILES	+= $(DEVICE_CSR)
DEVICE_FILES	+= $(DEVICE_KEY)

ROOT_FILES	+= $(BASE_CERTS)
ROOT_FILES	+= $(BASE_CRL)
ROOT_FILES	+= $(BASE_NEWCERTS)
ROOT_FILES	+= $(BASE_PRIVATE)
ROOT_FILES	+= $(ROOT_SERIAL)
ROOT_FILES	+= $(ROOT_INDEX)

all:
	false

device-crt:	$(DEVICE_CRT)
device-csr:	$(DEVICE_CSR)
device-key:	$(DEVICE_KEY)

# Sign the CSR
$(DEVICE_CRT): $(DEVICE_CSR) $(ROOT_CERT) $(ROOT_PRIVATE_KEY)
	openssl x509 -req -in $(DEVICE_CSR) -CA $(ROOT_CERT) -CAkey $(ROOT_PRIVATE_KEY) -CAcreateserial -out $(DEVICE_CRT) -days 500

# Generate the Certificate Signing Request for the Device Key
$(DEVICE_CSR): $(DEVICE_KEY)
	openssl req -new -key $(DEVICE_KEY) -out $(DEVICE_CSR)

# Generate the Device Key; no Password
$(DEVICE_KEY):
	openssl genrsa -out $(DEVICE_KEY) 2048

# One-time initialization
once:
	$(MAKE) root
	$(MAKE) int

# Generate the Root CA
root:
	@echo "Generate the Root"
	cd $(BASE)
	mkdir -p $(BASE_CERTS)
	mkdir -p $(BASE_CRL)
	mkdir -p $(BASE_NEWCERTS)
	mkdir -p $(BASE_PRIVATE)
	chmod 700 $(BASE_PRIVATE)
	touch       $(ROOT_INDEX)
	echo 1000 > $(ROOT_SERIAL)
	$(MAKE) root-key
	$(MAKE) root-cert
	$(MAKE) root-verify

root-key:
	cd $(BASE)
	@echo "Generate the root key"
	openssl genrsa -aes256 -out $(ROOT_PRIVATE_KEY) 4096
	chmod 400 $(ROOT_PRIVATE_KEY)

root-cert:
	cd $(BASE)
	@echo "Generate the root certificate"
	openssl req -config $(CNF_ROOT) -key $(ROOT_PRIVATE_KEY) -new -x509 -days 7300 -sha256 -extensions v3_ca -out $(ROOT_CERT)

root-verify:
	cd $(BASE)
	@echo "Verify the root certificate"
	openssl x509 -noout -text -in $(ROOT_CERT)

# Generate the Intermediate CA
int:
	@echo "Generate the Intermediate"
	cd $(BASE)
	mkdir -p $(INTD)
	cd $(INTD)
	mkdir -p $(INTD_CERTS)
	mkdir -p $(INTD_CRL)
	mkdir -p $(INTD_CSR)
	mkdir -p $(INTD_NEWCERTS)
	mkdir -p $(INTD_PRIVATE)
	chmod 700 $(INTD_PRIVATE)
	touch       $(INTF_INDEX)
	echo 1000 > $(INTF_SERIAL)
	echo 1000 > $(INTF_CRLNUMBER)
	$(MAKE) int-key
	$(MAKE) int-csr
	$(MAKE) int-cert
	$(MAKE) int-verify

int-key:
	cd $(BASE)
	@echo "Generate the intermediate key"
	openssl genrsa -aes256 -out $(INTF_PRIVATE_KEY) 4096
	chmod 400 $(INTF_PRIVATE_KEY)

int-csr:
	cd $(BASE)
	@echo "Generate the intermediate CSR"
	openssl req -config $(CNF_INT) -new -sha256 -key $(INTF_PRIVATE_KEY) -out $(INTF_CSR)

int-cert:
	cd $(BASE)
	@echo "Sign the intermediate certificate with the root CA"
	openssl ca -config $(CNF_ROOT) -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in $(INTF_CSR) -out $(INTF_CERT)
	chmod 444 $(INTF_CERT)

int-verify:
	cd $(BASE)
	@echo "Verify the intermediate CA"
	openssl x509 -noout -text -in $(INTF_CERT)
	@echo "Verify the intermediate CA against the root CA"
	openssl verify -CAfile $(ROOT_CERT) $(INTF_CERT)

clean:
	$(RM) -f $(DEVICE_FILES)

clean-int:
	$(RM) -rf $(INTD)

clean-root:
	$(RM) -rf $(ROOT_FILES)

danger:
	$(MAKE) clean-int
	$(MAKE) clean-root
