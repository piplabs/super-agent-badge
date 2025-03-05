// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ICreate3Deployer } from "@storyprotocol/script/utils/ICreate3Deployer.sol";
import { JsonDeploymentHandler } from "../utils/JsonDeploymentHandler.s.sol";
import { BroadcastManager } from "../utils/BroadcastManager.s.sol";
import { StoryBadgeNFT } from "../../contracts/story-nft/StoryBadgeNFT.sol";
import { IStoryNFT } from "../../contracts/interfaces/story-nft/IStoryNFT.sol";
import { IStoryBadgeNFT } from "../../contracts/interfaces/story-nft/IStoryBadgeNFT.sol";
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { TestProxyHelper } from "@storyprotocol/test/utils/TestProxyHelper.sol";
import { StoryProtocolCoreAddressManager } from "../utils/StoryProtocolCoreAddressManager.sol";
import { StoryProtocolPeripheryAddressManager } from "../utils/StoryProtocolPeripheryAddressManager.sol";

contract StoryNFTDeployer is
    Script,
    BroadcastManager,
    JsonDeploymentHandler,
    StoryProtocolCoreAddressManager,
    StoryProtocolPeripheryAddressManager
{
    address internal CREATE3_DEPLOYER = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
    uint256 private constant CREATE3_DEFAULT_SEED = 123456237890;

    ICreate3Deployer internal immutable create3Deployer;

    StoryBadgeNFT public storyBadgeNft;

    address internal defaultLicenseTemplate;
    uint256 internal defaultLicenseTermsId;

    constructor() JsonDeploymentHandler("main") {
        create3Deployer = ICreate3Deployer(CREATE3_DEPLOYER);
    }

    function run() public {
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        _readStoryProtocolCoreAddresses();
        (defaultLicenseTemplate, defaultLicenseTermsId) = ILicenseRegistry(licenseRegistryAddr)
            .getDefaultLicenseTerms();

        vm.startBroadcast(vm.envUint("STORY_PRIVATEKEY"));

        _deployBadgeNft();
        _mintToRecipient();

        vm.stopBroadcast();
    }

    function _deployBadgeNft() internal {
        IStoryNFT.StoryNftInitParams memory initParams = IStoryNFT.StoryNftInitParams({
            owner: vm.envAddress("STORY_DEPLOYER_ADDRESS"),
            name: "Super Agent Hackathon Badge",
            symbol: "SUPERAGENT",
            contractURI: "https://ipfs.io/ipfs/bafkreidsedvpq43275dv4ydqboewurfouzyokcr6iorzkntm5gxl7dbneu",
            baseURI: "",
            customInitData: abi.encode(
                IStoryBadgeNFT.CustomInitParams({
                    tokenURI: "https://ipfs.io/ipfs/bafkreibttfkvzugpuo2dcjnwl63orm2xlhex3r2dm62apju3bzjyovtuyi",
                    ipMetadataURI: "https://ipfs.io/ipfs/bafkreife7t4c3wok5k27u26voeotol3iscv6jjgjntphxsrbojp467vafu",
                    ipMetadataHash: bytes32(0xa4fcf82dd9caeab5fa6bd5711d372f6890abe4a4c96cde7bca21725fcf7ea02d),
                    nftMetadataHash: bytes32(0x3399555cd0cfa3b43125b65fb6e8b35759c97dc74367b407a69b0e53875674c2)
                })
            )
        });
        _predeploy("StoryBadgeNFT");
        address impl = address(
            new StoryBadgeNFT(
                ipAssetRegistryAddr,
                licensingModuleAddr,
                coreMetadataModuleAddr,
                pilTemplateAddr,
                defaultLicenseTermsId
            )
        );
        storyBadgeNft = StoryBadgeNFT(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(StoryBadgeNFT).name),
                impl,
                abi.encodeCall(StoryBadgeNFT.initialize, (initParams))
            )
        );
        impl = address(0);
        _postdeploy("StoryBadgeNFT", address(storyBadgeNft));
    }

    function _mintToRecipient() internal {
        storyBadgeNft.mintRoot(vm.envAddress("STORY_MULTISIG_ADDRESS"));
        // Read recipient addresses from a JSON file
        string memory json = vm.readFile("recipients.json");
        bytes memory recipientAddressesJson = vm.parseJson(json, "$.addresses");
        address[] memory recipientAddresses = abi.decode(recipientAddressesJson, (address[]));

        // Mint badges to all recipients in the JSON file
        for (uint256 i = 0; i < recipientAddresses.length; i++) {
            if (recipientAddresses[i] != address(0)) {
                storyBadgeNft.mint(recipientAddresses[i]);
            }
        }
    }

    /// @dev get the salt for the contract deployment with CREATE3
    function _getSalt(string memory name) internal view returns (bytes32 salt) {
        salt = keccak256(abi.encode(name, CREATE3_DEFAULT_SEED));
    }

    function _predeploy(string memory contractKey) internal view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) internal {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
