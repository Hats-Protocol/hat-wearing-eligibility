// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import { HatWearingEligibility } from "../src/HatWearingEligibility.sol";
import { Deploy, DeployPrecompiled } from "../script/Deploy.s.sol";
import {
  HatsModuleFactory, IHats, deployModuleInstance, deployModuleFactory
} from "hats-module/utils/DeployFunctions.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";

contract HatWearingEligibilityTest is Deploy, Test {
  /// @dev Inherit from DeployPrecompiled instead of Deploy if working with pre-compiled contracts

  /// @dev variables inhereted from Deploy script
  // HatWearingEligibility public implementation;
  // bytes32 public SALT;

  uint256 public fork;
  uint256 public BLOCK_NUMBER = 17_671_864; // deployment block for Hats.sol
  IHats public HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth
  HatsModuleFactory public factory;
  HatWearingEligibility public instance;
  bytes public otherImmutableArgs;
  bytes public initArgs;

  uint256 public tophat;
  uint256 public criterionHat;
  uint256 public targetHat;
  address public org = makeAddr("org");
  address public wearer = makeAddr("wearer");
  address public nonWearer = makeAddr("nonWearer");

  string public MODULE_VERSION;

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER
    fork = vm.createSelectFork(vm.rpcUrl("mainnet"), BLOCK_NUMBER);

    // deploy implementation via the script
    prepare(false, MODULE_VERSION);
    run();

    // deploy the hats module factory
    factory = deployModuleFactory(HATS, SALT, "test factory");
  }
}

contract WithInstanceTest is HatWearingEligibilityTest {
  function setUp() public virtual override {
    super.setUp();

    // set up the hats
    tophat = HATS.mintTopHat(org, "org's tophat", "");
    vm.startPrank(org);
    criterionHat = HATS.createHat(tophat, "eligibility criterion hat", 2, org, org, true, "");
    targetHat = HATS.createHat(tophat, "target hat", 2, org, org, true, "");
    HATS.mintHat(criterionHat, wearer);
    vm.stopPrank();

    // we don't have any other immutable args or init args, so we leave them empty
    otherImmutableArgs = abi.encode(criterionHat);
    initArgs;

    // deploy an instance of the module
    instance =
      HatWearingEligibility(deployModuleInstance(factory, address(implementation), 0, otherImmutableArgs, initArgs));

    // set the instance as the eligibility module for the target hat
    vm.prank(org);
    HATS.changeHatEligibility(targetHat, address(instance));
  }
}

contract Deployment is WithInstanceTest {
  /// @dev ensure that both the implementation and instance are properly initialized
  function test_initialization() public {
    // implementation
    vm.expectRevert("Initializable: contract is already initialized");
    implementation.setUp("setUp attempt");
    // instance
    vm.expectRevert("Initializable: contract is already initialized");
    instance.setUp("setUp attempt");
  }

  function test_version() public {
    assertEq(instance.version(), MODULE_VERSION);
  }

  function test_implementation() public {
    assertEq(address(instance.IMPLEMENTATION()), address(implementation));
  }

  function test_hats() public {
    assertEq(address(instance.HATS()), address(HATS));
  }

  function test_hatId() public {
    assertEq(instance.hatId(), 0);
  }

  function test_criterionHat() public {
    assertEq(instance.CRITERION_HAT(), criterionHat);
  }
}

contract GetWearerStatus is WithInstanceTest {
  function test_getWearerStatus() public {
    // the wearer is wearing the criterion hat and therefore should be eligible for the target hat
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, targetHat);
    assertEq(eligible, true);
    assertEq(standing, true);

    // the nonWearer is not wearing the criterion hat and therefore should be ineligible for the target hat
    (eligible, standing) = instance.getWearerStatus(nonWearer, targetHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }

  function test_revocationCascade() public {
    // the wearer is wearing the criterion hat and therefore should be eligible for the target hat
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, targetHat);
    assertEq(eligible, true);
    assertEq(standing, true);

    // revoke the criterion hat
    vm.prank(org);
    HATS.setHatWearerStatus(criterionHat, wearer, false, true);

    // the wearer is no longer wearing the criterion hat and therefore should be ineligible for the target hat
    (eligible, standing) = instance.getWearerStatus(wearer, targetHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }
}
