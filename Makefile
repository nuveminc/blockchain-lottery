-include .env

.PHONY: all test deploy

ANVIL_PRIVATE_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo " make deploy [ARGS=]"

build:; forge build

install:; forge install

test:; forge test

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(ANVIL_PRIVATE_KEY) --broadcast

# if --network sepolia is passed as an arg, then use sepolia as network otherwise use anvil as the network
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy
endif

deploy:
	@forge script script/DeployLottery.s.sol:DeployLottery $(NETWORK_ARGS)
