#!/usr/bin/env make -f

# See https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html

# Base directory
BASE			= /home/kevin/github.com/kshortwindham/ca

# Config files		DO NOT DELETE !!
CNF_ROOT		= $(BASE)/config/openssl.cnf-root
CNF_INT			= $(BASE)/config/openssl.cnf-intermediate

# Root directories
ROOT			= $(BASE)/root
ROOT_CERTS		= $(ROOT)/certs
ROOT_CRL		= $(ROOT)/crl
ROOT_NEWCERTS		= $(ROOT)/newcerts
ROOT_PRIVATE		= $(ROOT)/private

# Intermediate directories
INTD			= $(BASE)/intermediate
INTD_CERTS		= $(INTD)/certs
INTD_CRL		= $(INTD)/crl
INTD_CSR		= $(INTD)/csr
INTD_NEWCERTS		= $(INTD)/newcerts
INTD_PRIVATE		= $(INTD)/private

# Root files
ROOT_PRIVATE_KEY 	= $(ROOT_PRIVATE)/ca.key.pem
ROOT_CERT		= $(ROOT_CERTS)/ca.cert.pem
ROOT_SERIAL		= $(ROOT)/serial
ROOT_INDEX		= $(ROOT)/index.txt

CRL			= $(ROOT_CRL)/ca.crl.pem # unused

ROOT_FILES		+= $(ROOT_PRIVATE_KEY)
ROOT_FILES		+= $(ROOT_CERT)
ROOT_FILES		+= $(ROOT_SERIAL)
ROOT_FILES		+= $(ROOT_INDEX)

# Intermediate files
INTF_PRIVATE_KEY 	= $(INTD_PRIVATE)/intermediate.key.pem
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
# Generate the Root CA
root:
	@echo "Generate the Root"
	mkdir -p $(ROOT)
	cd $(ROOT)
	mkdir -p $(ROOT_CERTS)
	mkdir -p $(ROOT_CRL)
	mkdir -p $(ROOT_NEWCERTS)
	mkdir -p $(ROOT_PRIVATE)
	chmod 700 $(ROOT_PRIVATE)
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

#------------------------------------------------------------------------------
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
	$(MAKE) int-chain
	$(MAKE) int-chain-verify

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

int-chain:
	cd $(BASE)
	cat $(INTF_CERT) $(ROOT_CERT) > $(INTF_CHAIN)
	chmod 444 $(INTF_CHAIN)

int-chain-verify:
	cd $(BASE)
	@echo "Verify the intermediate chain"
	openssl x509 -noout -text -in $(INTF_CHAIN)
	@echo "Verify the intermediate chain against the root CA"
	openssl verify -CAfile $(ROOT_CERT) $(INTF_CHAIN)

#------------------------------------------------------------------------------
# Generate the Server certificate
server:
	$(MAKE) server-key
	$(MAKE) server-csr
	$(MAKE) server-cert
	$(MAKE) server-verify

server-key:
	cd $(BASE)
	# Add "-aes256" only if you want to require a password on every restart
	@echo "Generate the server key"
	openssl genrsa -out $(SERVER_KEY) 2048
	chmod 400 $(SERVER_KEY)

server-csr:
	cd $(BASE)
	@echo "Generate the server CSR"
	openssl req -config $(CNF_INT) -key $(SERVER_KEY) -new -sha256 -out $(SERVER_CSR)

server-cert:
	cd $(BASE)
	@echo "Sign the server certificate with the intermediate CA"
	openssl ca -config $(CNF_INT) -extensions server_cert -days 375 -notext -md sha256 -in $(SERVER_CSR) -out $(SERVER_CERT)
	chmod 444 $(SERVER_CERT)

server-verify:
	cd $(BASE)
	openssl x509 -noout -text -in $(SERVER_CERT)
