// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {EduToken} from "../src/EduToken.sol";
import {ContentRegistry} from "../src/ContentRegistry.sol";
import {EduRewards} from "../src/EduRewards.sol";

contract DeployEdTech is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(pk); // real EOA that will be the admin

        // params
        string memory name = "EduToken";
        string memory symbol = "EDU";
        uint64 epochDuration = 7 days;
        uint256 emissionPerEpoch = 10_000 ether;
        uint256 minStake = 1 ether;
        uint256 lockPeriod = 1 days;

        vm.startBroadcast(pk);

        // deploy, pass admin EOA explicitly
        EduToken token = new EduToken(name, symbol, admin);
        ContentRegistry reg = new ContentRegistry(admin);

        uint64 initialEnd = uint64(block.timestamp + epochDuration);
        EduRewards rewards = new EduRewards(
            admin,
            token,
            reg,
            initialEnd,
            emissionPerEpoch,
            minStake,
            lockPeriod
        );

        // grant minter, call is from admin EOA because we are inside startBroadcast(pk)
        token.grantRole(token.MINTER_ROLE(), address(rewards));

        vm.stopBroadcast();

        console2.log("Admin EOA:", admin);
        console2.log("EduToken:", address(token));
        console2.log("ContentRegistry:", address(reg));
        console2.log("EduRewards:", address(rewards));
    }
}
