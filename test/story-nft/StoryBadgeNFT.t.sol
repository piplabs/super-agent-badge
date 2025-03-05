// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BaseTest } from "@storyprotocol/periphery/test/utils/BaseTest.t.sol";
import { TestProxyHelper } from "@storyprotocol/test/utils/TestProxyHelper.sol";

// contracts
import { BaseStoryNFT } from "../../contracts/story-nft/BaseStoryNFT.sol";
import { IStoryBadgeNFT } from "../../contracts/interfaces/story-nft/IStoryBadgeNFT.sol";
import { IStoryNFT } from "../../contracts/interfaces/story-nft/IStoryNFT.sol";
import { StoryBadgeNFT } from "../../contracts/story-nft/StoryBadgeNFT.sol";

contract StoryBadgeNFTTest is BaseTest {
    StoryBadgeNFT public storyBadgeNft;

    function setUp() public override {
        super.setUp();

        IStoryNFT.StoryNftInitParams memory storyBadgeNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: rootOrgStoryNftOwner,
            name: "Test Badge",
            symbol: "TB",
            contractURI: "Test Contract URI",
            baseURI: "",
            customInitData: abi.encode(
                IStoryBadgeNFT.CustomInitParams({
                    tokenURI: "Test Token URI",
                    ipMetadataURI: ipMetadataDefault.ipMetadataURI,
                    ipMetadataHash: ipMetadataDefault.ipMetadataHash,
                    nftMetadataHash: ipMetadataDefault.nftMetadataHash
                })
            )
        });
        address impl = address(
            new StoryBadgeNFT({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                coreMetadataModule: address(coreMetadataModule),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1
            })
        );

        storyBadgeNft = StoryBadgeNFT(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(StoryBadgeNFT.initialize, (storyBadgeNftInitParams))
            )
        );
    }

    function test_StoryBadgeNFT_initialize() public {
        address testStoryBadgeNftImpl = address(
            new StoryBadgeNFT({
                ipAssetRegistry: address(ipAssetRegistry),
                licensingModule: address(licensingModule),
                coreMetadataModule: address(coreMetadataModule),
                pilTemplate: address(pilTemplate),
                defaultLicenseTermsId: 1
            })
        );

        string memory tokenURI = "Test Token URI";

        bytes memory storyBadgeNftCustomInitParams = abi.encode(
            IStoryBadgeNFT.CustomInitParams({
                tokenURI: tokenURI,
                ipMetadataURI: ipMetadataDefault.ipMetadataURI,
                ipMetadataHash: ipMetadataDefault.ipMetadataHash,
                nftMetadataHash: ipMetadataDefault.nftMetadataHash
            })
        );

        IStoryNFT.StoryNftInitParams memory storyBadgeNftInitParams = IStoryNFT.StoryNftInitParams({
            owner: rootOrgStoryNftOwner,
            name: "Test Badge",
            symbol: "TB",
            contractURI: "Test Contract URI",
            baseURI: "",
            customInitData: storyBadgeNftCustomInitParams
        });

        StoryBadgeNFT testStoryBadgeNft = StoryBadgeNFT(
            TestProxyHelper.deployUUPSProxy(
                testStoryBadgeNftImpl,
                abi.encodeCall(StoryBadgeNFT.initialize, (storyBadgeNftInitParams))
            )
        );

        assertEq(address(BaseStoryNFT(address(testStoryBadgeNft)).IP_ASSET_REGISTRY()), address(ipAssetRegistry));
        assertEq(address(BaseStoryNFT(address(testStoryBadgeNft)).LICENSING_MODULE()), address(licensingModule));
        assertEq(testStoryBadgeNft.PIL_TEMPLATE(), address(pilTemplate));
        assertEq(testStoryBadgeNft.DEFAULT_LICENSE_TERMS_ID(), 1);
        assertEq(testStoryBadgeNft.name(), "Test Badge");
        assertEq(testStoryBadgeNft.symbol(), "TB");
        assertEq(testStoryBadgeNft.contractURI(), "Test Contract URI");
        assertEq(testStoryBadgeNft.tokenURI(0), tokenURI);
        assertEq(testStoryBadgeNft.owner(), rootOrgStoryNftOwner);
        assertEq(testStoryBadgeNft.totalSupply(), 0);
        assertTrue(testStoryBadgeNft.locked(0));
    }

    function test_StoryBadgeNFT_mint() public {
        // First mint root
        vm.startPrank(rootOrgStoryNftOwner);
        (uint256 rootTokenId, address rootIpId) = storyBadgeNft.mintRoot(u.alice);

        // Then mint derivative
        (uint256 tokenId, address ipId) = storyBadgeNft.mint(u.carl);
        vm.stopPrank();

        assertEq(storyBadgeNft.ownerOf(tokenId), u.carl);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(storyBadgeNft.tokenURI(tokenId), "Test Token URI");
        assertMetadata(ipId, ipMetadataDefault);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId, 0);
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, 1);
        assertEq(IIPAccount(payable(ipId)).owner(), u.carl);

        assertParentChild({
            parentIpId: rootIpId,
            childIpId: ipId,
            expectedParentCount: 1,
            expectedParentIndex: 0
        });
    }

    function test_StoryBadgeNFT_revert_mint_RootIpNotSet() public {
        vm.startPrank(rootOrgStoryNftOwner);
        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__RootIpNotSet.selector);
        storyBadgeNft.mint(u.carl);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_mint_RecipientAlreadyHasBadge() public {
        vm.startPrank(rootOrgStoryNftOwner);
        storyBadgeNft.mintRoot(u.carl);

        vm.expectRevert(
            abi.encodeWithSelector(IStoryBadgeNFT.StoryBadgeNFT__RecipientAlreadyHasBadge.selector, u.carl)
        );
        storyBadgeNft.mint(u.carl);
        vm.stopPrank();
    }

    function test_StoryBadgeNFT_revert_TransferLocked() public {
        vm.startPrank(rootOrgStoryNftOwner);
        storyBadgeNft.mintRoot(u.alice);
        (uint256 tokenId, ) = storyBadgeNft.mint(u.carl);
        vm.stopPrank();

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        storyBadgeNft.approve(u.bob, tokenId);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        storyBadgeNft.setApprovalForAll(u.bob, true);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        storyBadgeNft.transferFrom(u.carl, u.bob, tokenId);

        vm.expectRevert(IStoryBadgeNFT.StoryBadgeNFT__TransferLocked.selector);
        storyBadgeNft.safeTransferFrom(u.carl, u.bob, tokenId);
    }
}
