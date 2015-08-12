#!/usr/bin/env make -f

# See https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html

# Base directory
BASE			= $(shell pwd)
CNFD			= $(BASE)/config
ROOT			= $(BASE)/root
INTD			= $(BASE)/intermediate

# Config files		DO NOT DELETE !!
CNF_ROOT		= $(CNFD)/openssl.cnf-root
CNF_INT			= $(CNFD)/openssl.cnf-intermediate

# Root directories
ROOT_CERTS		= $(ROOT)/certs
ROOT_CRL		= $(ROOT)/crl
ROOT_NEWCERTS		= $(ROOT)/newcerts
ROOT_PRIVATE		= $(ROOT)/private

# Intermediate directories
INTD_CERTS		= $(INTD)/certs
INTD_CRL		= $(INTD)/crl
INTD_CSR		= $(INTD)/csr
INTD_NEWCERTS		= $(INTD)/newcerts
INTD_PRIVATE		= $(INTD)/private

# Root files
ROOT_KEY 		= $(ROOT_PRIVATE)/ca.key.pem
ROOT_CERT		= $(ROOT_CERTS)/ca.cert.pem
ROOT_SERIAL		= $(ROOT)/serial
ROOT_INDEX		= $(ROOT)/index.txt

CRL			= $(ROOT_CRL)/ca.crl.pem # unused

# Intermediate files
INTF_KEY 		= $(INTD_PRIVATE)/intermediate.key.pem
INTF_CSR		= $(INTD_CSR)/intermediate.csr.pem
INTF_CERT		= $(INTD_CERTS)/intermediate.cert.pem
INTF_CHAIN		= $(INTD_CERTS)/ca-chain.cert.pem
INTF_SERIAL		= $(INTD)/serial
INTF_INDEX		= $(INTD)/index.txt
INTF_CRLNUMBER		= $(INTD)/crlnumber

# Server files

SERVER_KEY		= $(INTD_PRIVATE)/www.example.com.key.pem
SERVER_CSR		= $(INTD_CSR)/www.example.com.csr.pem
SERVER_CERT		= $(INTD_CERTS)/www.example.com.cert.pem

all:
	false

# One-time initialization
once:
	$(MAKE) root
	$(MAKE) int

clean-int:
	$(RM) -rf $(INTD)

clean-root:
	$(RM) -rf $(ROOT)

danger:
	$(MAKE) clean-int
	$(MAKE) clean-root

#------------------------------------------------------------------------------
# Generate the Server Certificate
server:
	$(MAKE) server-key
	$(MAKE) server-csr
	$(MAKE) server-cert
	$(MAKE) server-verify
	$(MAKE) server-chain-verify

server-key:
	# Add "-aes256" only if you want to require a password on every restart
	@echo "Generate the Server Key"
	openssl genrsa -out $(SERVER_KEY) 2048
	chmod 400 $(SERVER_KEY)

server-csr:
	@echo "Generate the Server CSR"
	openssl req -config $(CNF_INT) -key $(SERVER_KEY) -new -sha256 -out $(SERVER_CSR)

server-cert:
	@echo "Sign the Server Certificate with the Intermediate CA"
	openssl ca -config $(CNF_INT) -extensions server_cert -days 375 -notext -md sha256 -in $(SERVER_CSR) -out $(SERVER_CERT)
	chmod 444 $(SERVER_CERT)

server-verify:
	@echo "Verify the Server Certificate"
	openssl x509 -noout -text -in $(SERVER_CERT)

server-chain-verify:
	@echo "Verify the Server Certificate against the Chain Of Trust"
	openssl verify -CAfile $(INTF_CHAIN) $(SERVER_CERT)

#------------------------------------------------------------------------------
# Generate the Intermediate CA
int:
	@echo "Generate the Intermediate"
	mkdir -p $(INTD)
	mkdir -p $(INTD_CERTS)
	mkdir -p $(INTD_CRL)
	mkdir -p $(INTD_CSR)
	mkdir -p $(INTD_NEWCERTS)
	mkdir -p $(INTD_PRIVATE)
	chmod 700 $(INTD_PRIVATE)
	touch $(INTF_INDEX)
	echo 1000 > $(INTF_SERIAL)
	echo 1000 > $(INTF_CRLNUMBER)
	$(MAKE) int-key
	$(MAKE) int-csr
	$(MAKE) int-cert
	$(MAKE) int-verify
	$(MAKE) int-chain
	$(MAKE) int-chain-verify

int-key:
	@echo "Generate the Intermediate Key"
	openssl genrsa -aes256 -out $(INTF_KEY) 4096
	chmod 400 $(INTF_KEY)

int-csr:
	@echo "Generate the Intermediate CSR"
	openssl req -config $(CNF_INT) -new -sha256 -key $(INTF_KEY) -out $(INTF_CSR)

int-cert:
	@echo "Sign the Intermediate Certificate with the Root CA"
	openssl ca -config $(CNF_ROOT) -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in $(INTF_CSR) -out $(INTF_CERT)
	chmod 444 $(INTF_CERT)

int-verify:
	@echo "Verify the Intermediate CA"
	openssl x509 -noout -text -in $(INTF_CERT)
	@echo "Verify the Intermediate CA against the Root CA"
	openssl verify -CAfile $(ROOT_CERT) $(INTF_CERT)

int-chain:
	cat $(INTF_CERT) $(ROOT_CERT) > $(INTF_CHAIN)
	chmod 444 $(INTF_CHAIN)

int-chain-verify:
	@echo "Verify the Intermediate chain"
	openssl x509 -noout -text -in $(INTF_CHAIN)
	@echo "Verify the Intermediate chain against the Root CA"
	openssl verify -CAfile $(ROOT_CERT) $(INTF_CHAIN)

#------------------------------------------------------------------------------
# Generate the Root CA
root:
	@echo "Generate the Root"
	mkdir -p $(ROOT)
	mkdir -p $(ROOT_CERTS)
	mkdir -p $(ROOT_CRL)
	mkdir -p $(ROOT_NEWCERTS)
	mkdir -p $(ROOT_PRIVATE)
	chmod 700 $(ROOT_PRIVATE)
	touch $(ROOT_INDEX)
	echo 1000 > $(ROOT_SERIAL)
	$(MAKE) root-key
	$(MAKE) root-cert
	$(MAKE) root-verify

root-key:
	@echo "Generate the Root Key"
	openssl genrsa -aes256 -out $(ROOT_KEY) 4096
	chmod 400 $(ROOT_KEY)

root-cert:
	@echo "Generate the Root Certificate"
	openssl req -config $(CNF_ROOT) -key $(ROOT_KEY) -new -x509 -days 7300 -sha256 -extensions v3_ca -out $(ROOT_CERT)

root-verify:
	@echo "Verify the Root Certificate"
	openssl x509 -noout -text -in $(ROOT_CERT)
