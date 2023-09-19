// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { HatWearingEligibility } from "../src/HatWearingEligibility.sol";

contract Deploy is Script {
  HatWearingEligibility public implementation;
  bytes32 public constant SALT = bytes32(abi.encode(0x4a75)); // ~ H(4) A(a) T(7) S(5)

  // default values
  bool internal _verbose = true;
  string internal _version = "0.2.0"; // increment this with each new deployment

  /// @dev Override default values, if desired
  function prepare(bool verbose, string memory version) public {
    _verbose = verbose;
    _version = version;
  }

  /// @dev Set up the deployer via their private key from the environment
  function deployer() public returns (address) {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    return vm.rememberKey(privKey);
  }

  function _log(string memory prefix) internal view {
    if (_verbose) {
      console2.log(string.concat(prefix, "Module:"), address(implementation));
    }
  }

  /// @dev Deploy the contract to a deterministic address via forge's create2 deployer factory.
  function run() public virtual {
    vm.startBroadcast(deployer());

    /**
     * @dev Deploy the contract to a deterministic address via forge's create2 deployer factory, which is at this
     * address on all chains: `0x4e59b44847b379578588920cA78FbF26c0B4956C`.
     * The resulting deployment address is determined by only two factors:
     *    1. The bytecode hash of the contract to deploy. Setting `bytecode_hash` to "none" in foundry.toml ensures that
     *       never differs regardless of where its being compiled
     *    2. The provided salt, `SALT`
     */
    implementation = new HatWearingEligibility{ salt: SALT}(_version /* insert constructor args here */);

    vm.stopBroadcast();

    _log("");
  }
}

/// @dev Deploy pre-compiled ir-optimized bytecode to a non-deterministic address
contract DeployPrecompiled is Deploy {
  /// @dev Update SALT and default values in Deploy contract

  function run() public override {
    vm.startBroadcast(deployer());

    bytes memory args = abi.encode( /* insert constructor args here */ );

    /// @dev Load and deploy pre-compiled ir-optimized bytecode.
    implementation = HatWearingEligibility(deployCode("optimized-out/Module.sol/Module.json", args));

    vm.stopBroadcast();

    _log("Precompiled ");
  }
}

/* FORGE CLI COMMANDS

## A. Simulate the deployment locally
forge script script/Deploy.s.sol:Deploy -f mainnet

## B. Deploy to real network and verify on etherscan
forge script script/Deploy.s.sol:Deploy -f mainnet --broadcast --verify

## C. Fix verification issues (replace values in curly braces with the actual values)
forge verify-contract --chain-id 5 --num-of-optimizations 1000000 --watch \
 --compiler-version v0.8.19 0xa2e614CE4FAaD60e266127F4006b812d69977265 \
 src/HatWearingEligibility.sol:HatWearingEligibility --etherscan-api-key $ETHERSCAN_KEY

## D. To verify ir-optimized contracts on etherscan...
  1. Run (C) with the following additional flag: `--show-standard-json-input > etherscan.json`
  2. Patch `etherscan.json`: `"optimizer":{"enabled":true,"runs":100}` =>
`"optimizer":{"enabled":true,"runs":100},"viaIR":true`
  3. Upload the patched `etherscan.json` to etherscan manually

  See this github issue for more: https://github.com/foundry-rs/foundry/issues/3507#issuecomment-1465382107

*/
