// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import { IERC5192 } from "./IERC5192.sol";
import { IStoryNFT } from "./IStoryNFT.sol";

/// @title Story Badge NFT Interface
/// @notice A Story Badge NFT is a soulbound NFT that has an unified token URI for all tokens.
interface IStoryBadgeNFT is IStoryNFT, IERC721Metadata, IERC5192 {
    ////////////////////////////////////////////////////////////////////////////
    //                              Errors                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Badges are soulbound, cannot be transferred.
    error StoryBadgeNFT__TransferLocked();

    /// @notice Zero address provided as a param to StoryBadgeNFT functions.
    error StoryBadgeNFT__ZeroAddressParam();

    /// @notice The recipient already has a badge.
    /// @param recipient The address of the recipient.
    error StoryBadgeNFT__RecipientAlreadyHasBadge(address recipient);

    /// @notice The root IP is not set.
    error StoryBadgeNFT__RootIpNotSet();

    /// @notice The root IP is already set.
    error StoryBadgeNFT__RootIpAlreadySet();

    ////////////////////////////////////////////////////////////////////////////
    //                              Structs                                   //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Struct for custom data for initializing the StoryBadgeNFT contract.
    /// @param tokenURI The token URI for all the badges (follows OpenSea metadata standard).
    /// @param ipMetadataURI The URI of the metadata for all IP from this collection.
    /// @param ipMetadataHash The hash of the metadata for all IP from this collection.
    /// @param nftMetadataHash The hash of the metadata for all IP NFTs from this collection.
    struct CustomInitParams {
        string tokenURI;
        string ipMetadataURI;
        bytes32 ipMetadataHash;
        bytes32 nftMetadataHash;
    }

    ////////////////////////////////////////////////////////////////////////////
    //                              Events                                    //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Emitted when a badge NFT is minted.
    /// @param recipient The address of the recipient of the badge NFT.
    /// @param tokenId The token ID of the minted badge NFT.
    /// @param ipId The ID of the badge NFT IP.
    event StoryBadgeNFTMinted(address recipient, uint256 tokenId, address ipId);

    ////////////////////////////////////////////////////////////////////////////
    //                             Functions                                  //
    ////////////////////////////////////////////////////////////////////////////
    /// @notice Mints a badge for the given recipient, registers it as an IP,
    ///         and makes it a derivative of the organization IP.
    /// @param recipient The address of the recipient of the badge NFT.
    /// @return tokenId The token ID of the minted badge NFT.
    /// @return ipId The ID of the badge NFT IP.
    function mint(address recipient) external returns (uint256 tokenId, address ipId);

    /// @notice Mints a badge for the given recipient, registers it as the root IP.
    /// @param recipient The address of the recipient of the badge NFT.
    /// @return tokenId The token ID of the minted badge NFT.
    /// @return ipId The ID of the badge NFT IP.
    function mintRoot(address recipient) external returns (uint256 tokenId, address ipId);

    /// @notice Updates the unified token URI for all badges.
    /// @param tokenURI_ The new token URI.
    function setTokenURI(string memory tokenURI_) external;
}
